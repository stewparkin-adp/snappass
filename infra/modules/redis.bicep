/*
  Module: redis
  Creates Azure Cache for Redis.
  - SSL port 6380 enabled, non-SSL port 6379 disabled
  - Minimum TLS version 1.2
*/

targetScope = 'resourceGroup'

@description('Redis cache resource name.')
param redisName string

@description('Azure region.')
param location string

@description('SKU name: Basic or Standard.')
@allowed(['Basic', 'Standard'])
param skuName string = 'Standard'

@description('SKU capacity for C-family (0-6).')
@minValue(0)
@maxValue(6)
param skuCapacity int = 1

resource redis 'Microsoft.Cache/redis@2024-11-01' = {
  name: redisName
  location: location
  properties: {
    sku: {
      name: skuName
      family: 'C'
      capacity: skuCapacity
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisVersion: '6'
    publicNetworkAccess: 'Enabled'
  }
}

@description('Redis hostname (e.g. myredis.redis.cache.windows.net).')
output hostName string = redis.properties.hostName

@description('Redis primary access key.')
@secure()
output primaryKey string = redis.listKeys().primaryKey
