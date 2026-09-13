<#
.SYNOPSIS
  Deletes the resource group recorded in env/<name>.json and clears the outputs.
  The Graph app role assignment and the SharePoint site permission are removed too when their ids are known.

.EXAMPLE
  ./remove.ps1 -Name aico
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Name,
    [switch]$KeepGraph
)

. (Join-Path $PSScriptRoot 'common.ps1')

$log = Start-Log 'remove' $Name
try {
    $cfg = Read-Env $Name
    Assert-AzLogin $cfg | Out-Null
    $rg = $cfg['resourceGroup']
    $g = $cfg['graph']

    if (-not $KeepGraph) {
        if ($g['appRoleAssignmentId'] -and $cfg['outputs']['identityPrincipalId']) {
            Write-Log "Removing Sites.Selected assignment $($g['appRoleAssignmentId'])"
            try {
                Invoke-Graph DELETE "/servicePrincipals/$($cfg['outputs']['identityPrincipalId'])/appRoleAssignments/$($g['appRoleAssignmentId'])" | Out-Null
            } catch { Write-Log "  (already gone or no rights: $($_.Exception.Message))" }
        }
        if ($g['sitePermissionId'] -and $g['siteId']) {
            Write-Log "Removing site permission $($g['sitePermissionId'])"
            try {
                Invoke-Graph DELETE "/sites/$($g['siteId'])/permissions/$($g['sitePermissionId'])" | Out-Null
            } catch { Write-Log "  (revoke it in Graph Explorer: DELETE https://graph.microsoft.com/v1.0/sites/$($g['siteId'])/permissions/$($g['sitePermissionId']))" }
        }
    }

    if ($rg) {
        $exists = az group exists --name $rg
        if ($exists -eq 'true') {
            Write-Log "Deleting resource group $rg (runs in the background in Azure)"
            az group delete --name $rg --yes --no-wait --output none
        } else {
            Write-Log "Resource group $rg does not exist"
        }
    } else {
        Write-Log "No resource group recorded"
    }

    $cfg['removed'] = @{ resourceGroup = $rg; at = (Get-Date).ToUniversalTime().ToString('o'); outputs = $cfg['outputs']; graph = $g }
    $cfg['resourceGroup'] = ''
    $cfg['outputs'] = @{}
    $cfg['graph'] = @{}
    $cfg.Remove('appSettings') | Out-Null
    $cfg.Remove('lastDeployment') | Out-Null
    Save-Env $cfg 'remove.ps1' "deleted $rg"
    Write-Log "Log: $log"
}
finally {
    Stop-Log
}
