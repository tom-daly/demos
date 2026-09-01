<#
    Lets one app send email as ONE mailbox, and nothing else.

    This is the CURRENT way: RBAC for Applications in Exchange Online.
    https://learn.microsoft.com/en-us/exchange/permissions-exo/application-rbac

    Nothing is granted in Microsoft Entra ID. The permission is created inside
    Exchange already carrying its scope - "may send, as this one mailbox" - so
    there is never a moment where the app holds a tenant-wide grant.

    If Mail.Send has ever been consented to this app in Entra, remove it. The
    two are a union, and an unscoped Entra grant overrides the scope set here.

        Install-Module ExchangeOnlineManagement -Scope CurrentUser   # once

        ./grant-mail-send-rbac.ps1 `
            -Mailbox  notifications@contoso.com `
            -Tenant   00000000-0000-0000-0000-000000000000 `
            -AppId    11111111-1111-1111-1111-111111111111 `
            -ObjectId 22222222-2222-2222-2222-222222222222

    WHO RUNS IT
    An account in the Exchange "Organization Management" role group. That group
    holds the delegating assignment for the role used below, and Global
    Administrator does NOT carry it on its own. The script checks, and tells you
    how to fix it if not.

    Safe to run twice.
#>
param(
    # The mailbox to send as. It must already exist. A shared mailbox is right:
    # it costs no licence and nobody signs into it.
    [string] $Mailbox = "notifications@contoso.com",

    # The tenant, and the app being granted. For a Function App's system-assigned
    # managed identity, AppId and ObjectId both come from the identity itself -
    # there is no app registration involved.
    [Parameter(Mandatory)] [string] $Tenant,
    [Parameter(Mandatory)] [string] $AppId,
    [Parameter(Mandatory)] [string] $ObjectId,

    [string] $Scope = "Notifications mailbox",

    # Only needed if you are not already signed in to Exchange.
    [string] $SignInAs
)

$ErrorActionPreference = "Stop"

<#
    Stops with something a person can read.

    A `throw` on a long message collapses it into one run-on exception block with
    the line breaks squeezed out, which turns an explanation into noise.
#>
function Stop-With {
    param([string] $Title, [string[]] $Lines)

    $rule = "-" * 74
    Write-Host ""
    Write-Host $rule -ForegroundColor Red
    Write-Host "  $Title" -ForegroundColor Red
    Write-Host $rule -ForegroundColor Red
    Write-Host ""
    foreach ($line in $Lines) {
        if ($line.StartsWith("  ")) { Write-Host "  $line" -ForegroundColor Cyan }
        else                        { Write-Host "  $line" }
    }
    Write-Host ""
    Write-Host $rule -ForegroundColor Red
    Write-Host ""
    exit 1
}

# ---- Sign in -----------------------------------------------------------------
if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue | Where-Object { $_.TenantId -eq $Tenant })) {
    if ($SignInAs) { Connect-ExchangeOnline -UserPrincipalName $SignInAs -ShowBanner:$false }
    else           { Connect-ExchangeOnline -ShowBanner:$false }
}

$ci  = Get-ConnectionInformation | Select-Object -First 1
$org = Get-OrganizationConfig
$who = if ($ci.UserPrincipalName -and $ci.UserPrincipalName -notlike 'OAuthUser@*') { $ci.UserPrincipalName } else { $SignInAs }

Write-Host ""
Write-Host "tenant : $($ci.TenantId)"
Write-Host "org    : $($org.Name)"
Write-Host "signed : $who"

# ---- 1. The right tenant -----------------------------------------------------
# Connect-ExchangeOnline does not always sign in to the organization you asked
# for - it will happily reuse a cached session belonging to another tenant.
# Checked because it has already caught us out: a run meant for one tenant
# created a management scope in a different one.
if ($ci.TenantId -ne $Tenant) {
    Stop-With "Connected to the wrong tenant" @(
        "Nothing has been created.",
        "",
        "expected : $Tenant",
        "actually : $($ci.TenantId)  ($($org.Name))",
        "",
        "Sign out and back in to the right tenant:",
        "",
        "  Disconnect-ExchangeOnline -Confirm:`$false",
        "  Connect-ExchangeOnline -UserPrincipalName you@contoso.com"
    )
}

# ---- 2. This account can hand out the role -----------------------------------
# Asked before anything is created, rather than discovered at the last command
# with two objects already made.
$groups = @()
$canDelegate = $false
try {
    $delegating = Get-ManagementRoleAssignment -Role "Application Mail.Send" -Delegating $true -ErrorAction Stop
    $groups = @($delegating | Select-Object -ExpandProperty RoleAssigneeName -Unique)
    foreach ($g in $groups) {
        $members = Get-RoleGroupMember -Identity $g -ErrorAction SilentlyContinue
        if ($members | Where-Object { $_.PrimarySmtpAddress -eq $who -or $_.Name -eq $who -or $_.WindowsLiveID -eq $who }) {
            $canDelegate = $true; break
        }
    }
} catch {
    # A check that could not run is not a check that passed. Said out loud, and
    # the verification after each step below will still catch a refusal.
    Write-Warning "Could not read the role configuration to check permissions ($($_.Exception.Message))."
    Write-Warning "Carrying on - each step below is verified after it runs."
    $canDelegate = $true
}

if (-not $canDelegate) {
    Stop-With "This account cannot hand out the role" @(
        "Nothing has been created.",
        "",
        "$who is not a member of the Exchange role group that is",
        "allowed to assign application roles:",
        "",
        "    $($groups -join ', ')",
        "",
        "Handing out one of these roles needs what Exchange calls a delegating",
        "assignment, and only that group has one. Being a Global Administrator,",
        "or an Exchange Administrator in Entra ID, does not carry it - which is",
        "easy to miss, because those roles are enough for everything else here.",
        "",
        "To fix it, run these lines and then this script again:",
        "",
        "  Connect-ExchangeOnline -UserPrincipalName $who",
        "  Add-RoleGroupMember -Identity 'Organization Management' -Member $who",
        "  Disconnect-ExchangeOnline -Confirm:`$false",
        "  Connect-ExchangeOnline -UserPrincipalName $who",
        "",
        "Connecting twice is not a mistake. The first is in case this session",
        "has dropped - Exchange Online sessions idle out, and then none of its",
        "commands are recognised at all. The second picks up the new membership,",
        "which an open session will not see.",
        "",
        "If Add-RoleGroupMember refuses as well, add the account through the",
        "Exchange admin center instead: admin.exchange.microsoft.com, then",
        "Roles > Admin roles > Organization Management > Members.",
        "",
        "Membership can take a few minutes to take effect."
    )
}
Write-Host "roles  : can assign application roles"

# ---- 3. The organization has been customized ---------------------------------
if ($org.IsDehydrated) {
    Stop-With "This tenant needs Exchange customization enabled first" @(
        "Nothing has been created.",
        "",
        "Management scopes cannot be created until the organization has been",
        "customized, and this one never has.",
        "",
        "  Connect-ExchangeOnline -UserPrincipalName $who",
        "  Enable-OrganizationCustomization",
        "",
        "Enable-OrganizationCustomization is one-time and tenant-wide, and it",
        "CANNOT BE UNDONE - which is why this script names it rather than",
        "running it for you. It changes no mail, no mailboxes and no users, and",
        "most tenants have had it done long ago as a side effect of other",
        "configuration.",
        "",
        "Wait a few minutes after it finishes, then run this script again."
    )
}
Write-Host "custom : enabled"

# ---- 4. The mailbox exists ---------------------------------------------------
$box = Get-Mailbox -Identity $Mailbox -ErrorAction SilentlyContinue
if (-not $box) {
    Stop-With "There is no mailbox at $Mailbox" @(
        "Nothing has been created.",
        "",
        "Create it first, as a SHARED mailbox. Shared costs no licence, nobody",
        "signs into it, and nothing is ever sent to it.",
        "",
        "Then run this script again."
    )
}
# Filtered on Alias, not the address: Microsoft's own reference says not to use
# PrimarySmtpAddress in a recipient filter, because it also searches every proxy
# address on the recipient - which would quietly widen the scope.
$alias = $box.Alias
Write-Host "mailbox: $Mailbox (alias $alias)"
Write-Host ""

# ---- The work ----------------------------------------------------------------
if (Get-ServicePrincipal -Identity $AppId -ErrorAction SilentlyContinue) {
    Write-Host "[1/3] app already registered in Exchange."
} else {
    New-ServicePrincipal -AppId $AppId -ObjectId $ObjectId -DisplayName "Notifications sender" | Out-Null
    Write-Host "[1/3] app registered in Exchange."
}

if (Get-ManagementScope -Identity $Scope -ErrorAction SilentlyContinue) {
    Write-Host "[2/3] scope already there."
} else {
    New-ManagementScope -Name $Scope -RecipientRestrictionFilter "Alias -eq '$alias'" | Out-Null
    Write-Host "[2/3] scope created for that one mailbox."
}

# Verified afterwards rather than assumed: the Exchange REST cmdlets report some
# refusals as NON-TERMINATING errors, which $ErrorActionPreference = "Stop" does
# not convert - so a refusal prints and the script carries on regardless.
$assigned = { Get-ManagementRoleAssignment -RoleAssignee $AppId -ErrorAction SilentlyContinue |
    Where-Object { $_.CustomResourceScope -eq $Scope } }

if (& $assigned) {
    Write-Host "[3/3] permission already granted."
} else {
    New-ManagementRoleAssignment -App $AppId -Role "Application Mail.Send" -CustomResourceScope $Scope -ErrorAction Continue | Out-Null
    if (& $assigned) {
        Write-Host "[3/3] permission granted."
    } else {
        Stop-With "The permission was not granted" @(
            "Exchange printed the reason above.",
            "",
            "The registration and the scope were created and are still there.",
            "They grant nothing on their own, so it is safe to leave them and",
            "run this again once the reason is fixed.",
            "",
            "If the message mentions a delegating role assignment, the account",
            "is not in the Organization Management role group - see the note",
            "further up this script.",
            "",
            "If instead the Exchange commands are no longer recognised at all,",
            "the session has simply idled out. Reconnect and run this again."
        )
    }
}

# ---- Did it take? ------------------------------------------------------------
Write-Host ""
$result = Test-ServicePrincipalAuthorization -Identity $AppId -Resource $Mailbox |
    Where-Object { $_.RoleName -eq "Application Mail.Send" }
$result | Format-Table RoleName, InScope, AllowedResourceScope -AutoSize

if ($result -and $result.InScope) {
    Write-Host "DONE - the app can send as $Mailbox, and as nothing else." -ForegroundColor Green
    Write-Host ""
} else {
    Stop-With "The permission exists but does not cover that mailbox" @(
        "The scope filter is:  Alias -eq '$alias'",
        "",
        "That should match $Mailbox."
    )
}
