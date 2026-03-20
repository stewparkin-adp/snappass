/*
  SnapPass — Azure Container Apps Deployment
  Orchestrates: Managed Identity, ACR, Redis, Log Analytics,
                Container Apps Environment, Container App
*/

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Base name used to derive all resource names (3-12 lowercase alphanumeric).')
@minLength(3)
@maxLength(12)
param baseName string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Flask SECRET_KEY value. Must be a strong random string.')
@secure()
param flaskSecretKey string

@description('Container image to deploy. Defaults to an MCR placeholder; deploy.sh and the workflow update this to the ACR image after import.')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Azure Cache for Redis SKU.')
@allowed(['Basic', 'Standard'])
param redisSku string = 'Standard'

@description('Azure Cache for Redis capacity (C-family: 0-6).')
@minValue(0)
@maxValue(6)
param redisCapacity int = 1

@description('Minimum Container App replicas (0 = scale-to-zero).')
param minReplicas int = 1

@description('Maximum Container App replicas.')
@minValue(1)
@maxValue(10)
param maxReplicas int = 3

// ---------------------------------------------------------------------------
// Derived names
// ---------------------------------------------------------------------------

var acrName          = '${baseName}acr${uniqueString(resourceGroup().id)}'
var redisName        = '${baseName}-redis-${uniqueString(resourceGroup().id)}'
var identityName     = '${baseName}-id'
var logAnalyticsName = '${baseName}-logs'
var environmentName  = '${baseName}-env'
var containerAppName = '${baseName}-app'

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

module identity 'modules/identity.bicep' = {
  name: 'deploy-identity'
  params: {
    identityName: identityName
    location: location
  }
}

module acr 'modules/acr.bicep' = {
  name: 'deploy-acr'
  params: {
    acrName: acrName
    location: location
    principalId: identity.outputs.principalId
  }
}

module redis 'modules/redis.bicep' = {
  name: 'deploy-redis'
  params: {
    redisName: redisName
    location: location
    skuName: redisSku
    skuCapacity: redisCapacity
  }
}

module app 'modules/containerapp.bicep' = {
  name: 'deploy-containerapp'
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    environmentName: environmentName
    containerAppName: containerAppName
    containerImage: containerImage
    acrLoginServer: acr.outputs.loginServer
    identityId: identity.outputs.identityId
    redisHostName: redis.outputs.hostName
    redisAccessKey: redis.outputs.primaryKey
    flaskSecretKey: flaskSecretKey
    minReplicas: minReplicas
    maxReplicas: maxReplicas
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('URL of the deployed SnapPass application.')
output snappassUrl string = 'https://${app.outputs.fqdn}'

@description('Azure Container Registry login server.')
output acrLoginServer string = acr.outputs.loginServer

@description('Azure Container Registry name (used by deploy.sh for image import).')
output acrName string = acrName
