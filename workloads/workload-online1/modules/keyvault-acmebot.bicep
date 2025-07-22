extension microsoftGraphV1

@description('The name of the function app that you wish to create.')
@maxLength(14)
param appNamePrefix string

@description('The location of the function app that you wish to create.')
param location string = resourceGroup().location

@description('Email address for ACME account.')
param mailAddress string

@description('Certification authority ACME Endpoint.')
@allowed([
  'https://acme-v02.api.letsencrypt.org/directory'
  'https://api.buypass.com/acme/directory'
  'https://acme.zerossl.com/v2/DV90/'
  'https://dv.acme-v02.api.pki.goog/directory'
  'https://acme.entrust.net/acme2/directory'
  'https://emea.acme.atlas.globalsign.com/directory'
])
param acmeEndpoint string = 'https://acme-v02.api.letsencrypt.org/directory'

@description('If you choose true, create and configure a key vault at the same time.')
@allowed([
  true
  false
])
param createWithKeyVault bool = true

@description('Specifies whether the key vault is a standard vault or a premium vault.')
@allowed([
  'standard'
  'premium'
])
param keyVaultSkuName string = 'standard'

@description('Enter the base URL of an existing Key Vault. (ex. https://example.vault.azure.net)')
param keyVaultBaseUrl string = ''

@description('Specifies additional name/value pairs to be appended to the functionap app appsettings.')
param additionalAppSettings array = []

@description('Enable authentication with managed identity as a federated credential.')
param parEnableMiAsFic bool

@description('Required. Log Analytics workspace resource id for application logging destination.')
param parLogWorkspaceResourceId string

var _dep = deployment().name

var issuer = '${environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'

var functionAppName = 'func-${appNamePrefix}-${substring(uniqueString(resourceGroup().id), 0, 4)}'

var appServicePlanName = 'plan-${appNamePrefix}-${substring(uniqueString(resourceGroup().id, deployment().name), 0, 4)}'
var appInsightsName = 'appi-${appNamePrefix}-${substring(uniqueString(resourceGroup().id, deployment().name), 0, 4)}'
var storageAccountName = 'st${uniqueString(resourceGroup().id, deployment().name)}func'
var keyVaultName = 'kv-${appNamePrefix}-${substring(uniqueString(resourceGroup().id, deployment().name), 0, 4)}'
var roleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions/', 'a4417e6f-fecd-4de8-b567-7b0420556985')
var acmebotAppSettings = [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsights.properties.ConnectionString
  }
  {
    name: 'AzureWebJobsStorage'
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }
  {
    name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }
  {
    name: 'WEBSITE_CONTENTSHARE'
    value: toLower(functionAppName)
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
    value: mailAddress
  }
  {
    name: 'Acmebot:Endpoint'
    value: acmeEndpoint
  }
  {
    name: 'Acmebot:VaultBaseUrl'
    value: (createWithKeyVault ? 'https://${keyVaultName}${environment().suffixes.keyvaultDns}' : keyVaultBaseUrl)
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

module modIdKeyVaultAcmeBot 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = if (parEnableMiAsFic) {
  name: '${_dep}-id-keyvault-acmebot'
  scope: resourceGroup()
  params: {
    //name: 'id-gwc-acmebot-001-${parEnvironment}'
    name: 'uai-gwc-acmebot'
    location: location
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}


resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: {
    'hidden-link:${resourceGroup().id}/providers/Microsoft.Web/sites/${functionAppName}': 'Resource'
  }
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: parLogWorkspaceResourceId
  }
}



module modFunctionApp 'br/public:avm/res/web/site:0.16.0' = {
  name: '${_dep}-func-keyvault-acmebot'
  scope: resourceGroup()
  params: {
    location: location
    kind: 'functionapp'
    name: functionAppName
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
            requireAuthentication: false
            unauthenticatedClientAction: 'RedirectToLoginPage'
            redirectToProvider: 'azureactivedirectory'
          }
          identityProviders: {
            azureActiveDirectory: {
              enabled: true
              registration: {
                clientId: appRegistrationKeyVaultAcmeBot.appId
                clientSecretSettingName: 'OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID'
                openIdIssuer: issuer
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
        }
      }
    ]
    clientAffinityEnabled: true
    httpsOnly: true
    serverFarmResourceId: appServicePlan.id
    siteConfig: {
      appSettings: concat(acmebotAppSettings, additionalAppSettings, acmebotAuthSettings)
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
var msGraphAppId = '00000003-0000-0000-c000-000000000000'
resource msGraphSP 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: msGraphAppId
}

var graphScopes = msGraphSP.oauth2PermissionScopes

var clientAppScopes = ['User.Read']

resource appRegistrationKeyVaultAcmeBot 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: 'keyvault-acmebot'
  displayName: 'KeyVault AcmeBot'
  signInAudience: 'AzureADMyOrg'
  web: {
    redirectUris: [
      'https://${functionAppName}.azurewebsites.net/.auth/login/aad/callback'
    ]
    implicitGrantSettings: {
      enableIdTokenIssuance: true
    }
  }
  requiredResourceAccess: [
    {
      resourceAppId: msGraphAppId
      resourceAccess: [
        for (scope, i) in clientAppScopes: {
          id: filter(graphScopes, graphScopes => graphScopes.value == scope)[0].id
          type: 'Scope'
        }
      ]
    }
  ]
  resource clientAppFic 'federatedIdentityCredentials@v1.0' = {
    name: '${appRegistrationKeyVaultAcmeBot.uniqueName}/miAsFic'
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: issuer
    subject: modIdKeyVaultAcmeBot.outputs.principalId
  }
}

resource ServicePrincipalKeyVaultAcmeBot 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: appRegistrationKeyVaultAcmeBot.appId
}


resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = if (createWithKeyVault) {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: keyVaultSkuName
    }
    enableRbacAuthorization: true
  }
}

resource keyVault_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createWithKeyVault) {
  scope: keyVault
  name: guid(keyVault.id, functionAppName, roleDefinitionId)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: modFunctionApp.outputs.systemAssignedMIPrincipalId!
    principalType: 'ServicePrincipal'
  }
}

module listKeysHelperFunctionApp'./list-keys-helper.bicep' = {
  name: '${_dep}-list-keys-helper-functionapp'
  params: {
    //resourceId: '${resFuncKeyVaultAcmeBot.id}/host/default'
    resourceId: modFunctionApp.outputs.resourceId
    apiVersion: '2024-11-01'
  }
  // dependsOn: [
  //   modFunctionApp
  // ]
}

// resource resFuncKeyVaultAcmeBot 'Microsoft.Web/sites@2024-11-01' existing = {
//   dependsOn: [
//     modFunctionApp
//   ]
//   scope: resourceGroup()
//   name: functionAppName
// }


output functionAppName string = functionAppName
output principalId string = modFunctionApp.outputs.systemAssignedMIPrincipalId! 
output keyVaultName string = createWithKeyVault ? keyVault.name : ''
output functionAppId string = modFunctionApp.outputs.resourceId

@secure()
//output outFunctionAppKey string = listKeys('${resFuncKeyVaultAcmeBot.id}/host/default','2024-11-01').functionKeys.default
output outFunctionAppKey string = listKeysHelperFunctionApp.outputs.key


