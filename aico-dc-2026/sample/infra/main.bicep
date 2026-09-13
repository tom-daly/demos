// Your First AI Automation Pipeline — infrastructure
// Deploys: storage (blob + queue + table), Microsoft Foundry (account, project, model deployment),
// Log Analytics + Application Insights, a Flex Consumption Function App with a user-assigned
// managed identity, and the role assignments that let the identity reach storage and Foundry
// without any keys. Microsoft Graph permissions are granted separately (scripts/grant-graph.ps1)
// because they live in Entra, not in ARM.

targetScope = 'resourceGroup'

@description('Short name for this environment, used in resource names. Letters and digits only; anything else is stripped.')
@minLength(2)
@maxLength(10)
param environmentName string

@description('Azure region. Needs Flex Consumption Functions and the chosen model. eastus2 works for both.')
param location string = resourceGroup().location

@description('SharePoint site the pipeline watches, e.g. https://contoso.sharepoint.com/sites/Documents')
param sharePointSiteUrl string

@description('Document library on that site.')
param sharePointLibrary string = 'Documents'

@description('Folder inside the library. Only files under this folder are processed.')
param sharePointFolder string = 'Incoming'

@description('SharePoint list where extracted results are written (structured; off by default).')
param sharePointResultsList string = 'Document Results'

@description('SharePoint list where every result is logged: Title = file name, Body = the JSON answer.')
param sharePointLogList string = 'Pipeline Log'

@description('Model to deploy in Foundry. Check availability in the region before changing.')
param modelName string = 'gpt-5-mini'
param modelVersion string = '2025-08-07'

@description('Tokens-per-minute capacity in thousands for the model deployment.')
@minValue(1)
param modelCapacity int = 50

@description('Function runtime. Changing this changes the code, not just the template.')
@allowed(['python', 'node', 'dotnet-isolated'])
param functionRuntime string = 'python'
param functionRuntimeVersion string = '3.12'

@description('Object id of a developer (you) who should get the same data-plane roles for running the functions locally. Leave empty to skip.')
param developerPrincipalId string = ''

@description('Shared secret echoed back by Graph on every change notification so the webhook can reject strangers.')
@secure()
param webhookClientState string = newGuid()

param tags object = {
  project: 'aico-dc-2026'
  purpose: 'sample'
}

// ---------------------------------------------------------------------------

var resourceToken = toLower(uniqueString(subscription().id, resourceGroup().id, environmentName))
// Resource names allow letters, digits and (mostly) hyphens only. Storage accounts and the Foundry
// subdomain allow no hyphens at all. So the environment name is reduced to lowercase letters and digits.
var env = toLower(replace(replace(replace(environmentName, '_', ''), '-', ''), ' ', ''))
var names = {
  identity: 'id-func-${env}-${resourceToken}'
  storage: 'st${env}${resourceToken}'          // 3-24 chars, lowercase alphanumeric
  foundry: 'ai-${env}-${resourceToken}'
  project: 'proj-${env}'
  logAnalytics: 'log-${env}-${resourceToken}'
  appInsights: 'appi-${env}-${resourceToken}'
  plan: 'plan-${env}-${resourceToken}'
  functionApp: 'func-${env}-${resourceToken}'
}

// Storage layout. The function code reads these names from app settings, so change them here only.
var storageLayout = {
  deploymentsContainer: 'deployments'   // Flex Consumption keeps the zipped app here
  incomingContainer: 'incoming'         // temp copy of each file while it is processed (deleted after 1 day)
  resultsContainer: 'results'           // JSON result per document (deleted after 30 days)
  queueName: 'documents'                // one message per file to process
  stateTable: 'State'                   // delta link, subscription, "already seen" rows, cached ids
}

// ---------------------------------------------------------------------------

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: names.identity
  location: location
  tags: tags
}

// Everyone who needs data-plane access. The function's identity always; you optionally.
var principals = concat(
  [{ id: identity.properties.principalId, type: 'ServicePrincipal' }],
  empty(developerPrincipalId) ? [] : [{ id: developerPrincipalId, type: 'User' }]
)

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: names.logAnalytics
    appInsightsName: names.appInsights
    location: location
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    name: names.storage
    location: location
    tags: tags
    layout: storageLayout
    principals: principals
  }
}

module foundry 'modules/foundry.bicep' = {
  name: 'foundry'
  params: {
    name: names.foundry
    projectName: names.project
    location: location
    tags: tags
    modelName: modelName
    modelVersion: modelVersion
    modelCapacity: modelCapacity
    principals: principals
  }
}

module functionApp 'modules/function.bicep' = {
  name: 'function-app'
  params: {
    planName: names.plan
    appName: names.functionApp
    location: location
    tags: tags
    identityId: identity.id
    identityClientId: identity.properties.clientId
    runtime: functionRuntime
    runtimeVersion: functionRuntimeVersion
    storageAccountName: storage.outputs.accountName
    deploymentsContainer: storageLayout.deploymentsContainer
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    appSettings: {
      // Storage (identity-based; no keys anywhere)
      STORAGE_ACCOUNT_NAME: storage.outputs.accountName
      STORAGE_INCOMING_CONTAINER: storageLayout.incomingContainer
      STORAGE_RESULTS_CONTAINER: storageLayout.resultsContainer
      STORAGE_QUEUE_NAME: storageLayout.queueName
      STORAGE_STATE_TABLE: storageLayout.stateTable
      // Foundry
      FOUNDRY_ENDPOINT: foundry.outputs.endpoint
      FOUNDRY_OPENAI_ENDPOINT: foundry.outputs.openAiEndpoint
      FOUNDRY_PROJECT_ENDPOINT: foundry.outputs.projectEndpoint
      FOUNDRY_MODEL_DEPLOYMENT: foundry.outputs.deploymentName
      // SharePoint / Graph
      SHAREPOINT_SITE_URL: sharePointSiteUrl
      SHAREPOINT_LIBRARY: sharePointLibrary
      SHAREPOINT_FOLDER: sharePointFolder
      SHAREPOINT_RESULTS_LIST: sharePointResultsList
      SHAREPOINT_LOG_LIST: sharePointLogList
      WRITE_RESULTS_LIST: 'false'
      GRAPH_WEBHOOK_CLIENT_STATE: webhookClientState
      // Makes DefaultAzureCredential pick the user-assigned identity
      AZURE_CLIENT_ID: identity.properties.clientId
    }
  }
}

// ---------------------------------------------------------------------------

output functionAppName string = functionApp.outputs.name
output functionAppUrl string = 'https://${functionApp.outputs.hostName}'
output webhookUrl string = 'https://${functionApp.outputs.hostName}/api/webhook'
output identityClientId string = identity.properties.clientId
output identityPrincipalId string = identity.properties.principalId
output storageAccountName string = storage.outputs.accountName
output foundryEndpoint string = foundry.outputs.endpoint
output foundryProjectEndpoint string = foundry.outputs.projectEndpoint
output modelDeployment string = foundry.outputs.deploymentName
