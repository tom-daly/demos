# Infrastructure

Everything the pipeline runs on, as Bicep, plus the scripts that stand it up, connect it to
SharePoint, publish the code, and tear it down. No keys anywhere: the function app has one user-assigned managed
identity and every service it touches is reached with that identity.

## What gets created

| Resource                             | Name pattern                | Why                                                               |
| ------------------------------------ | --------------------------- | ----------------------------------------------------------------- |
| Resource group                       | `rg-<env>-dev-<4 random>` | fresh one per deploy so a broken run never taints the next        |
| User-assigned identity               | `id-func-<env>-<token>`   | the one identity the function app uses everywhere                 |
| Storage account                      | `st<env><token>`          | keys disabled; blob + queue + table below                         |
| &nbsp; blob `deployments`          |                             | Flex Consumption keeps the zipped app here                        |
| &nbsp; blob `incoming`             |                             | temp copy of each file while it is processed; deleted after 1 day |
| &nbsp; blob `results`              |                             | JSON result per document; deleted after 30 days                   |
| &nbsp; queue `documents`           |                             | one message per file; the host adds`documents-poison`           |
| &nbsp; table `State`               |                             | delta tokens, subscriptions, "already seen" rows                  |
| SharePoint list `Pipeline Log` (not ARM) | | one row per document: Title = file name, Body = the JSON answer; the function creates it on first use |
| Foundry account                      | `ai-<env>-<token>`        | kind AIServices, project management on, local auth off            |
| &nbsp; project                       | `proj-<env>`              |                                                                   |
| &nbsp; model deployment              | `<modelName>`             | GlobalStandard, capacity from the env file                        |
| Log Analytics + App Insights         | `log-…`, `appi-…`     |                                                                   |
| Flex Consumption plan + Function App | `plan-…`, `func-…`    | Linux, identity-based host storage                                |

Role assignments, all scoped to the single resource, for the function identity and optionally you:

| On      | Role                                                                                    |
| ------- | --------------------------------------------------------------------------------------- |
| storage | Storage Blob Data Owner, Storage Queue Data Contributor, Storage Table Data Contributor |
| Foundry | Foundry User, Cognitive Services OpenAI User, Cognitive Services User                   |

Graph permissions are not ARM resources. `grant-graph.ps1` assigns the `Sites.Selected`
application role to the identity, then (signed in as you through the Graph PowerShell module) checks
the library exists, creates the watched folder, and grants the identity *manage* on that one site.
The function creates the lists it writes to on first use. Without the module the script falls back to
two copy/paste files; `../provision/setup-site.js` is the template.

## Expiry

- **Blobs** expire through a storage lifecycle policy (real TTL, set in `modules/storage.bicep`).
- **Table rows do not.** Azure Table Storage has no per-row TTL. Every row in `State` and `Jobs`
  carries an `ExpiresAt` column and a timer function deletes rows past it once an hour. If that
  ever feels flimsy, the same code runs unchanged against Cosmos DB for Table, which does have
  native TTL, at a higher cost.

Rows in `State`, by partition key:

| PartitionKey     | RowKey                                                   | Columns                                         | Expires                                                                         |
| ---------------- | -------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------- |
| `delta`        | drive id                                                 | `DeltaLink`, `UpdatedAt`                    | never (replaced on every walk)                                                  |
| `subscription` | drive id                                                 | `SubscriptionId`, `Resource`, `ExpiresAt` | Graph's own expiry (≤ 3 days for drive items); renewed by a timer a day before |
| `seen`         | `<itemId>:<eTag>`                                      | `ProcessedAt`, `ExpiresAt`                  | 7 days; stops a redelivered notification from processing a file twice           |
| `config`       | `siteId`, `driveId`, `folderId`, `resultsListId` | `Value`                                       | never; looked up once                                                           |



## Files

```
infra/
  main.bicep               entry point; names, layout, wiring
  modules/
    storage.bicep          account, containers, queue, tables, lifecycle, roles
    foundry.bicep          account, project, model deployment, roles
    monitoring.bicep       Log Analytics + App Insights
    function.bicep         plan, function app, app settings
  env/
    example.json           copy to <name>.json; the one place inputs and outputs live
  scripts/
    common.ps1             read/save env json, logging, Graph helper
    check.ps1              prerequisites: tools, sign-in, rights, providers, region, model; read-only
    deploy.ps1             new resource group + deployment; writes outputs + appSettings
    grant-graph.ps1        Sites.Selected, then writes env/<name>.setup-site.js + .grant-site.md for the two browser pastes
    publish.ps1            func publish + function key + Graph subscription; records URLs
    make-local-settings.ps1  app/local.settings.json from the env file, for running on your PC
    remove.ps1             deletes the resource group and the Graph grants
  logs/                    one transcript per script run (git-ignored)
```

## Run it

```powershell
cd infra/scripts
Copy-Item ../env/example.json ../env/aico.json     # then edit sharePointSiteUrl etc.
az login
./check.ps1 -Name aico                              # prerequisites; fix every FAIL first
./deploy.ps1 -Name aico                             # creates rg-aico-dev-xxxx, deploys, saves outputs
./grant-graph.ps1 -Name aico                        # Entra admin; then paste A (site console) and B (Graph Explorer)
./publish.ps1 -Name aico                            # code up, subscription created, URLs printed
./remove.ps1 -Name aico                             # when done
```

`deploy.ps1 -Name aico -Reuse` redeploys into the resource group already in the env file.
`deploy.ps1 -Name aico -WhatIf` shows the change set without touching anything.

Step-by-step version with what each step needs: `../DEPLOY.md`.

Every script writes a transcript to `logs/` and updates `env/<name>.json`:

- `outputs` — every Bicep output (function URL, webhook URL, identity ids, endpoints, storage name)
- `appSettings` — exactly what `local.settings.json` needs for running the functions on your machine
- `graph` — site id, drive id, folder id, app role assignment id, site permission id
- `history` — one line per script run

Commit `env/example.json` only. Real env files hold a webhook secret and tenant ids.

## Decisions and open items

- **Model default is gpt-5-mini / 2025-08-07.** Confirm it is still offered in the region before the
  talk; change it in the env file, not the template.
- **Runtime is Python 3.12.** The code in `../app` is Python; the env file's runtime setting must stay `python`.
- **Region default is eastus2**, which has Flex Consumption and GlobalStandard model deployments.
- **Sites.Selected, not Sites.Read.All.** The identity can see one site and nothing else. That
  is the point of the demo's "least access" line.
- **The library is subscribed as a list, not a drive.** List subscriptions last 30 days and work with
  Sites.Selected (proven on this tenant by the survey project); drive subscriptions last under three
  days and are unproven under that permission. The housekeeping timer (every 15 minutes) renews it,
  queues a catch-up scan, and sweeps expired table rows.
- **Not in Bicep:** the SharePoint results list. The code creates it on first use with the columns it needs.
