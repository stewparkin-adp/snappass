/*
  Module: identity
  Creates a User-Assigned Managed Identity for ACR pull access.
*/

targetScope = 'resourceGroup'

@description('Name of the managed identity resource.')
param identityName string

@description('Azure region.')
param location string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

@description('Resource ID of the managed identity (used in Container App configuration).')
output identityId string = identity.id

@description('Principal ID used for role assignment on ACR.')
output principalId string = identity.properties.principalId

@description('Client ID used in Container App registries configuration.')
output clientId string = identity.properties.clientId
