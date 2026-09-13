<#
.SYNOPSIS
  Writes app/local.settings.json from the appSettings block that deploy.ps1 saved in env/<name>.json,
  so the functions run on your machine against the real storage, Foundry and SharePoint.

.DESCRIPTION
  Locally the Functions host and the code both sign in as you (az login), so the "managed identity"
  lines are left out. Your user needs the same data-plane roles the identity has; deploy.ps1 grants
  them when developerPrincipalId is set (it defaults to the signed-in user).

.EXAMPLE
  ./make-local-settings.ps1 -Name aico
  ./make-local-settings.ps1 -Name aico -PublicBaseUrl https://abc123.devtunnels.ms
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Name,
    [string]$PublicBaseUrl
)

. (Join-Path $PSScriptRoot 'common.ps1')

$log = Start-Log 'make-local-settings' $Name
try {
    $cfg = Read-Env $Name
    if (-not $cfg.ContainsKey('appSettings') -or -not $cfg['appSettings']) { throw "No appSettings in the env file. Run deploy.ps1 first." }

    $values = [ordered]@{
        FUNCTIONS_WORKER_RUNTIME        = 'python'
        AzureWebJobsFeatureFlags        = 'EnableWorkerIndexing'
        AzureWebJobsStorage__accountName = $cfg['appSettings']['STORAGE_ACCOUNT_NAME']
    }
    foreach ($k in ($cfg['appSettings'].Keys | Sort-Object)) {
        if ($k -eq 'AZURE_CLIENT_ID') { continue }   # locally we are a user, not the identity
        $values[$k] = $cfg['appSettings'][$k]
    }
    if ($PublicBaseUrl) { $values['PUBLIC_BASE_URL'] = $PublicBaseUrl.TrimEnd('/') }
    elseif ($cfg.ContainsKey('localPublicBaseUrl') -and $cfg['localPublicBaseUrl']) { $values['PUBLIC_BASE_URL'] = $cfg['localPublicBaseUrl'] }

    $appDir = Join-Path (Split-Path -Parent $script:InfraRoot) 'app'
    $target = Join-Path $appDir 'local.settings.json'
    @{ IsEncrypted = $false; Values = $values } | ConvertTo-Json -Depth 5 | Set-Content $target -Encoding utf8

    Write-LogValues "local.settings.json values" ([hashtable]$values)
    Write-Log "Wrote $target"

    $cfg['localSettingsPath'] = $target
    if ($PublicBaseUrl) { $cfg['localPublicBaseUrl'] = $PublicBaseUrl.TrimEnd('/') }
    Save-Env $cfg 'make-local-settings.ps1' "wrote $target"
    Write-Log "Log: $log"
}
finally {
    Stop-Log
}
