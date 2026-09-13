<#
.SYNOPSIS
  Connects the function's managed identity to one existing SharePoint library.

.DESCRIPTION
  Part 1 runs here, with your az login (needs a Global, Privileged Role or Application Administrator):
    assign the Graph application role Sites.Selected to the managed identity, and record the site id.

  Part 2 cannot run from the Azure CLI: Microsoft's own CLI app is not allowed to ask Graph for
  SharePoint scopes (AADSTS65002). The Microsoft Graph PowerShell module can. So, as in the LGP
  project, the script signs you in with Connect-MgGraph asking for Sites.FullControl.All (browser,
  consent as admin, once) and then, with your token:
    - finds the library (it must exist; never created), creates the watched folder if missing
    - grants the identity manage on this one site (manage, not write: the function creates the
      lists it writes to, the first time it needs them)

  If the module is not installed, it writes the same work as two copy/paste files instead, filled in
  for this environment (env/<name>.setup-site.js for F12 > Console on the site, and
  env/<name>.grant-site.md for Graph Explorer), as the survey project did.

  Rerunning is safe.

.EXAMPLE
  ./grant-graph.ps1 -Name aico
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Name
)

. (Join-Path $PSScriptRoot 'common.ps1')

$GraphAppId = '00000003-0000-0000-c000-000000000000'
$SitesSelectedRoleId = '883ea226-0bf2-4a8f-9f9d-92c9162a727d'   # Sites.Selected (application)

$log = Start-Log 'grant-graph' $Name
try {
    $cfg = Read-Env $Name
    Assert-AzLogin $cfg | Out-Null
    $o = $cfg['outputs']; $p = $cfg['parameters']; $g = $cfg['graph']
    if (-not $o['identityPrincipalId']) { throw "No identityPrincipalId in outputs. Run deploy.ps1 first." }

    $principalId = $o['identityPrincipalId']
    $clientId = $o['identityClientId']
    $displayName = $o['functionAppName']
    Write-LogValues "Identity" @{ principalId = $principalId; clientId = $clientId; displayName = $displayName }

    # --- Part 1. Sites.Selected app role on the managed identity (Entra) ------
    $graphSp = Invoke-Graph GET "/servicePrincipals?`$filter=appId eq '$GraphAppId'&`$select=id"
    $graphSpId = $graphSp.value[0].id
    $g['graphServicePrincipalId'] = $graphSpId

    $existing = Invoke-Graph GET "/servicePrincipals/$principalId/appRoleAssignments"
    $already = $existing.value | Where-Object { $_.appRoleId -eq $SitesSelectedRoleId -and $_.resourceId -eq $graphSpId }
    if ($already) {
        Write-Log "Sites.Selected already assigned ($($already.id))"
        $g['appRoleAssignmentId'] = $already.id
    } else {
        $assignment = Invoke-Graph POST "/servicePrincipals/$principalId/appRoleAssignments" @{
            principalId = $principalId
            resourceId  = $graphSpId
            appRoleId   = $SitesSelectedRoleId
        }
        Write-Log "Assigned Sites.Selected ($($assignment.id))"
        $g['appRoleAssignmentId'] = $assignment.id
    }

    $uri = [uri]$p['sharePointSiteUrl']
    $site = Invoke-Graph GET "/sites/$($uri.Host):$($uri.AbsolutePath.TrimEnd('/'))"
    $g['siteId'] = $site.id
    $g['siteWebUrl'] = $site.webUrl
    Write-Log "Site $($site.webUrl) → $($site.id)"

    Save-Env $cfg 'grant-graph.ps1' 'Sites.Selected assigned; site id recorded'

    # --- Part 2a. With the Graph PowerShell module: do it here -----------------
    if (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication) {
        Import-Module Microsoft.Graph.Authentication
        Write-Log "Signing in with Connect-MgGraph for Sites.FullControl.All (browser; consent as admin the first time)"
        Connect-MgGraph -TenantId $cfg['tenantId'] -Scopes 'Sites.FullControl.All' -NoWelcome
        $ctx = Get-MgContext
        if (-not $ctx -or $ctx.Scopes -notcontains 'Sites.FullControl.All') { throw "Connected, but without Sites.FullControl.All. Consent was not given." }
        Write-Log "Connected as $($ctx.Account)"
        $mg = { param($Method, $Uri, $Body) if ($Body) { Invoke-MgGraphRequest -Method $Method -Uri "v1.0$Uri" -Body $Body -OutputType PSObject } else { Invoke-MgGraphRequest -Method $Method -Uri "v1.0$Uri" -OutputType PSObject } }

        # Library: must exist.
        $drives = (& $mg GET "/sites/$($site.id)/drives?`$select=id,name,webUrl").value
        $drive = $drives | Where-Object { $_.name -eq $p['sharePointLibrary'] } | Select-Object -First 1
        if (-not $drive) {
            throw "Library '$($p['sharePointLibrary'])' not found. Libraries on this site: $(($drives | ForEach-Object { $_.name }) -join ', '). Set sharePointLibrary in env/$Name.json to one of those and rerun."
        }
        $g['driveId'] = $drive.id; $g['libraryUrl'] = $drive.webUrl
        Write-Log "Library '$($drive.name)' → drive $($drive.id)"

        # Folder: create if missing.
        $folderPath = $p['sharePointFolder'].Trim('/')
        $folder = $null
        try { $folder = & $mg GET "/drives/$($drive.id)/root:/$folderPath" } catch { }
        if ($folder) { Write-Log "Folder '$folderPath' exists → $($folder.id)" }
        else {
            $folder = & $mg POST "/drives/$($drive.id)/root/children" @{ name = $folderPath; folder = @{}; '@microsoft.graph.conflictBehavior' = 'fail' }
            Write-Log "Created folder '$folderPath' → $($folder.id)"
        }
        $g['folderId'] = $folder.id; $g['folderUrl'] = $folder.webUrl

        # Site permission: manage, this one site. Manage (not write) because the function creates its own
        # lists (the logging list, the results list) the first time it needs them.
        $perms = (& $mg GET "/sites/$($site.id)/permissions").value
        $mine = $perms | Where-Object { @($_.grantedToIdentitiesV2.application.id) + @($_.grantedToIdentities.application.id) -contains $clientId } | Select-Object -First 1
        if ($mine -and ($mine.roles -contains 'manage' -or $mine.roles -contains 'fullcontrol')) {
            Write-Log "Site permission already present ($($mine.id)) with $($mine.roles -join ', ')"
            $g['sitePermissionId'] = $mine.id
        } elseif ($mine) {
            & $mg PATCH "/sites/$($site.id)/permissions/$($mine.id)" @{ roles = @('manage') } | Out-Null
            Write-Log "Raised site permission ($($mine.id)) from $($mine.roles -join ', ') to manage"
            $g['sitePermissionId'] = $mine.id
        } else {
            $perm = & $mg POST "/sites/$($site.id)/permissions" @{ roles = @('manage'); grantedToIdentities = @(@{ application = @{ id = $clientId; displayName = $displayName } }) }
            Write-Log "Granted manage on the site to $displayName ($($perm.id))"
            $g['sitePermissionId'] = $perm.id
        }
        Disconnect-MgGraph | Out-Null

        Save-Env $cfg 'grant-graph.ps1' 'library found, folder ready, site permission granted (manage)'
        Write-Log ""
        Write-Log "Next: ./publish.ps1 -Name $Name"
        Write-Log "Log: $log"
        return
    }

    # --- Part 2b. No Graph module: write the two copy/paste steps instead -----
    Write-Log "Microsoft.Graph.Authentication is not installed (Install-Module Microsoft.Graph.Authentication -Scope CurrentUser). Writing the copy/paste files instead."

    $template = Join-Path (Split-Path -Parent $script:InfraRoot) 'provision\setup-site.js'
    $js = (Get-Content $template -Raw).
        Replace('__SITE_URL__', $p['sharePointSiteUrl']).
        Replace('__LIBRARY__', $p['sharePointLibrary'].Replace("'", "\'")).
        Replace('__FOLDER__', $p['sharePointFolder'].Trim('/').Replace("'", "\'")).
        Replace('__RESULTS_LIST__', $p['sharePointResultsList'].Replace("'", "\'"))
    $jsPath = Join-Path $script:EnvDir "$Name.setup-site.js"
    Set-Content -Path $jsPath -Value $js -Encoding utf8

    $body = @{
        roles               = @('write')
        grantedToIdentities = @(@{ application = @{ id = $clientId; displayName = $displayName } })
    } | ConvertTo-Json -Depth 5
    $mdPath = Join-Path $script:EnvDir "$Name.grant-site.md"
    @"
# Let the identity into this one site

The identity has ``Sites.Selected``, which reaches **no** site until an admin names one. Once:

1. Open https://developer.microsoft.com/graph/graph-explorer and sign in as yourself (Global Admin).
2. If asked, consent to ``Sites.FullControl.All`` for Graph Explorer (Modify permissions tab).
3. Method **POST**, URL:

``````
https://graph.microsoft.com/v1.0/sites/$($site.id)/permissions
``````

4. Request body:

``````json
$body
``````

5. Run query. Expect **201 Created**. Copy the ``id`` from the response into ``env/$Name.json`` under ``graph.sitePermissionId`` (optional; remove.ps1 uses it).

``write`` lets the function read files in the library, and add rows to the results list. It cannot touch any other site.

To check later: GET the same URL lists every app with access to the site.
"@ | Set-Content -Path $mdPath -Encoding utf8

    $g['setupSiteScript'] = $jsPath
    $g['grantSiteNotes'] = $mdPath
    Save-Env $cfg 'grant-graph.ps1' 'Sites.Selected assigned; copy/paste files written'

    Write-Log ""
    Write-Log "Two copy/paste steps remain, done as you in a browser:"
    Write-Log "  A. Open $($p['sharePointSiteUrl'])  ->  F12  ->  Console  ->  paste the contents of:"
    Write-Log "       $jsPath"
    Write-Log "     Wait for ALL DONE. If it says the library was not found, it lists the libraries it saw."
    Write-Log "  B. Grant the identity write on the site in Graph Explorer, exactly as written in:"
    Write-Log "       $mdPath"
    Write-Log "Then: ./publish.ps1 -Name $Name"
    Write-Log "Log: $log"
}
finally {
    Stop-Log
}
