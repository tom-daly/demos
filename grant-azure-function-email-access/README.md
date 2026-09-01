# Grant Azure Function Email Access

Companion code for the blog post
**[Letting an Azure Function Send Email as One Mailbox — and Only One](https://thomasdaly.net/)**.

The problem these scripts solve: the `Mail.Send` application permission in
Microsoft Graph is **tenant-wide**. Grant it to your app and, until you scope it,
that app can send mail as anybody in the organisation — the CEO included. There
is no "just this one mailbox" option in the consent dialog.

Two ways to scope it. Both end with the app able to send as exactly one mailbox.

| File | Approach | Use it when |
|---|---|---|
| `grant-mail-send-rbac.ps1` | **RBAC for Applications** in Exchange Online. Nothing is granted in Entra ID at all — the permission is created inside Exchange already carrying its scope. | New setups. This is Microsoft's current guidance. |
| `grant-mail-send-legacy-policy.ps1` | Tenant-wide `Mail.Send` in Entra ID, restricted afterwards by an **application access policy**. | You already have policies in place, or you are supporting a tenant that does. Microsoft now labels this approach legacy. |
| `send-mail.ts` | The calling code. Managed identity, no secrets, one `sendMail` call. | Either approach — the app code is identical. |

## Before you run either script

- The **mailbox must already exist**. A shared mailbox is the right shape: it
  costs no licence and nobody signs into it.
- The Function App needs a **system-assigned managed identity** turned on. Both
  scripts take that identity's app ID and object ID, not an app registration's.
- Install the modules:
  ```powershell
  Install-Module ExchangeOnlineManagement -Scope CurrentUser
  Install-Module Microsoft.Graph -Scope CurrentUser   # legacy script only
  ```

## The current way

```powershell
./grant-mail-send-rbac.ps1 `
    -Mailbox  notifications@contoso.com `
    -Tenant   00000000-0000-0000-0000-000000000000 `
    -AppId    11111111-1111-1111-1111-111111111111 `
    -ObjectId 22222222-2222-2222-2222-222222222222
```

Run by an account in the Exchange **Organization Management** role group.
Global Administrator on its own is not enough — handing out an application role
needs what Exchange calls a *delegating* assignment, and only that group has one.
The script checks up front and tells you how to fix it.

It creates three things and then proves the result with
`Test-ServicePrincipalAuthorization`. Safe to run twice.

## The legacy way

```powershell
./grant-mail-send-legacy-policy.ps1 `
    -TenantId 00000000-0000-0000-0000-000000000000 `
    -ManagedIdentityObjectId 22222222-2222-2222-2222-222222222222 `
    -ServiceMailbox notifications@contoso.com
```

Needs Global Administrator (for the Entra grant) **and** Exchange Organization
Management (for the policy).

The ordering in that script is the important part: the policy is created
**first** and the permission granted **last**, so the tenant-wide grant never
exists without its restriction. Do it the other way round and there is a window —
minutes, if something goes wrong, longer — where your app can send as anyone.

## Don't do both

If an app has RBAC for Applications *and* an unscoped `Mail.Send` grant in Entra,
the two are a union and the unscoped grant wins. If you migrate from the legacy
approach to RBAC, remove the Entra app-role assignment afterwards.

## Gotchas worth knowing

- **`Connect-ExchangeOnline` may not connect where you asked.** It will reuse a
  cached session for a different tenant. Both scripts verify the connected tenant
  before creating anything.
- **Some Exchange failures are non-terminating.** `$ErrorActionPreference = "Stop"`
  does not convert them, so a refusal prints and the script sails on. Both scripts
  verify each step after it runs rather than assuming it worked.
- **Scope filters: use `Alias`, not `PrimarySmtpAddress`.** A recipient filter on
  the primary address also searches every proxy address on the recipient, which
  quietly widens the scope.
- **`Enable-OrganizationCustomization` cannot be undone.** Management scopes need
  it. The RBAC script names the command rather than running it for you.
- **The legacy policy's *deny* side takes up to ~30 minutes to propagate.**
  Testing an out-of-scope mailbox right after creation may still say `Granted`.
