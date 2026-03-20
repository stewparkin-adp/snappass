/*
  Module: acr
  Creates Azure Container Registry (Basic SKU) and grants
  the provided principal the AcrPull built-in role.
*/

targetScope = 'resourceGroup'

@description('Globally unique ACR name (alphanumeric, 5-50 chars).')
param acrName string

@description('Azure region.')
param location string

@description('Principal ID of the managed identity that needs AcrPull.')
param principalId string

// Built-in role definition ID for AcrPull
var acrPullRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, principalId, acrPullRoleDefinitionId)
  scope: acr
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

@description('ACR login server hostname (e.g. myacr.azurecr.io).')
output loginServer string = acr.properties.loginServer

@description('ACR resource ID.')
output acrId string = acr.id
