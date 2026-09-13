// One storage account, keys switched off. Blob for temp files and results, a queue for work,
// tables for state. Blob containers get real expiry through a lifecycle policy.
// Azure Table Storage has no built-in row expiry, so every state row carries an ExpiresAt
// column and a timer function deletes rows past it (see README).
param name string
param location string
param tags object

@description('Container / queue / table names. Shared with the function app settings.')
param layout object

@description('Identities that get data-plane roles: [{ id, type }] where type is ServicePrincipal or User.')
param principals array

resource account 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false      // managed identity only; no keys to leak
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Enabled'
    networkAcls: { defaultAction: 'Allow', bypass: 'AzureServices' }
  }
}

// --- Blob -------------------------------------------------------------------

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: account
  name: 'default'
  properties: {
    deleteRetentionPolicy: { enabled: false }
  }
}

resource deploymentsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: layout.deploymentsContainer
  properties: { publicAccess: 'None' }
}

resource incomingContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: layout.incomingContainer
  properties: { publicAccess: 'None' }
}

resource resultsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: layout.resultsContainer
  properties: { publicAccess: 'None' }
}

// Temp files live one day, results thirty. This is the blob-side "TTL".
resource lifecycle 'Microsoft.Storage/storageAccounts/managementPolicies@2023-05-01' = {
  parent: account
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'expire-incoming'
          type: 'Lifecycle'
          definition: {
            filters: { blobTypes: ['blockBlob'], prefixMatch: ['${layout.incomingContainer}/'] }
            actions: { baseBlob: { delete: { daysAfterModificationGreaterThan: 1 } } }
          }
        }
        {
          enabled: true
          name: 'expire-results'
          type: 'Lifecycle'
          definition: {
            filters: { blobTypes: ['blockBlob'], prefixMatch: ['${layout.resultsContainer}/'] }
            actions: { baseBlob: { delete: { daysAfterModificationGreaterThan: 30 } } }
          }
        }
      ]
    }
  }
}

// --- Queue ------------------------------------------------------------------

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = {
  parent: account
  name: 'default'
}

// The Functions host creates "<name>-poison" itself for messages that fail five times.
resource documentsQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-05-01' = {
  parent: queueService
  name: layout.queueName
}

// --- Table ------------------------------------------------------------------

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  parent: account
  name: 'default'
}

resource stateTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01' = {
  parent: tableService
  name: layout.stateTable
}


// --- Roles ------------------------------------------------------------------
// Blob Data Owner is what the Functions host needs for its own storage on Flex Consumption.
// Queue and Table Data Contributor cover the triggers and the state tables.

var roles = {
  storageBlobDataOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  storageQueueDataContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  storageTableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
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
output blobEndpoint string = account.properties.primaryEndpoints.blob
output queueEndpoint string = account.properties.primaryEndpoints.queue
output tableEndpoint string = account.properties.primaryEndpoints.table
