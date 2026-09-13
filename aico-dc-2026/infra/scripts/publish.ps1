<#
.SYNOPSIS
  Publishes the function code in app/ to the Function App recorded in env/<name>.json, then
  creates the Graph subscription and records the function key and URLs.

.DESCRIPTION
  Zips sample/app (without local settings, virtual envs or caches) and pushes it with
  az functionapp deployment source config-zip --build-remote: Azure installs requirements.txt itself.
  Nothing to install locally beyond the Azure CLI; Functions Core Tools is not used (older builds do
  not understand Flex Consumption apps).
  The Graph subscription is owned by the app's renew timer (startup + every 6 h), so publishing
  does not touch it. The function key and the URLs are written back to the env file.

.EXAMPLE
  ./publish.ps1 -Name aico
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Name
)

. (Join-Path $PSScriptRoot 'common.ps1')

$log = Start-Log 'publish' $Name
try {
    $cfg = Read-Env $Name
    Assert-AzLogin $cfg | Out-Null
    $o = $cfg['outputs']
    if (-not $o['functionAppName']) { throw "No functionAppName in outputs. Run deploy.ps1 first." }
    $appDir = Join-Path (Split-Path -Parent $script:InfraRoot) 'app'
    $zip = Join-Path ([IO.Path]::GetTempPath()) "docpipe-$Name-$((Get-Date).ToString('yyyyMMdd-HHmmss')).zip"
    $exclude = @('local.settings.json', '.venv', 'venv', '__pycache__', '.pytest_cache', '.mypy_cache', '.vscode')
    # Stage a clean copy first: Compress-Archive flattens folder paths when handed a list of files.
    $staging = Join-Path ([IO.Path]::GetTempPath()) "docpipe-$Name-staging"
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
    $files = Get-ChildItem $appDir -Recurse -File | Where-Object {
        $rel = $_.FullName.Substring($appDir.Length + 1)
        -not ($exclude | Where-Object { $rel -eq $_ -or $rel.StartsWith("$_\") -or $rel -like "*\$_\*" })
    }
    foreach ($f in $files) {
        $dest = Join-Path $staging $f.FullName.Substring($appDir.Length + 1)
        New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
        Copy-Item $f.FullName $dest
    }
    Write-Log "Zipping $($files.Count) files from $appDir"
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zip -Force
    Remove-Item $staging -Recurse -Force
    $cfg['lastZip'] = @{ path = $zip; files = $files.Count; bytes = (Get-Item $zip).Length }

    Write-Log "Publishing to $($o['functionAppName']) (remote build; Azure installs requirements.txt)"
    az functionapp deployment source config-zip --resource-group $cfg['resourceGroup'] --name $o['functionAppName'] `
        --src $zip --build-remote true --timeout 600 --only-show-errors --output none
    if ($LASTEXITCODE -ne 0) { throw "zip deploy failed (exit $LASTEXITCODE). Log stream: az webapp log deployment show -g $($cfg['resourceGroup']) -n $($o['functionAppName'])" }
    Remove-Item $zip -Force -ErrorAction SilentlyContinue

    # Confirm the host indexed our functions before going on.
    Write-Log "Waiting for the app to list its functions"
    $names = @()
    for ($i = 1; $i -le 12 -and $names.Count -eq 0; $i++) {
        Start-Sleep -Seconds 10
        $names = @(az functionapp function list -g $cfg['resourceGroup'] -n $o['functionAppName'] --query '[].name' -o tsv --only-show-errors 2>$null | ForEach-Object { $_.Split('/')[-1] })
    }
    if ($names.Count -eq 0) { throw "The app lists no functions after deployment. Check: az webapp log deployment show -g $($cfg['resourceGroup']) -n $($o['functionAppName'])" }
    Write-Log "Functions: $($names -join ', ')"
    $cfg['functions'] = $names

    $cfg['lastPublish'] = @{ at = (Get-Date).ToUniversalTime().ToString('o'); app = $o['functionAppName'] }

    # Function key (kept on record; no keyed endpoints exist today)
    $keys = az functionapp keys list --name $o['functionAppName'] --resource-group $cfg['resourceGroup'] | ConvertFrom-Json
    $cfg['secrets']['functionKey'] = $keys.functionKeys.default
    $base = $o['functionAppUrl']
    $cfg['urls'] = @{
        webhook = "$base/api/webhook"
    }
    Save-Env $cfg 'publish.ps1' "published $($o['functionAppName'])"

    # The subscription is owned by the app's own timer (runs at startup and every 6 h): it creates it,
    # keeps exactly one, and renews it. Nothing to do here. POST the subscribe URL below to force it now.
    Write-Log ""
    Write-Log "Webhook: $($cfg['urls']['webhook'])  (the app's housekeeping timer subscribes it at startup)"
    Write-Log "Try it: drop a PDF into the watched folder; within a minute a row appears in the Pipeline Log list."
    Write-Log "Log: $log"
}
finally {
    Stop-Log
}
