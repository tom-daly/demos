# Deploying it yourself

Everything here is typed into **PowerShell 7** (`pwsh`), on your PC, from the `sample\infra\scripts`
folder unless a step says otherwise. Each script writes a log to `sample\infra\logs\` and saves what it
learned into `sample\infra\env\aico.json`, so a failed step can be rerun without losing anything.

## Getting started

### Prerequisites

| Need                                                                                                                     | Why                                                                                                                                                                       | Check                                                                                                                                                                       | Install / fix                                                                                                                                                 |
| ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PowerShell 7 or later                                                                                                    | the scripts use`ConvertFrom-Json -AsHashtable` and `&&`, which Windows PowerShell 5.1 lacks                                                                           | `$PSVersionTable.PSVersion`                                                                                                                                               | `winget install Microsoft.PowerShell`, then open **pwsh**, not "Windows PowerShell"                                                                   |
| Azure CLI 2.60 or later                                                                                                  | deploys the Bicep; older versions predate Flex Consumption                                                                                                                | `az version`                                                                                                                                                              | `winget install Microsoft.AzureCLI` or `az upgrade`                                                                                                       |
| Bicep 0.30 or later                                                                                                      | compiles the templates (bundled with az)                                                                                                                                  | `az bicep version`                                                                                                                                                        | `az bicep install` or `az bicep upgrade`                                                                                                                  |
| Azure Functions Core Tools v4 (optional)                                                                                 | only for running the functions on your PC; publishing uses the Azure CLI                                                                                                  | `func --version`                                                                                                                                                          | `winget install Microsoft.Azure.FunctionsCoreTools`. Builds older than 4.0.5907 cannot publish to Flex Consumption, which is why the script does not use it |
| Python 3.12 (3.10+ works for a smoke test)                                                                               | only for running the functions on your PC; Azure has its own                                                                                                              | `python --version`                                                                                                                                                        | `winget install Python.Python.3.12`                                                                                                                         |
| An Azure subscription where you are**Owner** (or Contributor **and** User Access Administrator)              | the template creates role assignments                                                                                                                                     | `az role assignment list --assignee (az ad signed-in-user show --query id -o tsv) --scope /subscriptions/<id> --include-inherited --query "[].roleDefinitionName" -o tsv` | ask the subscription owner                                                                                                                                    |
| Resource providers registered: Microsoft.Web, Storage, CognitiveServices, ManagedIdentity, OperationalInsights, Insights | first-time subscriptions often have some unregistered                                                                                                                     | `az provider show --namespace Microsoft.Web --query registrationState`                                                                                                    | `az provider register --namespace <name>` (a minute each)                                                                                                   |
| A region with Flex Consumption and the model                                                                             | `eastus2` has both                                                                                                                                                      | `az cognitiveservices model list --location eastus2 --query "[?model.name=='gpt-5-mini'].model.version" -o tsv`                                                           | change`location` or `modelName` in the env file                                                                                                           |
| An Entra admin, for one command                                                                                          | assigning a Graph application role to the identity (step 4)                                                                                                               |                                                                                                                                                                             | Global, Privileged Role, or Application Administrator                                                                                                         |
| A SharePoint site with a library that already exists                                                                     | the pipeline watches a folder in that library; the script never creates a library                                                                                         | open the site, note the library name exactly as shown                                                                                                                       | put the name in`sharePointLibrary`                                                                                                                          |
| Microsoft Graph PowerShell module                                                                                        | the Azure CLI's sign-in may not ask Graph for SharePoint scopes; this module's may. The grant script uses it to make the folder and grant the identity manage on the site | `Get-Module -ListAvailable Microsoft.Graph.Authentication`                                                                                                                | `Install-Module Microsoft.Graph.Authentication -Scope CurrentUser`. Without it the script writes two copy/paste files for the browser instead.              |

You do **not** need: Visual Studio, Docker, the Azure portal (handy but optional), or any key or connection string.

### Prerequisites check

Two ways. The script is the normal one; the block below is the same checks, by hand, for when you
want to see each answer yourself.

**Script** (from `sample\infra\scripts`, read-only, logs to `logs\`, saves results to the env file):

```powershell
./check.ps1 -Name aico
```

**By hand**, paste into pwsh. Each line prints a name and a value; compare against the table above.

```powershell
"pwsh      $($PSVersionTable.PSVersion)"                       # want 7.x
"az        $((az version | ConvertFrom-Json).'azure-cli')"     # want 2.60+
"bicep     $((az bicep version 2>&1 | Select-String 'Bicep CLI version ([\d.]+)').Matches[0].Groups[1].Value)"   # want 0.30+
"func      $(func --version)"                                  # want 4.x
"python    $(python --version 2>&1)"                           # want 3.10+ (Azure runs 3.12)
$acct = az account show | ConvertFrom-Json
"login     $($acct.user.name) on '$($acct.name)' ($($acct.id))"   # the subscription you mean to use
$me = az ad signed-in-user show --query id -o tsv
"roles     $((az role assignment list --assignee $me --scope /subscriptions/$($acct.id) --include-inherited --query '[].roleDefinitionName' -o tsv) -join ', ')"   # want Owner, or Contributor + User Access Administrator
foreach ($ns in 'Microsoft.Web','Microsoft.Storage','Microsoft.CognitiveServices','Microsoft.ManagedIdentity','Microsoft.OperationalInsights','Microsoft.Insights') {
  "provider  $ns = $(az provider show --namespace $ns --query registrationState -o tsv)"   # want Registered
}
"flex      $((az functionapp list-flexconsumption-locations --query '[].name' -o tsv) -contains 'East US 2')"   # want True (needs az 2.60+)
"model     $(az cognitiveservices model list --location eastus2 --query "[?model.name=='gpt-5-mini' && kind=='AIServices'].model.version" -o tsv | Sort-Object -Unique)"   # want 2025-08-07 in the list
```

What each answer means:

| Line         | Good                                                              | If not                                                                                                                                                                  |
| ------------ | ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pwsh`     | starts with 7                                                     | you are in Windows PowerShell; open**pwsh**                                                                                                                       |
| `az`       | 2.60 or higher                                                    | `az upgrade`                                                                                                                                                          |
| `bicep`    | 0.30 or higher                                                    | `az bicep upgrade`                                                                                                                                                    |
| `func`     | starts with 4                                                     | install Core Tools v4                                                                                                                                                   |
| `python`   | 3.10 or higher                                                    | only matters for local runs                                                                                                                                             |
| `login`    | your account, the right subscription                              | `az login`, `az account set --subscription <id>`                                                                                                                    |
| `roles`    | contains Owner, or both Contributor and User Access Administrator | ask the subscription owner; deploy will fail on role assignments otherwise                                                                                              |
| `provider` | Registered, all six                                               | `az provider register --namespace <name>`, wait a minute, rerun                                                                                                       |
| `flex`     | True                                                              | False with an`az` below 2.60 just means the command is missing; upgrade az first. Otherwise pick another region from the list and change `location` in the env file |
| `model`    | includes 2025-08-07                                               | pick a listed version and change`modelVersion` in the env file                                                                                                        |

### 1. Sign in and pick the subscription

```powershell
az login
az account list --output table
az account set --subscription "<name or id>"
```

### 2. Fill in the environment file

```powershell
cd infra   # from the folder this file is in
Copy-Item env\example.json env\aico.json
notepad env\aico.json
```

| Field                 | What to put                                                                    |
| --------------------- | ------------------------------------------------------------------------------ |
| `sharePointSiteUrl` | the site to watch, e.g.`https://yourtenant.sharepoint.com/sites/DocPipeline` |
| `sharePointLibrary` | the library name as shown in SharePoint, usually`Documents`                  |
| `sharePointFolder`  | a folder inside that library; created if missing                               |
| `location`          | `eastus2` unless you have a reason                                           |

Leave `resourceGroup` empty. Leave `subscriptionId` empty too; the checker and the deploy script record it.

### 3. Run the checker (if you have not already)

```powershell
cd scripts
./check.ps1 -Name aico
```

It prints PASS / WARN / FAIL for every line in the prerequisites table, tells you the fix for each
FAIL, and writes the results into the env file under `checks`. Nothing is created or changed.
Rerun until there are no FAILs. WARNs are informational.

## Deploying

### 4. Deploy the Azure resources (about 5 minutes)

```powershell
./deploy.ps1 -Name aico -WhatIf      # optional: lists what would be created, touches nothing
./deploy.ps1 -Name aico
```

You will see the parameters, then the outputs: function app name, URLs, identity ids, endpoints.
The resource group is named `rg-aico-dev-` plus four random characters. Afterwards `env\aico.json`
has `outputs`, `appSettings` and a `history` line.

If the model deployment fails on availability, change `modelName` / `modelVersion` in the env file
and run `./deploy.ps1 -Name aico -Reuse` to redeploy into the same resource group.

### 5. Give the identity access to SharePoint

```powershell
./grant-graph.ps1 -Name aico
```

- As an Entra admin, with your Azure CLI sign-in: assigns the "selected sites only" Graph permission
  to the function's identity and records the site id.
- Then a browser opens for a second sign-in through the Microsoft Graph PowerShell module, asking for
  the one SharePoint scope. Consent as admin the first time. With that, the script finds the library
  named in the env file (it must already exist; if the name is wrong it lists the libraries it found),
  creates the watched folder if missing, and grants the identity *manage* on that one site. Manage
  rather than write because the function creates its own lists the first time it needs them.

Why the second sign-in? Microsoft's own Azure CLI app is not allowed to ask Graph for SharePoint
scopes. The Graph PowerShell module's app is. Same approach as the LGP project.

If the module is not installed, the script writes two files instead, filled in for this environment:
`envico.setup-site.js` to paste into F12 > Console on the site, and `envico.grant-site.md` with
one POST for Graph Explorer. Same result, done by hand, as in the survey project.

Rerunning is safe; every step checks before it acts. Ids go into `envico.json` under `graph`.

### 6. Publish the function code (about 3 minutes)

```powershell
./publish.ps1 -Name aico
```

Zips `sample\app`, sends it up with the Azure CLI, lets Azure install the Python packages, waits
until the app lists its functions, and fetches the function key. At the end it prints:

- the webhook URL the subscription points at

The Graph change subscription is owned by the app's own timer: it creates it when the app starts,
keeps exactly one, renews it in time, and queues a catch-up scan every fifteen minutes.

## Trying it

1. Drop a PDF (a résumé, say) into the Incoming folder of the Documents library on the site.
2. Within about a minute a row appears in the **Pipeline Log** list on the same site. Title is the
   file name, Body is the whole JSON answer: what kind of document, the fields with the quote each
   came from, how sure, and which lane. The function creates the list itself on its first document.
3. If nothing appears after two minutes, look at the log stream (below). The housekeeping timer also
   queues a catch-up scan every fifteen minutes, so a missed notification is not fatal.

Watch the logs:

```powershell
func azure functionapp logstream (Get-Content ..\env\aico.json | ConvertFrom-Json).outputs.functionAppName
```

Or in the portal: the Function App → *Log stream*. Application Insights has the same lines under
*Logs*: `traces | where message startswith "done"`.

## Tearing it down

```powershell
./remove.ps1 -Name aico
```

Deletes the resource group (in the background) and the two Graph grants, and blanks the env file so
the next `deploy.ps1` starts clean. Your logs and the env file's `history` are kept.

## Running the functions on your PC instead of in Azure

```powershell
./make-local-settings.ps1 -Name aico          # writes sample\app\local.settings.json from the env file
cd ..\..\app
python -m venv .venv; .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
func start
```

Your user account needs the same storage and Foundry roles as the identity; `deploy.ps1` grants them
because `developerPrincipalId` defaults to whoever is signed in. SharePoint calls run as you.

Change notifications cannot reach `localhost`. Start a dev tunnel
(`devtunnel host -p 7071 --allow-anonymous`) and pass its URL with
`./make-local-settings.ps1 -Name aico -PublicBaseUrl https://...`; the housekeeping timer then
subscribes that URL at startup and queues a scan.

## Who runs what

| Script              | Signed in as                                             | Rights                                                                                                   |
| ------------------- | -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `check.ps1`       | Azure user                                               | read-only                                                                                                |
| `deploy.ps1`      | Azure user                                               | Owner, or Contributor + User Access Administrator, on the subscription                                   |
| `grant-graph.ps1` | Entra admin (az) and Global Admin (Graph module sign-in) | assign a Graph application role; consent to Sites.FullControl.All; grant the identity manage on one site |
| `publish.ps1`     | Azure user                                               | Contributor on the resource group                                                                        |
| `remove.ps1`      | Azure user                                               | same as deploy                                                                                           |

## Where things are recorded

| What                                                     | Where                                                                     |
| -------------------------------------------------------- | ------------------------------------------------------------------------- |
| inputs you typed                                         | `env\aico.json` → `parameters`, `location`                         |
| checker results                                          | `env\aico.json` → `checks`                                           |
| resource group, Bicep outputs, app settings              | `env\aico.json` → `resourceGroup`, `outputs`, `appSettings`      |
| site / drive / folder ids, Graph grant ids, subscription | `env\aico.json` → `graph`                                            |
| function key and the URLs                                | `env\aico.json` → `secrets`, `urls`                                |
| every script run                                         | `env\aico.json` → `history`, and one transcript per run in `logs\` |

### Step-by-step trace of every file

Each file gets a trace: every step (download, read, model, check_prompt_version, route, record), what went into it,
what came out, how long it took, and any error. A scan gets one too (walk_delta, queue_new_files, save_delta_link).
The same trace is in three places:

| Where | What |
|---|---|
| Function log / Application Insights | one line per step, `step {json}`, plus `trace <id> start` and `trace <id> end` lines |
| Results container, `<item-id>/trace.json` | the full trace; failed attempts as `trace-attempt-<n>.json`, one per delivery |
| SharePoint logging list | the result row carries the trace under `trace` |

The big inputs and outputs are blobs next to the result, and the trace points at them under `artifacts`:
`<item-id>/document.txt` (the text sent to the model), `<item-id>/model-request.json` (the exact request; page
images replaced by their byte count), `<item-id>/model-response.json` (the raw API response, tokens included).

Application Insights query for the last hour of steps, slowest first:

```
traces
| where timestamp > ago(1h) and message startswith "step "
| extend s = parse_json(substring(message, 5))
| project timestamp, trace = tostring(s.trace), subject = tostring(s.subject), step = tostring(s.step), status = tostring(s.status), ms = toint(s.ms), inputs = s.inputs, outputs = s.outputs, error = tostring(s.error)
| order by ms desc
```
