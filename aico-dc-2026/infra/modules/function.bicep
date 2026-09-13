// Flex Consumption Function App on Linux with a user-assigned managed identity.
// Host storage and deployment storage both use the identity, so no connection strings exist.
param planName string
param appName string
param location string
param tags object
param identityId string
param identityClientId string
param runtime string
param runtimeVersion string
param storageAccountName string
param deploymentsContainer string
param appInsightsConnectionString string

@description('Extra app settings merged with the ones the host needs.')
param appSettings object = {}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'functionapp'
  sku: { tier: 'FlexConsumption', name: 'FC1' }
  properties: { reserved: true }
}

var hostSettings = {
  AzureWebJobsStorage__accountName: storage.name
  AzureWebJobsStorage__credential: 'managedidentity'
  AzureWebJobsStorage__clientId: identityClientId
  APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
}

resource app 'Microsoft.Web/sites@2024-04-01' = {
  name: appName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${identityId}': {} }
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}${deploymentsContainer}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: identityId
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 40
        instanceMemoryMB: 2048
      }
      runtime: { name: runtime, version: runtimeVersion }
    }
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        for setting in items(union(hostSettings, appSettings)): {
          name: setting.key
          value: setting.value
        }
      ]
    }
  }
}

output name string = app.name
output id string = app.id
output hostName string = app.properties.defaultHostName
