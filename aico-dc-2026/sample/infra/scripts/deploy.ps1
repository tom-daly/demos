<#
.SYNOPSIS
  Deploys the pipeline infrastructure into a fresh resource group and records everything in env/<name>.json.

.DESCRIPTION
  Default run: creates rg-<env>-dev-<4 random chars>, deploys main.bicep into it, writes the outputs,
  the resource group name and the app settings back into env/<name>.json, and logs to logs/.
  -Reuse: deploy into the resource group already recorded in the env file instead of a new one.
  -Recover: do not deploy; pick up the outputs of the last successful deployment in that group
            (for when the deployment finished but the script failed afterwards).

.EXAMPLE
  ./deploy.ps1 -Name aico
  ./deploy.ps1 -Name aico -Reuse
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Name,
    [switch]$Reuse,
    [switch]$WhatIf,
    [switch]$Recover     # skip deploying; read the outputs of the last successful deployment in the recorded resource group
)

. (Join-Path $PSScriptRoot 'common.ps1')

$log = Start-Log 'deploy' $Name
try {
    $cfg = Read-Env $Name
    $account = Assert-AzLogin $cfg
    $p = $cfg['parameters']
    if ($cfg['environmentName'] -notmatch '^[a-z0-9]{2,10}$') {
        throw "environmentName '$($cfg['environmentName'])' must be 2-10 lowercase letters and digits (storage account and Foundry subdomain rules). Change it in env/$Name.json; the file name can stay."
    }

    # --- Resource group -------------------------------------------------------
    if ($Recover) {
        $rg = $cfg['resourceGroup']
        if (-not $rg) { throw "No resourceGroup in the env file to recover from." }
        $last = az deployment group list --resource-group $rg --only-show-errors --query "[?properties.provisioningState=='Succeeded'] | sort_by(@, &properties.timestamp) | [-1].name" -o tsv
        if (-not $last) { throw "No successful deployment found in $rg." }
        Write-Log "Recovering outputs of deployment $last in $rg"
        $deploymentName = $last
        $raw = az deployment group show --name $last --resource-group $rg --output json --only-show-errors
    } elseif ($Reuse -and $cfg['resourceGroup']) {
        $rg = $cfg['resourceGroup']
        Write-Log "Reusing resource group $rg"
    } else {
        $rg = "rg-$($cfg['environmentName'])-dev-$(New-RandomSuffix 4)"
        $cfg['resourceGroup'] = $rg
        Write-Log "New resource group $rg in $($cfg['location'])"
        if (-not $WhatIf) {
            az group create --name $rg --location $cfg['location'] --tags project=aico-dc-2026 purpose=sample environment=$($cfg['environmentName']) --output none
        }
    }

    # --- Secrets: generated once, kept in the env file so redeploys don't rotate them ---
    if (-not $cfg['secrets']['webhookClientState']) {
        $cfg['secrets']['webhookClientState'] = [guid]::NewGuid().ToString()
        Write-Log "Generated webhook client state"
    }

    # --- Developer principal: default to the signed-in user so local runs work ---
    if (-not $p['developerPrincipalId']) {
        $me = az ad signed-in-user show --query id -o tsv 2>$null
        if ($me) { $p['developerPrincipalId'] = $me; Write-Log "developerPrincipalId defaulted to signed-in user $me" }
    }

    Write-LogValues "Parameters" $p
    # Save now, so a failed deployment still leaves the resource group name on record for -Reuse or remove.ps1.
    Save-Env $cfg 'deploy.ps1' "starting deployment into $rg"

    # --- Deploy ----------------------------------------------------------------
    $template = Join-Path $script:InfraRoot 'main.bicep'
    if (-not $Recover) {
    $deploymentName = "docpipe-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
    $params = @(
        "environmentName=$($cfg['environmentName'])",
        "location=$($cfg['location'])",
        "sharePointSiteUrl=$($p['sharePointSiteUrl'])",
        "sharePointLibrary=$($p['sharePointLibrary'])",
        "sharePointFolder=$($p['sharePointFolder'])",
        "sharePointResultsList=$($p['sharePointResultsList'])",
        "sharePointLogList=$($p['sharePointLogList'])",
        "modelName=$($p['modelName'])",
        "modelVersion=$($p['modelVersion'])",
        "modelCapacity=$($p['modelCapacity'])",
        "functionRuntime=$($p['functionRuntime'])",
        "functionRuntimeVersion=$($p['functionRuntimeVersion'])",
        "developerPrincipalId=$($p['developerPrincipalId'])",
        "webhookClientState=$($cfg['secrets']['webhookClientState'])"
    )

    $mode = if ($WhatIf) { 'what-if' } else { 'create' }
    Write-Log "az deployment group $mode --name $deploymentName --resource-group $rg"
    # --only-show-errors keeps "new Bicep release" warnings out of the JSON we parse.
    $raw = az deployment group $mode --name $deploymentName --resource-group $rg `
        --template-file $template --parameters @params --output json --only-show-errors 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Deployment failed:`n$raw" }
    $raw = ($raw | ForEach-Object { "$_" }) -join "`n"
    $raw = $raw.Substring([Math]::Max(0, $raw.IndexOf('{')))

    if ($WhatIf) {
        Write-Host $raw
        Save-Env $cfg 'deploy.ps1' "what-if in $rg"
        return
    }
    }   # end of deploy (skipped with -Recover)

    $result = $raw | ConvertFrom-Json
    $outputs = @{}
    foreach ($prop in $result.properties.outputs.PSObject.Properties) {
        $outputs[$prop.Name] = $prop.Value.value
    }
    $cfg['outputs'] = $outputs
    $cfg['lastDeployment'] = @{
        name              = $deploymentName
        resourceGroup     = $rg
        provisioningState = $result.properties.provisioningState
        at                = (Get-Date).ToUniversalTime().ToString('o')
    }
    Write-LogValues "Outputs" $outputs

    # --- App settings mirror: what local.settings.json needs, in one place ---
    $cfg['appSettings'] = @{
        AZURE_CLIENT_ID             = $outputs['identityClientId']
        STORAGE_ACCOUNT_NAME        = $outputs['storageAccountName']
        STORAGE_INCOMING_CONTAINER  = 'incoming'
        STORAGE_RESULTS_CONTAINER   = 'results'
        STORAGE_QUEUE_NAME          = 'documents'
        STORAGE_STATE_TABLE         = 'State'
        FOUNDRY_ENDPOINT            = $outputs['foundryEndpoint']
        FOUNDRY_PROJECT_ENDPOINT    = $outputs['foundryProjectEndpoint']
        FOUNDRY_MODEL_DEPLOYMENT    = $outputs['modelDeployment']
        SHAREPOINT_SITE_URL         = $p['sharePointSiteUrl']
        SHAREPOINT_LIBRARY          = $p['sharePointLibrary']
        SHAREPOINT_FOLDER           = $p['sharePointFolder']
        SHAREPOINT_RESULTS_LIST     = $p['sharePointResultsList']
        SHAREPOINT_LOG_LIST         = $p['sharePointLogList']
        WRITE_RESULTS_LIST          = 'false'
        GRAPH_WEBHOOK_CLIENT_STATE  = $cfg['secrets']['webhookClientState']
    }

    Save-Env $cfg 'deploy.ps1' "$(if ($Recover) { 'recovered' } else { 'deployed' }) $deploymentName into $rg"

    Write-Log ""
    Write-Log "Next: ./grant-graph.ps1 -Name $Name   (gives the function's identity access to the SharePoint site)"
    Write-Log "Log: $log"
}
finally {
    Stop-Log
}
