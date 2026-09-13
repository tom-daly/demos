# Shared helpers for the infra scripts. Dot-source this file.
# Every script: reads its inputs from env/<name>.json, logs to logs/<script>-<name>-<timestamp>.log,
# and writes whatever it learned back into the same JSON so the next script (and you) can find it.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:InfraRoot = Split-Path -Parent $PSScriptRoot
$script:EnvDir = Join-Path $script:InfraRoot 'env'
$script:LogDir = Join-Path $script:InfraRoot 'logs'

function Get-EnvPath([string]$Name) {
    return Join-Path $script:EnvDir "$Name.json"
}

function Read-Env([string]$Name) {
    $path = Get-EnvPath $Name
    if (-not (Test-Path $path)) {
        throw "No environment file at $path. Copy env/example.json to env/$Name.json and fill it in."
    }
    $cfg = Get-Content $path -Raw | ConvertFrom-Json -AsHashtable
    $script:EnvName = $Name    # Save-Env writes back to the file it was read from, whatever environmentName says
    foreach ($key in 'parameters', 'secrets', 'outputs', 'graph') {
        if (-not $cfg.ContainsKey($key) -or $null -eq $cfg[$key]) { $cfg[$key] = @{} }
    }
    if (-not $cfg.ContainsKey('history') -or $null -eq $cfg['history']) { $cfg['history'] = @() }
    return $cfg
}

function Save-Env([hashtable]$Cfg, [string]$Script, [string]$Note) {
    $Cfg['history'] += @{
        at     = (Get-Date).ToUniversalTime().ToString('o')
        script = $Script
        note   = $Note
    }
    $path = Get-EnvPath $(if ($script:EnvName) { $script:EnvName } else { $Cfg['environmentName'] })
    $Cfg | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding utf8
    Write-Log "Saved $path"
}

function Start-Log([string]$Script, [string]$Name) {
    New-Item -ItemType Directory -Force $script:LogDir | Out-Null
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $script:LogFile = Join-Path $script:LogDir "$Script-$Name-$stamp.log"
    Start-Transcript -Path $script:LogFile -Append | Out-Null
    Write-Log "=== $Script for environment '$Name' ==="
    return $script:LogFile
}

function Stop-Log {
    try { Stop-Transcript | Out-Null } catch {}
}

function Write-Log([string]$Message) {
    $line = "[{0}] {1}" -f (Get-Date).ToString('HH:mm:ss'), $Message
    Write-Host $line
}

function Write-LogValues([string]$Title, [hashtable]$Values) {
    Write-Log $Title
    foreach ($k in ($Values.Keys | Sort-Object)) {
        $v = $Values[$k]
        if ($k -match 'secret|state|key|password') { $v = '********' }
        Write-Host ("    {0,-32} {1}" -f $k, $v)
    }
}

function New-RandomSuffix([int]$Length = 4) {
    $chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
    -join (1..$Length | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

function Assert-AzLogin([hashtable]$Cfg) {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) { throw "Not signed in. Run: az login" }
    if ($Cfg['subscriptionId']) {
        if ($account.id -ne $Cfg['subscriptionId']) {
            Write-Log "Switching to subscription $($Cfg['subscriptionId'])"
            az account set --subscription $Cfg['subscriptionId']
            $account = az account show | ConvertFrom-Json
        }
    } else {
        $Cfg['subscriptionId'] = $account.id
    }
    $Cfg['tenantId'] = $account.tenantId
    Write-Log "Signed in as $($account.user.name) · subscription $($account.name) ($($account.id))"
    return $account
}

function Invoke-Graph([string]$Method, [string]$Uri, $Body) {
    # az rest gets a Graph token for the signed-in user. Good enough for admin one-offs.
    $args = @('rest', '--method', $Method, '--url', "https://graph.microsoft.com/v1.0$Uri", '--headers', 'Content-Type=application/json', '--only-show-errors')
    $tmp = $null
    if ($null -ne $Body) {
        # PowerShell strips the quotes out of inline JSON on its way to a native command, so the body goes via a file.
        $tmp = New-TemporaryFile
        $Body | ConvertTo-Json -Depth 10 -Compress | Set-Content -Path $tmp -Encoding utf8 -NoNewline
        $args += @('--body', "@$($tmp.FullName)")
    }
    try {
        $out = & az @args 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Graph $Method $Uri failed: $out" }
        if ($out) { return (($out | ForEach-Object { "$_" }) -join "`n" | ConvertFrom-Json) }
    } finally {
        if ($tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}
