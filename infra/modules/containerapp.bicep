/*
  Module: containerapp
  Creates:
    - Log Analytics Workspace
    - Container Apps Managed Environment
    - Container App running PWPush

  Secrets (SECRET_KEY_BASE, PWPUSH_MASTER_KEY) are stored in Container Apps secrets
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

@description('Full image reference, e.g. pglombardo/pwpush:stable or myacr.azurecr.io/pwpush:stable.')
param containerImage string

@description('ACR login server (e.g. myacr.azurecr.io).')
param acrLoginServer string

@description('Resource ID of the user-assigned managed identity.')
param identityId string

@description('Rails SECRET_KEY_BASE value.')
@secure()
param secretKeyBase string

@description('PWPush master encryption key for stored secrets.')
@secure()
param pwpushMasterKey string

@description('Custom domain (e.g. secrets.assured-dp.com). Sets PWP__HOST_DOMAIN.')
param customDomain string = ''

@description('Minimum number of replicas (0 allows scale-to-zero).')
param minReplicas int = 1

@description('Maximum number of replicas.')
param maxReplicas int = 3

// PWPush runs on port 5100 in HTTP mode (Container Apps handles TLS termination)
var pwpushPort = 5100

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
        targetPort: pwpushPort
        allowInsecure: false
        transport: 'auto'
      }
      registries: [
        {
          server: acrLoginServer
          identity: identityId
        }
      ]
      secrets: [
        {
          name: 'secret-key-base'
          value: secretKeyBase
        }
        {
          name: 'pwpush-master-key'
          value: pwpushMasterKey
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'pwpush'
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'SECRET_KEY_BASE'
              secretRef: 'secret-key-base'
            }
            {
              name: 'PWPUSH_MASTER_KEY'
              secretRef: 'pwpush-master-key'
            }
            {
              name: 'RAILS_ENV'
              value: 'production'
            }
            {
              // Container Apps handles TLS termination; tell PWPush links should use https
              name: 'PWP__HOST_PROTOCOL'
              value: 'https'
            }
            {
              // Set the public hostname for generated links (custom domain if set, otherwise blank)
              name: 'PWP__HOST_DOMAIN'
              value: customDomain
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/'
                port: 80
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
              periodSeconds: 30
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/'
                port: 80
                scheme: 'HTTP'
              }
              initialDelaySeconds: 20
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
