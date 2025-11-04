// Bicep template for deploying a static website, Azure Function, and storage with OCR integration

// Parameters for customization
param location string = 'westeurope'
param id string =take(uniqueString(resourceGroup().id), 6)
param storageAccountName string = 'ocrstrgacct${id}'
param ocrFunctionAppName string = 'ocrfunc${id}'
param storageFunctionAppName string = 'ocrstrgfunc${id}'
param computerVisionName string = 'ocrvision${id}'
param applicationInsightsName string = 'ocrinsights${id}'

param ocrAzureFunctionCodePackage string = ''
param ocrStorageAzureFunctionCodePackage string = ''
param uiHtmlUrl string = '' 


// Resource for Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    DisableIpMasking: false
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Resource for Storage Account
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  // This is the Storage Account Contributor role, which is the minimum role permission we can give. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#:~:text=17d1049b-9a84-46fb-8f53-869881c3d3ab
  name: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}


//Blob Service for the Storage Account
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: [
        {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST']
          allowedHeaders: ['*']
          exposedHeaders: ['*']
          maxAgeInSeconds: 3600
        }
      ]
    }
  }
}

// Container for uploaded images
resource uploadedImagesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  parent: blobService
  name: 'ocr'
  properties: {
    publicAccess: 'None'
  }
}


// Cognitive Services for OCR - Computer Vision
resource computerVision 'Microsoft.CognitiveServices/accounts@2022-12-01' = {
  name: computerVisionName
  location: location
  sku: {
    name: 'S1'
  }
  kind: 'ComputerVision'
  properties: {
    customSubDomainName: computerVisionName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
  dependsOn: [
    storageAccount
    applicationInsights
  ]
}

// OCR Azure Function App Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${ocrFunctionAppName}-plan'
  location: location
  sku: {
    tier: 'Dynamic'
    name: 'Y1'
  }
  properties: {
    reserved: true 

  }
}


// remove trailing slash at the end of the url
var staticWebsiteUrl = substring(storageAccount.properties.primaryEndpoints.web, 0, length(storageAccount.properties.primaryEndpoints.web) - 1)


// OCR Azure Function App deployment
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: ocrFunctionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'Python|3.9'
      cors: {
        allowedOrigins: [
          staticWebsiteUrl
        ]
      }
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'COMPUTER_VISION_ENDPOINT'
          value: computerVision.properties.endpoint
        }
        {
          name: 'COMPUTER_VISION_SUBSCRIPTION_KEY'
          value: computerVision.listKeys().key1
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: ocrAzureFunctionCodePackage
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
      ]
    }
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Storage Azure Function App Plan
resource storageFunctionAppServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${storageFunctionAppName}-plan'
  location: location
  sku: {
    tier: 'Dynamic'
    name: 'Y1'
  }
  properties: {
    reserved: true 

  }
}

// Storage Azure Function App deployment
resource storagefunctionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: storageFunctionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'Python|3.9'
      cors: {
        allowedOrigins: [
          staticWebsiteUrl
        ]
      }
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'OCR_STORAGE_ACCOUNT_CONTAINER_NAME'
          value: uploadedImagesContainer.name
        }
        {
          name: 'OCR_STORAGE_ACCOUNT_KEY'
          value: storageAccount.listKeys().keys[0].value
        }
        {
          name: 'OCR_STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: ocrStorageAzureFunctionCodePackage
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
      ]
    }
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}



// Role assignment to allow Function to access Storage Account
resource functionAppBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, 'StorageBlobDataContributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}


// Static website deployment
var key = listkeys('${functionApp.id}/host/default', '2022-03-01').masterKey
var key2 = listkeys('${storagefunctionApp.id}/host/default', '2022-03-01').masterKey

var ocrFunctionAppUrl = 'https://${functionApp.properties.defaultHostName}/api/ocr?code=${key}'
var storageFunctionAppUrl = 'https://${storagefunctionApp.properties.defaultHostName}/api/uploadimage?code=${key2}'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'DeploymentScript'
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: storageAccount
  name: guid(resourceGroup().id, managedIdentity.id, contributorRoleDefinition.id)
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deploymentScript'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  dependsOn: [
    roleAssignment
  ]
  properties: {
    azPowerShellVersion: '3.0'
    scriptContent: loadTextContent('./enable-static-website-new.ps1')
    retentionInterval: 'PT4H'
    environmentVariables: [
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'StorageAccountName'
        value: storageAccount.name
      }
      {
        name: 'storageFunctionAppUrl'
        value: storageFunctionAppUrl
      }
      {
        name: 'ocrFunctionAppUrl'
        value: ocrFunctionAppUrl
      }
      {
        name: 'uiHtmlUrl'
        value: uiHtmlUrl
      }
    ]
  }
}

// Outputs for easy access to deployed resources
output staticWebsiteUrl string = storageAccount.properties.primaryEndpoints.web
output storageAccountName string = storageAccount.name
output ocrFunctionAppName string = functionApp.name
output storageFunctionAppName string = storagefunctionApp.name
output ocrFunctionUrl string = ocrFunctionAppUrl
output storageFunctionUrl string = storageFunctionAppUrl
output computerVisionEndpoint string = computerVision.properties.endpoint
output resourceGroupName string = resourceGroup().name