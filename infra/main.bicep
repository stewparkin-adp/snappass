/*
  PWPush — Azure Container Apps Deployment
  Orchestrates: Managed Identity, ACR, Log Analytics,
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

@description('Rails SECRET_KEY_BASE value. Must be a strong random string (128+ hex chars).')
@secure()
param secretKeyBase string

@description('PWPush master encryption key for stored secrets (64 hex chars).')
@secure()
param pwpushMasterKey string

@description('Container image to deploy. Defaults to an MCR placeholder; the workflow updates this to the ACR image after import.')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Custom domain (e.g. secrets.assured-dp.com). Used to set PWP__HOST_DOMAIN.')
param customDomain string = ''

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
    secretKeyBase: secretKeyBase
    pwpushMasterKey: pwpushMasterKey
    customDomain: customDomain
    minReplicas: minReplicas
    maxReplicas: maxReplicas
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('URL of the deployed PWPush application.')
output pwpushUrl string = 'https://${app.outputs.fqdn}'

@description('Azure Container Registry login server.')
output acrLoginServer string = acr.outputs.loginServer

@description('Azure Container Registry name (used by the workflow for image import).')
output acrName string = acrName
