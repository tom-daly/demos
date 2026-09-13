<#
.SYNOPSIS
  Checks every prerequisite before deploy.ps1: tools, sign-in, subscription rights, resource providers,
  region support for Flex Consumption and the model, and the env file. Nothing is changed.

.DESCRIPTION
  Each check prints PASS, WARN or FAIL with what to do. The results are written to env/<name>.json
  under "checks" and to the log, so a failed deploy can be compared against what was verified.

.EXAMPLE
  ./check.ps1 -Name aico
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Name
)

. (Join-Path $PSScriptRoot 'common.ps1')

$results = [ordered]@{}
$failed = 0

function Check([string]$Label, [scriptblock]$Test, [string]$Fix) {
    try {
        $out = & $Test
        if ($out -is [string] -and $out.StartsWith('WARN')) {
            Write-Host ("  WARN  {0,-42} {1}" -f $Label, $out.Substring(4).Trim()) -ForegroundColor Yellow
            $script:results[$Label] = "warn: $($out.Substring(4).Trim())"
        } else {
            Write-Host ("  PASS  {0,-42} {1}" -f $Label, $out) -ForegroundColor Green
            $script:results[$Label] = "pass: $out"
        }
    } catch {
        $msg = $_.Exception.Message.Split("`n")[0]
        Write-Host ("  FAIL  {0,-42} {1}" -f $Label, $msg) -ForegroundColor Red
        if ($Fix) { Write-Host ("        -> {0}" -f $Fix) -ForegroundColor DarkGray }
        $script:results[$Label] = "fail: $msg"
        $script:failed++
    }
}

function Require-Version([string]$Actual, [version]$Min, [string]$What) {
    $v = [version]($Actual -replace '[^\d.].*$', '')
    if ($v -lt $Min) { throw "$What $v is below $Min" }
    return "$v"
}

$log = Start-Log 'check' $Name
try {
    Write-Log "Tools"
    Check 'PowerShell 7' { Require-Version $PSVersionTable.PSVersion.ToString() '7.0' 'pwsh' } 'winget install Microsoft.PowerShell, then run these scripts with pwsh, not Windows PowerShell'
    Check 'Azure CLI (az)' {
        $v = (az version 2>$null | ConvertFrom-Json).'azure-cli'
        if (-not $v) { throw 'not found' }
        Require-Version $v '2.60' 'az'
    } 'winget install Microsoft.AzureCLI  (or: az upgrade)'
    Check 'Bicep' {
        $line = (az bicep version 2>&1 | Select-String 'Bicep CLI version ([\d.]+)').Matches.Groups[1].Value
        if (-not $line) { throw 'not installed' }
        Require-Version $line '0.30' 'bicep'
    } 'az bicep install  (or: az bicep upgrade)'
    Check 'Functions Core Tools (func, optional)' {
        $cmd = Get-Command func -ErrorAction SilentlyContinue
        if (-not $cmd) { return 'WARN not installed; only needed for running the functions on this PC (publish uses the Azure CLI)' }
        $v = [version]((func --version 2>$null) -replace '[^\d.].*$', '')
        if ($v -lt [version]'4.0.5907') { return "WARN $v is too old for Flex Consumption; publish.ps1 does not use it, but 'func start' locally is fine. Upgrade: winget upgrade Microsoft.Azure.FunctionsCoreTools" }
        "$v"
    } ''
    Check 'Python' {
        $cmd = Get-Command python -ErrorAction SilentlyContinue
        if (-not $cmd) { throw 'not found' }
        $v = (python --version 2>&1) -replace 'Python ', ''
        $out = Require-Version $v '3.10' 'python'
        if ([version]$out -lt [version]'3.12') { return "WARN $out on this PC; Azure builds and runs on its own 3.12, so publishing is unaffected. Only matters for 'func start' locally." }
        $out
    } 'winget install Python.Python.3.12'
    Check 'Microsoft.Graph.Authentication module' {
        $m = Get-Module -ListAvailable Microsoft.Graph.Authentication | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $m) { return 'WARN not installed; grant-graph.ps1 will write two copy/paste files for the browser instead' }
        "$($m.Version)"
    } 'Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'

    Write-Log "Environment file"
    $cfg = $null
    Check "env/$Name.json exists" {
        $cfg = Read-Env $Name
        Set-Variable -Name cfg -Value $cfg -Scope Script
        (Get-EnvPath $Name)
    } "Copy-Item env/example.json env/$Name.json and fill it in"
    if ($script:cfg) {
        $cfg = $script:cfg
        Check 'environmentName is letters and digits only' {
            $n = $cfg['environmentName']
            if ($n -notmatch '^[a-z0-9]{2,10}$') { throw "'$n' - storage accounts and the Foundry subdomain allow only lowercase letters and digits, 2-10 of them. Use e.g. 'aicodc'." }
            $n
        } "set environmentName in env/$Name.json to lowercase letters and digits only (the file name can stay as it is)"
        Check 'sharePointSiteUrl set' {
            $u = $cfg['parameters']['sharePointSiteUrl']
            if (-not $u -or $u -match 'contoso') { throw 'still the example value' }
            $u
        } 'set parameters.sharePointSiteUrl to the real site'
        Check 'resourceGroup blank (new one per deploy)' {
            if ($cfg['resourceGroup']) { return "WARN set to $($cfg['resourceGroup']); deploy.ps1 will still create a new one unless you pass -Reuse" }
            'blank'
        } ''
        Check 'location set' { if (-not $cfg['location']) { throw 'empty' }; $cfg['location'] } 'set location, e.g. eastus2'
    }

    Write-Log "Azure sign-in"
    $account = $null
    Check 'az login' {
        $account = az account show 2>$null | ConvertFrom-Json
        if (-not $account) { throw 'not signed in' }
        Set-Variable -Name account -Value $account -Scope Script
        "$($account.user.name) · $($account.name)"
    } 'az login'
    if ($script:account) {
        $account = $script:account
        $sub = $account.id
        Check 'Subscription matches env file' {
            $want = $cfg['subscriptionId']
            if ($want -and $want -ne $sub) { throw "signed in to $sub, env file says $want" }
            if (-not $want) { return "WARN env file has no subscriptionId; deploy.ps1 will record $sub" }
            $sub
        } "az account set --subscription <id>, or fix subscriptionId in env/$Name.json"
        Check 'Rights: Owner or Contributor + User Access Admin' {
            $me = az ad signed-in-user show --query id -o tsv 2>$null
            $roles = az role assignment list --assignee $me --scope "/subscriptions/$sub" --include-inherited --query '[].roleDefinitionName' -o tsv 2>$null
            $set = @($roles -split "`n" | Where-Object { $_ })
            if ($set -contains 'Owner') { return 'Owner' }
            if (($set -contains 'Contributor') -and ($set -contains 'User Access Administrator')) { return 'Contributor + User Access Administrator' }
            if ($set.Count -eq 0) { throw 'no role assignments visible for you on this subscription (or no rights to list them)' }
            throw "you have: $($set -join ', '). Role assignments in the template need Owner or User Access Administrator"
        } 'ask for Owner on the subscription, or Contributor plus User Access Administrator'

        Write-Log "Built-in role ids used by the templates"
        $roleIds = @{}
        foreach ($f in Get-ChildItem (Join-Path $script:InfraRoot 'modules') -Filter *.bicep) {
            foreach ($m in [regex]::Matches((Get-Content $f.FullName -Raw), "(\w+):\s*'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'")) {
                $roleIds[$m.Groups[1].Value] = $m.Groups[2].Value
            }
        }
        foreach ($k in ($roleIds.Keys | Sort-Object)) {
            Check "Role $k" {
                $n = az role definition list --name $roleIds[$k] --query '[0].roleName' -o tsv 2>$null
                if (-not $n) { throw "id $($roleIds[$k]) is not a role definition" }
                $n
            } 'fix the id in modules/*.bicep; find it with: az role definition list --query "[?contains(roleName,''<part of name>'')].{n:roleName,id:name}" -o table'
        }

        Write-Log "Resource providers"
        foreach ($ns in 'Microsoft.Web', 'Microsoft.Storage', 'Microsoft.CognitiveServices', 'Microsoft.ManagedIdentity', 'Microsoft.OperationalInsights', 'Microsoft.Insights') {
            Check "Provider $ns" {
                $st = az provider show --namespace $ns --query registrationState -o tsv 2>$null
                if ($st -ne 'Registered') { throw "state: $st" }
                $st
            } "az provider register --namespace $ns   (takes a minute; rerun this check)"
        }

        Write-Log "Region: $($cfg['location'])"
        $loc = $cfg['location']
        Check 'Flex Consumption available in region' {
            $regions = az functionapp list-flexconsumption-locations --query '[].name' -o tsv 2>$null
            if (-not $regions) { return 'WARN could not list (old az?); eastus2 is known good' }
            $names = @($regions -split "`n" | ForEach-Object { $_.Trim().ToLower() -replace ' ', '' })
            if ($names -notcontains $loc.ToLower()) { throw "$loc not in: $($names -join ', ')" }
            $loc
        } 'pick a region from az functionapp list-flexconsumption-locations'
        Check "Model $($cfg['parameters']['modelName']) $($cfg['parameters']['modelVersion']) in region" {
            $m = $cfg['parameters']['modelName']; $v = $cfg['parameters']['modelVersion']
            $json = az cognitiveservices model list --location $loc -o json 2>$null
            if (-not $json) { return 'WARN could not list models' }
            $models = $json | ConvertFrom-Json
            $hit = $models | Where-Object { $_.model.name -eq $m -and $_.model.version -eq $v -and $_.kind -eq 'AIServices' }
            if (-not $hit) {
                $versions = ($models | Where-Object { $_.model.name -eq $m } | ForEach-Object { $_.model.version } | Sort-Object -Unique) -join ', '
                if ($versions) { throw "version $v not offered; versions here: $versions" }
                throw "model $m not offered in $loc"
            }
            $skus = ($hit | ForEach-Object { $_.model.skus.name } | Sort-Object -Unique) -join ', '
            if ($skus -notmatch 'GlobalStandard') { return "WARN offered, but SKUs are: $skus (template uses GlobalStandard)" }
            "offered · SKUs: $skus"
        } "change modelName / modelVersion in env/$Name.json"
        Check 'Cognitive Services quota (AIServices S0)' {
            $usage = az cognitiveservices usage list --location $loc -o json 2>$null
            if (-not $usage) { return 'WARN could not read usage' }
            'readable'
        } ''
    }

    Write-Host ""
    if ($failed -eq 0) { Write-Log "All checks passed. Next: ./deploy.ps1 -Name $Name" }
    else { Write-Log "$failed check(s) failed. Fix them, then rerun ./check.ps1 -Name $Name" }

    if ($script:cfg) {
        $cfg = $script:cfg
        $cfg['checks'] = @{ at = (Get-Date).ToUniversalTime().ToString('o'); failed = $failed; results = $results }
        Save-Env $cfg 'check.ps1' "$failed failed"
    }
    Write-Log "Log: $log"
    if ($failed -gt 0) { exit 1 }
}
finally {
    Stop-Log
}
