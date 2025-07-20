metadata name = 'ALZ IaaS Online Landing Zone'
metadata description = 'ALZ Bicep Module used to set up IaaS Online Application Landing Zone'

targetScope = 'resourceGroup'

extension microsoftGraphV1


@sys.description('The Azure Region to deploy the resources into.')
param parLocation string = resourceGroup().location

@sys.description('Deployment environment.')
param parEnvironment string = 'canary'

@sys.description('Requires. The virtual network resource ID to deploy resources into.')
param parVnetResourceId string 

@sys.description('Requires. The public DNS zone name for access to application.')
param parPublicDnsZoneName string

// Object containing a mapping for location / region code
var varLocationCodes = {
  germanywestcentral: 'gwc'
  westeurope: 'weu'
}

var varLocationCode = varLocationCodes[parLocation]

var _dep = deployment().name

resource resVnet1 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  scope: resourceGroup(split(parVnetResourceId, '/')[4])
  name: last(split(parVnetResourceId, '/'))
}

module modLogWorkSpace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
  name: '${_dep}-logworkspace'
  scope: resourceGroup()
  params: {
    name: 'log-${varLocationCode}-001-${parEnvironment}'
    location: parLocation
  }
}


module modKeyVault 'br/public:avm/res/key-vault/vault:0.13.0' = {
  scope: resourceGroup()
  name: '${_dep}-keyvault'  
  params: {
    name: 'kv-${varLocationCode}-001-${parEnvironment}-${take(uniqueString(resourceGroup().name,subscription().id),6)}'
    location: parLocation
    enablePurgeProtection: true
  }
}

module modPublicDnsZone 'br/public:avm/res/network/dns-zone:0.5.3' = {
  scope: resourceGroup()
  name: '${_dep}-dnszone'
  params: {
    name: parPublicDnsZoneName
  }
}

module modRbacKeyVaultAcmeBot '../../../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  name: '${_dep}-rbac-keyvault-acmebot'
  scope: resourceGroup()
  params: {
    principalId: modKeyVaultAcmeBot.outputs.principalId
    roleDefinitionId: 'a4417e6f-fecd-4de8-b567-7b0420556985' // Key Vault Certificates Officer
    resourceId: modKeyVault.outputs.resourceId
  }
}

module modRbacDnsZoneKeyVaultAcme '../../../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  name: '${_dep}-rbac-dnszone-keyvault-acmebot'
  scope: resourceGroup()
  params: {
    principalId: modKeyVaultAcmeBot.outputs.principalId
    roleDefinitionId: 'befefa01-2a29-4197-83a8-272ff33ce314' // DNS Zone Contributor
    resourceId: modPublicDnsZone.outputs.resourceId
  }
}

module modKeyVaultAcmeBot 'modules/keyvault-acmebot.bicep' = {
  name: 'keyvault-acmebot'
  scope: resourceGroup()
  params: {
    appNamePrefix: 'jdacmebot01'
    location: parLocation
    mailAddress: 'noreply@noreply.org'
    createWithKeyVault: false
    keyVaultBaseUrl: modKeyVault.outputs.uri
    parLogWorkspaceResourceId: modLogWorkSpace.outputs.resourceId
    additionalAppSettings: [
      {
        name: 'Acmebot:AzureDns:SubscriptionId'
        value: last(split(subscription().id, '/'))
      }

    ]
    parEnableMiAsFic: true
  }
}


output acmeBotAppName string = modKeyVaultAcmeBot.outputs.functionAppName

@secure()
output outFunctionAppKey string = modKeyVaultAcmeBot.outputs.outFunctionAppKey



