metadata name = 'ALZ IaaS Online Landing Zone '
metadata description = 'ALZ Bicep Module used to set up IaaS Online Application Landing Zone'

targetScope = 'resourceGroup'

extension microsoftGraphV1

import { funcGetResourceInformation } from 'functions/funcs-udts.bicep'

@sys.description('The Azure Region to deploy the resources into.')
param parLocation string = resourceGroup().location

@sys.description('Deployment environment.')
param parEnvironment string = 'canary'

@sys.description('Requires. The virtual network resource ID to deploy resources into.')
param parVnetResourceId string 

@sys.description('Requires. The public DNS zone name for access to application.')
param parPublicDnsZoneName string

@description('The name of the function app that you wish to create.')
@maxLength(9)
param parAppNamePrefix string

@description('Enable authentication with managed identity as a federated credential.')
param parEnableMiAsFic bool = true

@description('If you choose true, create and configure a key vault at the same time.')
@allowed([
  true
  false
])
param parCreateKeyVault bool = true

@description('Specifies whether the key vault is a standard vault or a premium vault.')
@allowed([
  'standard'
  'premium'
])
param parKeyVaultSkuName string = 'standard'

@description('Resource Id of an existing Key Vault to store the certificates. ')
param parKeyVaultResourceId string = ''

@description('Email address for ACME account.')
param parEmailAddress string = 'noreply@noreply.org'

@description('Certification authority ACME Endpoint.')
@allowed([
  'https://acme-v02.api.letsencrypt.org/directory'
  'https://acme-staging-v02.api.letsencrypt.org/directory'
  'https://api.buypass.com/acme/directory'
  'https://acme.zerossl.com/v2/DV90/'
  'https://dv.acme-v02.api.pki.goog/directory'
  'https://acme.entrust.net/acme2/directory'
  'https://emea.acme.atlas.globalsign.com/directory'
])
param parAcmeEndpoint string = 'https://acme-v02.api.letsencrypt.org/directory'

@description('Specifies additional name/value pairs to be appended to the functionap app appsettings.')
param parAdditionalAppSettings array = [
  {
    name: 'Acmebot:AzureDns:SubscriptionId'
    value: last(split(subscription().id, '/'))
  }
]

// Object containing a mapping for location / region code
var varLocationCodes = {
  germanywestcentral: 'gwc'
  westeurope: 'weu'
}

var varLocationCode = varLocationCodes[parLocation]

var _dep = deployment().name

var varStorageAccountName = 'sa${varLocationCode}${parAppNamePrefix}${substring(uniqueString(resourceGroup().id), 0, 4)}func'
var varAppServicePlanName = 'asp-${varLocationCode}-${parAppNamePrefix}-${substring(uniqueString(resourceGroup().id), 0, 4)}-${parEnvironment}'
var varAppInsightsName = 'appi-${varLocationCode}-${parAppNamePrefix}-${substring(uniqueString(resourceGroup().id), 0, 4)}-${parEnvironment}'
var varFunctionAppName = 'func-${varLocationCode}-${parAppNamePrefix}-${substring(uniqueString(resourceGroup().id), 0, 4)}-${parEnvironment}'
var varKeyVaultName = 'kv-${varLocationCode}-${parAppNamePrefix}-${substring(uniqueString(resourceGroup().id), 0, 4)}'
var varLogAnalyticsWorkspaceName = 'log-${varLocationCode}-${parAppNamePrefix}-${substring(uniqueString(resourceGroup().id), 0, 4)}-${parEnvironment}'
var varIdKeyVaultAcmeBotName = 'id-${varLocationCode}-${parAppNamePrefix}-${substring(uniqueString(resourceGroup().id), 0, 4)}-${parEnvironment}'

var varExistingKeyVault = !parCreateKeyVault ? funcGetResourceInformation(parKeyVaultResourceId) : ''

var varIssuer = '${environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'

var varAcmebotAppSettings = [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: modAppInsights.outputs.connectionString
  }
  {
    name: 'AzureWebJobsStorage'
    //value: 'DefaultEndpointsProtocol=https;AccountName=${modStorageAccount.outputs.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
    value: 'DefaultEndpointsProtocol=https;AccountName=${modStorageAccount.outputs.name};AccountKey=${modStorageAccount.outputs.primaryAccessKey};EndpointSuffix=${environment().suffixes.storage}'

  }
  {
    name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
    //value: 'DefaultEndpointsProtocol=https;AccountName=${modStorageAccount.outputs.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
    value: 'DefaultEndpointsProtocol=https;AccountName=${modStorageAccount.outputs.name};AccountKey=${modStorageAccount.outputs.primaryAccessKey};EndpointSuffix=${environment().suffixes.storage}'

  }
  {
    name: 'WEBSITE_CONTENTSHARE'
    value: toLower(varFunctionAppName)
  }
  {
    name: 'WEBSITE_RUN_FROM_PACKAGE'
    value: 'https://stacmebotprod.blob.core.windows.net/keyvault-acmebot/v4/latest.zip'
  }
  {
    name: 'FUNCTIONS_EXTENSION_VERSION'
    value: '~4'
  }
  {
    name: 'FUNCTIONS_INPROC_NET8_ENABLED'
    value: '1'
  }
  {
    name: 'FUNCTIONS_WORKER_RUNTIME'
    value: 'dotnet'
  }
  {
    name: 'Acmebot:Contacts'
    value: parEmailAddress
  }
  {
    name: 'Acmebot:Endpoint'
    value: parAcmeEndpoint
  }
  {
    name: 'Acmebot:VaultBaseUrl'
    value: parCreateKeyVault ? modKeyVault.outputs.uri : resKeyVault.properties.vaultUri
  }
  {
    name: 'Acmebot:Environment'
    value: environment().name
  }
]

var acmebotAuthSettings = (parEnableMiAsFic)
  ? [
      {
        name: 'OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID'
        value: modIdKeyVaultAcmeBot.outputs.clientId
      }
    ]
  : []

// Modules and Resources

// function app
module modKeyVaultAcmeBot 'br/public:avm/res/web/site:0.19.0' = {
  name: '${_dep}-func-keyvault-acmebot'
  scope: resourceGroup()
  params: {
    location: parLocation
    kind: 'functionapp'
    name: varFunctionAppName
    managedIdentities: {
      systemAssigned: true
      userAssignedResourceIds: [
        modIdKeyVaultAcmeBot.outputs.resourceId
      ]
    }
    configs: [
      {
        name: 'authsettingsV2'
        properties: {
          globalValidation: {
            requireAuthentication: true
            unauthenticatedClientAction: 'RedirectToLoginPage'
            redirectToProvider: 'azureactivedirectory'
          }
          identityProviders: {
            azureActiveDirectory: {
              enabled: true
              registration: {
                clientId: resAppRegistrationKeyVaultAcmeBot.appId
                clientSecretSettingName: 'OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID'
                openIdIssuer: varIssuer
              }
              validation: {
                defaultAuthorizationPolicy: {
                  allowedApplications: []
                }
              }
            }
          }
          login: {
            tokenStore: {
              enabled: true
            }
          }
          platform: {
            enabled: true
          }
        }
      }
    ]
    clientAffinityEnabled: true
    httpsOnly: true
    serverFarmResourceId: modAppServicePlan.outputs.resourceId
    siteConfig: {
      appSettings: concat(varAcmebotAppSettings, parAdditionalAppSettings, acmebotAuthSettings)
      netFrameworkVersion: 'v8.0'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
        supportCredentials: false
      }
    }
  }
}


// Application authentication with User assigned managed identity and federated identity credential

// Get the MS Graph Service Principal based on its application ID:
var varMsGraphAppId = '00000003-0000-0000-c000-000000000000'
resource resMsGraphSP 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: varMsGraphAppId
}
var varGraphScopes = resMsGraphSP.oauth2PermissionScopes

var varClientAppScopes = ['User.Read']

// Entra ID App registration
resource resAppRegistrationKeyVaultAcmeBot 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: 'keyvault-acmebot'
  displayName: 'KeyVault AcmeBot'
  signInAudience: 'AzureADMyOrg'
  web: {
    redirectUris: [
      'https://${varFunctionAppName}.azurewebsites.net/.auth/login/aad/callback'
    ]
    implicitGrantSettings: {
      enableIdTokenIssuance: true
    }
  }
  requiredResourceAccess: [
    {
      resourceAppId: varMsGraphAppId
      resourceAccess: [
        for (scope, i) in varClientAppScopes: {
          id: filter(varGraphScopes, graphScopes => graphScopes.value == scope)[0].id
          type: 'Scope'
        }
      ]
    }
  ]
  resource resClientAppFic 'federatedIdentityCredentials@v1.0' = {
    name: '${resAppRegistrationKeyVaultAcmeBot.uniqueName}/miAsFic'
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: varIssuer
    subject: modIdKeyVaultAcmeBot.outputs.principalId
  }
}

resource ServicePrincipalKeyVaultAcmeBot 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: resAppRegistrationKeyVaultAcmeBot.appId
}

module modListKeysHelperFunctionApp'./modules/list-keys-helper.bicep' = {
  name: '${_dep}-list-keys-helper-functionapp'
  params: {
    resourceId: modKeyVaultAcmeBot.outputs.resourceId
    apiVersion: '2024-11-01'
  }
}

module modStorageAccount 'br/public:avm/res/storage/storage-account:0.25.1' = {
  name: '${_dep}-storageaccount'
  scope: resourceGroup()
  params: {
    name: varStorageAccountName
    location: parLocation
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
  }
}

module modAppServicePlan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  name: '${_dep}-appserviceplan'
  scope: resourceGroup()
  params: {
    name: varAppServicePlanName
    location: parLocation
    skuName: 'Y1'
  }
}

module modIdKeyVaultAcmeBot 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (parEnableMiAsFic) {
  name: '${_dep}-id-keyvault-acmebot'
  scope: resourceGroup()
  params: {
    name: varIdKeyVaultAcmeBotName
    location: parLocation
  }
}

module modAppInsights 'br/public:avm/res/insights/component:0.6.0' = {
  name: '${_dep}-appinsights'
  scope: resourceGroup()
  params: {
    name: varAppInsightsName
    location: parLocation
    workspaceResourceId: modLogWorkSpace.outputs.resourceId
    kind: 'web'
    applicationType: 'web'
    tags: {
      'hidden-link:${resourceGroup().id}/providers/Microsoft.Web/sites/${varFunctionAppName}': 'Resource'
    }
  }
}


resource resVnet1 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  scope: resourceGroup(split(parVnetResourceId, '/')[4])
  name: last(split(parVnetResourceId, '/'))
}

module modLogWorkSpace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
  name: '${_dep}-logworkspace'
  scope: resourceGroup()
  params: {
    name: varLogAnalyticsWorkspaceName
    location: parLocation
  }
}

resource resKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (!parCreateKeyVault) {
  //name: last(split(parKeyVaultResourceId, '/'))
  name: varExistingKeyVault.resourceName
  //scope: resourceGroup(split(parKeyVaultResourceId, '/')[2],split(parKeyVaultResourceId, '/')[4])
  scope: resourceGroup(varExistingKeyVault.subscriptionId,varExistingKeyVault.resourceGroupName)
}

module modKeyVault 'br/public:avm/res/key-vault/vault:0.13.0' = if (parCreateKeyVault) {
  scope: resourceGroup()
  name: '${_dep}-keyvault'  
  params: {
    name: varKeyVaultName
    location: parLocation
    enablePurgeProtection: true
    sku: parKeyVaultSkuName
    enableRbacAuthorization: true
  }
}

module modPublicDnsZone 'br/public:avm/res/network/dns-zone:0.5.3' = {
  scope: resourceGroup()
  name: '${_dep}-dnszone'
  params: {
    name: parPublicDnsZoneName
  }
}

module modRbacNewKeyVaultAcmeBot '../../../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = if (parCreateKeyVault) {
  name: '${_dep}-rbac-keyvault-acmebot'
  scope: resourceGroup()
  params: {
    principalId: modKeyVaultAcmeBot.outputs.systemAssignedMIPrincipalId!
    roleDefinitionId: 'a4417e6f-fecd-4de8-b567-7b0420556985' // Key Vault Certificates Officer
    resourceId: modKeyVault.outputs.resourceId
  }
}

module modRbacExistingKeyVaultAcmeBot '../../../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = if (!parCreateKeyVault) {
  name: '${_dep}-rbac-keyvault-acmebot'
  scope: resourceGroup(varExistingKeyVault.subscriptionId,varExistingKeyVault.resourceGroupName)
  params: {
    principalId: modKeyVaultAcmeBot.outputs.systemAssignedMIPrincipalId!
    roleDefinitionId: 'a4417e6f-fecd-4de8-b567-7b0420556985' // Key Vault Certificates Officer
    resourceId: resKeyVault.id
  }
}

module modRbacDnsZoneKeyVaultAcme '../../../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  name: '${_dep}-rbac-dnszone-keyvault-acmebot'
  scope: resourceGroup()
  params: {
    principalId: modKeyVaultAcmeBot.outputs.systemAssignedMIPrincipalId!
    roleDefinitionId: 'befefa01-2a29-4197-83a8-272ff33ce314' // DNS Zone Contributor
    resourceId: modPublicDnsZone.outputs.resourceId
  }
}

output acmeBotAppName string = modKeyVaultAcmeBot.outputs.name

@secure()
output outFunctionAppKey string = modListKeysHelperFunctionApp.outputs.key



