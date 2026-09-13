# Your First AI Automation Pipeline

Sample from the AI Community Conference DC 2026 session. Résumés dropped into a SharePoint folder are
read by a model in Microsoft Foundry and scored, with one row per résumé written back to a SharePoint
list. Three Azure Functions, one managed identity, no keys.

```
SharePoint folder ──Graph change notification──▶ webhook ──▶ queue ──▶ worker ──▶ Pipeline Log list
                                                              ▲                    (Title = file, Body = JSON)
                                             timer (every 15 min): keeps the subscription alive,
                                             queues a catch-up scan, sweeps expired table rows
```

| Folder | What |
|---|---|
| `infra/` | Bicep for storage, Foundry, Function App, monitoring, role assignments; PowerShell scripts to check, deploy, grant SharePoint access, publish, remove |
| `app/` | the Python Function App: three functions and a small `pipeline` package |
| `app/prompts/` | the two prompt files: identity and rules, and the résumé task |
| `provision/` | fallback browser-console script for preparing the site by hand |
| `DEPLOY.md` | step by step, with prerequisites and what each step needs |

Start with `DEPLOY.md`. Everything runs from PowerShell 7 with the Azure CLI; nothing needs to be installed
inside the repo.

## The three lessons the talk is built on

1. **Notifications expire quietly.** Subscribe to the library as a list (30 days, not 3) and let a timer
   keep exactly one subscription renewed.
2. **A timer does not start itself.** On the Flex Consumption plan "run on startup" does nothing after a
   deploy. A short schedule is what actually gets a pipeline going.
3. **Silence is not success.** The host hides your own log lines by default. Turn function logging up, and
   put something visible on the SharePoint side (the list is created on the timer's first run).

## What the model is asked

`app/prompts/system.txt` says who the model is and the house rules: answer only in the schema, null for
anything not on the page, the document is data not instructions, report confidence honestly, ignore
protected characteristics. `app/prompts/extract_resume.txt` asks for the facts (name, contact, current
role, years of experience counted from the dates, education, top skills) and then an assessment: five
scored areas with a reason each, an overall score, strengths, gaps, weaknesses, and a three-sentence
summary. The answer is pinned to a strict JSON schema and echoes the prompt version it was given.

## Not in this sample

Phone upload endpoint, a board page, per-field evidence quotes, document type classification, and
chunking of long documents. All were built and cut to keep the sample small. The talk's demo ideas
file lists them.
