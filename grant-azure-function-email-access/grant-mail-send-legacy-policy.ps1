<#
    The OLDER way to fence an app to one mailbox: grant Mail.Send in Microsoft
    Entra ID, then restrict it with an Exchange application access policy.

    Microsoft now labels application access policies as legacy and points to
    RBAC for Applications instead (see grant-mail-send-rbac.ps1). This script is
    kept because plenty of tenants are already set up this way, and because the
    ordering below is the part people get wrong.

    ORDERING IS DELIBERATE. Mail.Send as an application permission is
    TENANT-WIDE - while it is granted and unfenced, the identity can send as any
    mailbox in the tenant. So this script creates the policy FIRST and grants
    the permission LAST, and the Exchange preflight fails before any grant is
    made. There is no window where the grant exists without its fence.

        Install-Module Microsoft.Graph, ExchangeOnlineManagement -Scope CurrentUser

        ./grant-mail-send-legacy-policy.ps1 `
            -TenantId 00000000-0000-0000-0000-000000000000 `
            -ManagedIdentityObjectId 22222222-2222-2222-2222-222222222222 `
            -ServiceMailbox notifications@contoso.com

    WHO RUNS IT
    Global Administrator (or Privileged Role Administrator) for the Entra grant,
    AND Exchange Organization Management for the policy. App-role assignments
    cannot be granted to a managed identity through the portal at all - which is
    the whole reason this is a script.
#>
param(
    [Parameter(Mandatory)] [string] $TenantId,                 # pins the admin session to the right tenant
    [Parameter(Mandatory)] [string] $ManagedIdentityObjectId,  # the Function App's system-assigned identity
    [Parameter(Mandatory)] [string] $ServiceMailbox,           # e.g. notifications@contoso.com
    [string] $ScopeGroup = "notifications-scope"               # mail-enabled security group the policy scopes to
)

# Fail loud - a partial grant on a security-critical script is worse than none.
$ErrorActionPreference = "Stop"

# Microsoft Graph's well-known first-party application id. The same in every tenant.
$graphAppId = "00000003-0000-0000-c000-000000000000"

Connect-MgGraph -TenantId $TenantId -Scopes "AppRoleAssignment.ReadWrite.All","Application.Read.All"

$graphSp  = Get-MgServicePrincipal -Filter "appId eq '$graphAppId'"
$miSp     = Get-MgServicePrincipal -ServicePrincipalId $ManagedIdentityObjectId
$existing = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentityObjectId -All

<#
    Assigning a Graph *application* role is an admin-consent operation: the
    signed-in account must be Global Administrator or Privileged Role
    Administrator. A 403 Authorization_RequestDenied here means it is not -
    Exchange or SharePoint admin is not sufficient.
#>
function Add-GraphAppRole {
    param([Parameter(Mandatory)] [string] $RoleName)

    $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq $RoleName -and $_.AllowedMemberTypes -contains "Application" }
    if (-not $appRole) { throw "Graph app role '$RoleName' not found (or not exposed as an Application role)." }

    if ($existing | Where-Object { $_.AppRoleId -eq $appRole.Id -and $_.ResourceId -eq $graphSp.Id }) {
        Write-Host "Already assigned $RoleName - skipping"
        return
    }

    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ManagedIdentityObjectId -ErrorAction Stop -BodyParameter @{
        principalId = $ManagedIdentityObjectId
        resourceId  = $graphSp.Id
        appRoleId   = $appRole.Id
    } | Out-Null
    Write-Host "Granted $RoleName"
}

# ---- 1. The fence, created BEFORE the grant ---------------------------------
Connect-ExchangeOnline

# Interactive Connect-ExchangeOnline cannot be pre-pinned to a tenant the way
# Connect-MgGraph can, and it may reuse a cached session - so verify the
# connected tenant before touching any mail policy.
$exoTenant = (Get-ConnectionInformation | Select-Object -First 1).TenantId
if ($exoTenant -and $exoTenant -ne $TenantId) {
    throw "Connected to Exchange Online tenant $exoTenant but expected $TenantId - disconnect and sign in to the correct tenant."
}

# The *-ApplicationAccessPolicy cmdlets are only imported for accounts holding
# Exchange Organization Management. If they are missing, the signed-in account is
# not an Exchange administrator - stop with a clear message rather than a
# "term is not recognized" further down. This preflight runs BEFORE any grant, so
# a non-Exchange-admin run cannot leave the identity holding unfenced mail access.
if (-not (Get-Command New-ApplicationAccessPolicy -ErrorAction SilentlyContinue)) {
    throw "New-ApplicationAccessPolicy is unavailable - run as an Exchange Administrator (Organization Management)."
}

# PolicyScopeGroupId must be a security principal. A plain mailbox address is
# rejected with "The identity of the policy scope is not a security principal."
# So: a mail-enabled security group whose only member is the service mailbox.
$grp = Get-DistributionGroup -Identity $ScopeGroup -ErrorAction SilentlyContinue
if (-not $grp) {
    $grp = New-DistributionGroup -Name $ScopeGroup -Type Security `
        -Members $ServiceMailbox -Notes "Application access policy scope"
    Write-Host "Created mail-enabled security group $($grp.PrimarySmtpAddress)"
} else {
    if (-not (Get-DistributionGroupMember -Identity $grp.Identity | Where-Object { $_.PrimarySmtpAddress -eq $ServiceMailbox })) {
        Add-DistributionGroupMember -Identity $grp.Identity -Member $ServiceMailbox
    }
    Write-Host "Using existing scope group $($grp.PrimarySmtpAddress)"
}

# Enumerating policies can throw a transient "object OU=...\* couldn't be found"
# error right after the scope group is created. Tolerate it, treat as "none".
$existingPolicy = $null
try {
    $existingPolicy = Get-ApplicationAccessPolicy -ErrorAction Stop |
        Where-Object { $_.AppId -eq $miSp.AppId -and $_.ScopeName -eq $ScopeGroup }
} catch {
    Write-Warning "Could not enumerate existing application access policies ($($_.Exception.Message)) - proceeding."
}

if ($existingPolicy) {
    Write-Host "Application access policy already present - skipping"
} else {
    New-ApplicationAccessPolicy -AppId $miSp.AppId -PolicyScopeGroupId $grp.PrimarySmtpAddress `
        -AccessRight RestrictAccess -Description "Restrict mail to the service mailbox"
    Write-Host "Created application access policy"
}

# ---- 2. The grant, now that the fence is in place ---------------------------
# Send-only. Mail.Read is deliberately absent: this identity never reads mail.
Add-GraphAppRole "Mail.Send"

# ---- 3. Verify the fence ----------------------------------------------------
# The service mailbox is IN the scope group, so its Granted result is immediate.
# Assert it and fail loud if the fence did not take.
$fence = Test-ApplicationAccessPolicy -AppId $miSp.AppId -Identity $ServiceMailbox
if ($fence.AccessCheckResult -ne "Granted") {
    throw "Fence verification failed: expected 'Granted' for $ServiceMailbox but got '$($fence.AccessCheckResult)'. Is the mailbox a member of '$ScopeGroup'?"
}
Write-Host "Fence verified: Mail.Send is Granted for $ServiceMailbox"

# The policy's DENY side can take up to ~30 minutes to propagate across Exchange
# Online, so testing an out-of-scope mailbox may briefly still return Granted.
# The ordering above guarantees no grant is made without the policy already
# existing; the propagation lag itself is inherent and unavoidable.
