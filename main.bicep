param location string = resourceGroup().location

@description('The Azure subscription environment being deployed to. Includes `DEV`; `SBOX`; `TEST` `PROD`.')
param environment string

@description('The abbreviated name of the application or project being deployed.')
param appName string

@description('If using an exsiting App Service PLan (Server Farm) enter the name here.')
param appHostingPlanName string = ''

//@description('An ID for the deployment. This is used as the parent ID for any child deployment slots.')
//param deploymentId string = '000000'

@description('The name of the additional deployment slot being used.')
param functionStagingSlot string = 'staging'

@description('The name to assign to the Azure Functions Storage Account.')
param storageAccountName string


// vars
var formattedResourceNameSuffix = toLower('-${appName}-${environment}')
var InstrumentationKey = azAppInsightsComponents.properties.InstrumentationKey


// Function App Storage Account
resource azFuncStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

// App insights
resource azAppInsightsComponents 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi${formattedResourceNameSuffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

// app service hosting plan

// use existing App Hosting Plan if specified
resource existingAzAppHostingPlan 'Microsoft.Web/serverfarms@2022-09-01' existing = if (appHostingPlanName != '') {
  name: appHostingPlanName
}

// Create new App Hosting Plan if existing ASP not specified.
resource newAzAppHostingPlan 'Microsoft.Web/serverfarms@2022-09-01' = if (appHostingPlanName == '') {
  name: 'asp-${formattedResourceNameSuffix}'
  location: location
  kind: 'windows'
  sku: {
    name: 'S1' 
  }
  properties: {
    reserved: true 
  }
}

var appHostingPlanId = ((appHostingPlanName == '') ? newAzAppHostingPlan.id : existingAzAppHostingPlan.id )

// az function app
resource azFunctionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: 'func${formattedResourceNameSuffix}'
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned' 
  }
  properties: {
    serverFarmId: appHostingPlanId
    httpsOnly: true
    clientAffinityEnabled: true
    reserved: true
    siteConfig: {
      minTlsVersion: '1.2' 
      alwaysOn: true
    }   
  }
}

// Create staging deployment slot
resource azFunctionstagingSlot 'Microsoft.Web/sites/slots@2022-09-01' = {
  name: functionStagingSlot
  parent: azFunctionApp
  location:  location
  identity: {
    type: 'SystemAssigned' 
  }
  properties: {
    httpsOnly: true
    enabled: true
  } 
}

// OUTPUTS
output appInsightsInstrumentationKey string = InstrumentationKey
output functionAppName string = azFunctionApp.name
output functionAppSlot string = functionStagingSlot
