// File principale Bicep per deploy completo su Azure
@description('Nome del progetto')
param projectName string = 'edoras'

@description('Environment (dev, staging, prod)')
param environment string = 'prod'

@description('Regione Azure')
param location string = resourceGroup().location

@description('SKU per App Service Plan')
param appServiceSku string = 'P1V2'

@description('Username amministratore SQL Server')
param sqlAdminUsername string = 'edorasadmin'

@description('Password amministratore SQL Server')
@secure()
param sqlAdminPassword string

@description('Nome del database')
param databaseName string = '${projectName}-${environment}-db'

@description('SKU del database SQL')
param databaseSku object = {
  name: 'S1'
  tier: 'Standard'
}

// Variables
var uniqueSuffix = uniqueString(resourceGroup().id)
var appName = '${projectName}-${environment}-${uniqueSuffix}'
var sqlServerName = '${appName}-sqlserver'
var keyVaultName = '${appName}-kv'
var storageAccountName = replace('${appName}storage', '-', '')

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${appName}-plan'
  location: location
  sku: {
    name: appServiceSku
  }
  properties: {
    reserved: true
  }
  tags: {
    Environment: environment
    Project: projectName
  }
}

// Azure SQL Server
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    Environment: environment
    Project: projectName
  }
}

// SQL Server Firewall Rule - Allow Azure Services
resource sqlFirewallAzure 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// SQL Server Firewall Rule - Allow development IPs (optional)
resource sqlFirewallDev 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AllowDevelopmentAccess'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

// Azure SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  sku: databaseSku
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2GB
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
  }
  tags: {
    Environment: environment
    Project: projectName
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
  tags: {
    Environment: environment
    Project: projectName
  }
}

// Storage Container for uploads
resource storageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${storageAccount.name}/default/uploads'
  properties: {
    publicAccess: 'Blob'
  }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enabledForTemplateDeployment: true
    enableRbacAuthorization: false
    accessPolicies: []
  }
  tags: {
    Environment: environment
    Project: projectName
  }
}

// Backend App Service (Flask Python)
resource backendApp 'Microsoft.Web/sites@2022-03-01' = {
  name: '${appName}-backend'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      appSettings: [
        {
          name: 'FLASK_ENV'
          value: environment
        }
        {
          name: 'FLASK_APP'
          value: 'app.py'
        }
        {
          name: 'DATABASE_URL'
          value: 'mssql+pyodbc://${sqlAdminUsername}:${sqlAdminPassword}@${sqlServer.properties.fullyQualifiedDomainName}/${databaseName}?driver=ODBC+Driver+17+for+SQL+Server'
        }
        {
          name: 'AZURE_STORAGE_CONNECTION_STRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'JWT_SECRET_KEY'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=jwt-secret)'
        }
        {
          name: 'SECRET_KEY'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=flask-secret)'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'POST_BUILD_SCRIPT_PATH'
          value: 'deploy/post_build.sh'
        }
      ]
      pythonVersion: '3.11'
      alwaysOn: true
      ftpsState: 'Disabled'
      httpLoggingEnabled: true
      logsDirectorySizeLimit: 40
    }
    httpsOnly: true
  }
  tags: {
    Environment: environment
    Project: projectName
  }
}

// Frontend App Service (Static Web App or Node.js)
resource frontendApp 'Microsoft.Web/sites@2022-03-01' = {
  name: '${appName}-frontend'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      appSettings: [
        {
          name: 'NODE_ENV'
          value: environment
        }
        {
          name: 'REACT_APP_API_URL'
          value: 'https://${backendApp.properties.defaultHostName}/api/v1'
        }
        {
          name: 'REACT_APP_ENVIRONMENT'
          value: environment
        }
      ]
      alwaysOn: true
      ftpsState: 'Disabled'
    }
    httpsOnly: true
  }
  tags: {
    Environment: environment
    Project: projectName
  }
}

// Key Vault Access Policy for Backend App
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: backendApp.identity.principalId
        permissions: {
          secrets: ['get', 'list']
        }
      }
    ]
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${appName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 90
  }
  tags: {
    Environment: environment
    Project: projectName
  }
}

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${appName}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
  tags: {
    Environment: environment
    Project: projectName
  }
}

// Outputs
output backendUrl string = 'https://${backendApp.properties.defaultHostName}'
output frontendUrl string = 'https://${frontendApp.properties.defaultHostName}'
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output databaseName string = databaseName
// Connection string senza password nell'output per sicurezza
// output databaseConnectionString string = 'mssql+pyodbc://${sqlAdminUsername}:${sqlAdminPassword}@${sqlServer.properties.fullyQualifiedDomainName}/${databaseName}?driver=ODBC+Driver+17+for+SQL+Server'
output storageAccountName string = storageAccount.name
// Storage connection string senza chiavi nell'output per sicurezza  
// output storageConnectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
output keyVaultName string = keyVault.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output resourceGroupName string = resourceGroup().name
