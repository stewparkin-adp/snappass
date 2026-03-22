/*
  Module: containerapp
  Creates:
    - Log Analytics Workspace
    - Container Apps Managed Environment
    - Container App running SnapPass

  Secrets (REDIS_URL, SECRET_KEY) are stored in Container Apps secrets
  and injected into the container via secretRef — never as plain-text env vars.
*/

targetScope = 'resourceGroup'

@description('Azure region.')
param location string

@description('Log Analytics workspace name.')
param logAnalyticsName string

@description('Container Apps managed environment name.')
param environmentName string

@description('Container App resource name.')
param containerAppName string

@description('Full image reference, e.g. pinterest/snappass:latest or myacr.azurecr.io/snappass:latest.')
param containerImage string

@description('ACR login server (e.g. myacr.azurecr.io).')
param acrLoginServer string

@description('Resource ID of the user-assigned managed identity.')
param identityId string

@description('Redis cache hostname.')
param redisHostName string

@description('Redis primary access key.')
@secure()
param redisAccessKey string

@description('Flask SECRET_KEY value.')
@secure()
param flaskSecretKey string

@description('Minimum number of replicas (0 allows scale-to-zero).')
param minReplicas int = 1

@description('Maximum number of replicas.')
param maxReplicas int = 3

@description('Custom domain to bind (e.g. secrets.assured-dp.com). Leave empty to skip.')
param customDomain string = ''

// Construct the rediss:// URL (double-s = SSL) for Azure Redis SSL port 6380
var redisUrl = 'rediss://:${redisAccessKey}@${redisHostName}:6380'

var hasCustomDomain = !empty(customDomain)
// Sanitised name for the managed cert resource (dots not allowed in resource names)
var certName = hasCustomDomain ? replace(customDomain, '.', '-') : 'none'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// Managed certificate — Azure provisions a free TLS cert once DNS is verified.
// Requires the CNAME and TXT records to exist in DNS before this resource deploys.
resource managedCert 'Microsoft.App/managedEnvironments/managedCertificates@2024-03-01' = if (hasCustomDomain) {
  parent: environment
  name: certName
  location: location
  properties: {
    subjectName: customDomain
    domainControlValidation: 'CNAME'
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 5000
        allowInsecure: false
        transport: 'auto'
        customDomains: hasCustomDomain ? [
          {
            name: customDomain
            bindingType: 'SniEnabled'
            certificateId: managedCert.id
          }
        ] : []
      }
      registries: [
        {
          server: acrLoginServer
          identity: identityId
        }
      ]
      secrets: [
        {
          name: 'redis-url'
          #disable-next-line use-secure-value-for-secure-inputs
          value: redisUrl
        }
        {
          name: 'flask-secret-key'
          value: flaskSecretKey
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'snappass'
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'REDIS_URL'
              secretRef: 'redis-url'
            }
            {
              name: 'SECRET_KEY'
              secretRef: 'flask-secret-key'
            }
            {
              // Container Apps handles TLS termination externally;
              // SnapPass itself runs plain HTTP internally
              name: 'NO_SSL'
              value: 'true'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/'
                port: 5000
                scheme: 'HTTP'
              }
              initialDelaySeconds: 15
              periodSeconds: 30
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/'
                port: 5000
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

@description('Fully qualified domain name of the Container App.')
output fqdn string = containerApp.properties.configuration.ingress.fqdn

@description('Log Analytics workspace resource ID.')
output logAnalyticsId string = logAnalytics.id

@description('Custom domain verification ID — used for the asuid DNS TXT record.')
output customDomainVerificationId string = environment.properties.customDomainVerificationId
