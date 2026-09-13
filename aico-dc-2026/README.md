# Your First AI Automation Pipeline

Drop a résumé into a SharePoint folder. A minute later a row appears in a SharePoint list with the
candidate's details pulled off the page, a score for the résumé, what is strong about it, what is
missing, and a three-sentence summary a recruiter could read instead of opening the file.

That is the whole demo. It was built for the *Your First AI Automation Pipeline* session at the
AI Community Conference DC 2026, and it is small on purpose: three Azure Functions, one managed
identity, two prompt files, and no keys or secrets anywhere.

## How it works

1. **SharePoint tells us a file arrived.** Microsoft Graph sends a change notification to a small
   web endpoint. The endpoint checks it is genuine and drops a "go look" message on a queue. That is
   all it does, so it always answers fast.
2. **A worker looks.** It asks Graph what changed in the watched folder since last time, and queues
   one message per new file.
3. **The worker reads each file.** It downloads it, turns it into text (or page images if it is a
   scan), and sends the whole thing to a gpt-5-mini model in Microsoft Foundry with two prompts: one
   that says who the model is and the rules it must follow, and one that says what to pull out of a
   résumé and how to score it. The answer comes back as JSON in a fixed shape.
4. **The answer is written down.** One row per file in a SharePoint list called *Pipeline Log*:
   the file name as the title, the JSON as the body. A copy also goes to blob storage.
5. **A timer keeps it alive.** Every fifteen minutes it renews the Graph subscription, queues a
   catch-up scan in case a notification was missed, and clears old bookkeeping rows.

Everything talks to everything else with one managed identity. It can see one SharePoint site and
nothing else.

## What you need

- An Azure subscription where you can create resources and assign roles
- A SharePoint site with a document library, and admin rights on the tenant for two one-time steps
- PowerShell 7 and the Azure CLI on your machine

`DEPLOY.md` has the full list, with a command to check each one.

## How to use it

Everything is run from PowerShell 7, from the `infra/scripts` folder.

```powershell
az login
Copy-Item ../env/example.json ../env/demo.json     # then edit: your site URL, library, folder
./check.ps1 -Name demo                             # checks every prerequisite; fix any FAIL
./deploy.ps1 -Name demo                            # creates the Azure resources (~5 min)
./grant-graph.ps1 -Name demo                       # lets the identity into your SharePoint site
./publish.ps1 -Name demo                           # uploads the code (~3 min)
```

Then drop a résumé (PDF) into the folder you named. Within a minute or two, open *Site contents*
on your SharePoint site and look for the **Pipeline Log** list.

When you are done:

```powershell
./remove.ps1 -Name demo                            # deletes everything it created
```

Each script writes a log to `infra/logs` and records what it learned in `infra/env/demo.json`, so a
step that fails can be rerun without starting over. `DEPLOY.md` walks through each step in detail,
including what to do when something does not work.

## Where to change things

| Want to | Change |
|---|---|
| Watch a different site, library or folder | `infra/env/demo.json`, then rerun `grant-graph.ps1` and `deploy.ps1 -Reuse` |
| Change what is pulled out or how it is scored | `app/prompts/extract_resume.txt`, then `publish.ps1` |
| Change the rules the model must follow | `app/prompts/system.txt`, then `publish.ps1` |
| Score résumés against a specific job | add an app setting `RESUME_TARGET_ROLE` with the role or job description |
| Use a different model | `modelName` and `modelVersion` in `infra/env/demo.json`, then `deploy.ps1 -Reuse` |

## What is in the folder

| Folder | What |
|---|---|
| `infra/` | the Azure resources as Bicep, and the scripts that stand everything up and tear it down |
| `app/` | the Function App: `function_app.py` has the three functions, `pipeline/` does the work |
| `app/prompts/` | the two prompt files |
| `provision/` | a fallback browser script for preparing the site by hand, if the Graph PowerShell module is not available |

## Three lessons from building it

- **Notifications expire quietly.** Subscribe to the library as a list (30 days, not 3) and let a
  timer keep one subscription renewed.
- **A timer does not start itself.** On the Flex Consumption plan, "run on startup" does nothing
  after a deploy. A short schedule is what gets the pipeline going.
- **Silence is not success.** The host hides your own log lines by default. Turn function logging
  up, and make the pipeline leave a visible mark, like creating its list on the first timer run.
