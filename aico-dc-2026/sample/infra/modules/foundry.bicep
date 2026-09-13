// Microsoft Foundry: one AI Services account with project management on, one project,
// one model deployment. Local auth is off, so callers must use Entra identities.
param name string
param projectName string
param location string
param tags object
param modelName string
param modelVersion string
param modelCapacity int

@description('Identities that may call the model: [{ id, type }].')
param principals array

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: name
  location: location
  tags: tags
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: name
    allowProjectManagement: true
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: account
  name: projectName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: projectName
    description: 'Document pipeline sample (AICO DC 2026)'
  }
}

resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: account
  name: modelName
  sku: { name: 'GlobalStandard', capacity: modelCapacity }
  properties: {
    model: { format: 'OpenAI', name: modelName, version: modelVersion }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

// Foundry User (formerly Azure AI User) covers the project endpoint (agents, evaluations). Cognitive Services OpenAI User
// covers the plain OpenAI endpoint. Cognitive Services User covers Document Intelligence and the
// rest of the AI Services surface if the code needs OCR.
var roles = {
  foundryUser: '53ca6127-db72-4b80-b1b0-d745d6d5456d'
  cognitiveServicesOpenAiUser: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  cognitiveServicesUser: 'a97b65f3-24c7-4388-baec-2e87135dc908'
}

// Every principal x every role, as a flat list.
var assignments = flatten(map(principals, p => map(items(roles), r => {
  principalId: p.id
  principalType: p.type
  roleId: r.value
})))

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for a in assignments: {
    name: guid(account.id, a.principalId, a.roleId)
    scope: account
    properties: {
      principalId: a.principalId
      principalType: a.principalType
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', a.roleId)
    }
  }
]

output accountName string = account.name
output accountId string = account.id
output endpoint string = account.properties.endpoint
output openAiEndpoint string = 'https://${account.name}.openai.azure.com/'
output projectEndpoint string = 'https://${account.name}.services.ai.azure.com/api/projects/${project.name}'
output deploymentName string = deployment.name
