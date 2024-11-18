metadata name = 'KeyVault Module'
metadata description = 'Keyvault deployment with check for existing soft deleted resource'

targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@sys.description('Prefix value which will be prepended to all resource names.')
param parCompanyPrefix string = 'alz'

@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Region where to deploy the resources.')
param parLocation string = resourceGroup().location

@sys.description('Region code for resource naming.')
param parLocationCode string = 'gwc'

@sys.description('KeyVault name.')
param parKeyVaultName string = 'kv-${parLocationCode}-001-${parTags.Environment}-${take(uniqueString(resourceGroup().name),6)}'

@sys.description('Enable secret deployment on Key Vault.')
param parSecretDeployEnabled bool = false

/*** VARIABLES ***/

var _dep = deployment().name



/*** NEW RESOURCES ***/

// User-assigned Managed Identity for KeyVault soft recovery

module modRecoverSoftDeletedKeyVaultIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: '${_dep}-id-kv-softRecover'
  params: {
    name: 'id-${parLocationCode}-kv-softRecover'
    location: parLocation
    tags: parTags
  }
}

// Set RBAC permissions for User-assigned Managed Identity  for KeyVault soft recovery

module modRoleAssignIdKvSoftRecover '../../../../../bicep-registry-modules/avm/ptn/authorization/role-assignment/modules/subscription.bicep' = {
  name: '${_dep}-roleAssignIdKvSoftRecover'
  scope:subscription()
  params: {
    principalId: modRecoverSoftDeletedKeyVaultIdentity.outputs.principalId
    roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/f25e0fa2-a7c8-4377-a976-54943a77a395'    // Key Vault Contributor
    principalType: 'ServicePrincipal'
    subscriptionId: subscription().id
  }
}

// User-assigned Managed Identity for access to KeyVault for new or existing secret deployment

module modSecretDeployIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = if (parSecretDeployEnabled) {
  name: '${_dep}-id-kv-secretDeploy'
  params: {
    location: parLocation
    name: 'id-${parLocationCode}-${parTags.Environment}-kv-secretDeploy'
    tags: parTags
  }
}

// Check for soft-deleted Key Vault and recover

module modKvSoftRecoverScript 'br/public:avm/res/resources/deployment-script:0.5.0' = {
  name: '${_dep}-kvSoftRecoverScript'
  params: {
    tags: parTags
    location: parLocation
    name: '${parKeyVaultName}-recover'
    kind: 'AzurePowerShell'
    retentionInterval: 'PT1H'
    azPowerShellVersion: '12.3'
    cleanupPreference: 'Always'
    managedIdentities: {
      userAssignedResourceIds: [
        modRecoverSoftDeletedKeyVaultIdentity.outputs.resourceId
      ]
    }
    environmentVariables: [
        {
          name: 'KV_NAME'
          value: parKeyVaultName
        }
        {
          name: 'KV_LOCATION'
          value: parLocation
        }
      ]
    scriptContent: loadTextContent('kv-recover.ps1')
  }
}

// Create new Key Vault if not recovered or modify if recovered

module modKeyVault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: '${_dep}-KeyVault'
  dependsOn: [modKvSoftRecoverScript]
  params: {
    tags: parTags
    location: parLocation
    name: parKeyVaultName
    enableVaultForDeployment: true
    enableRbacAuthorization: true
    enableVaultForDiskEncryption: true
    enableVaultForTemplateDeployment: true
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    roleAssignments: parSecretDeployEnabled ? [ 
      parSecretDeployEnabled ? { 
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
        principalId: modSecretDeployIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
      }:{}
      parSecretDeployEnabled ? { 
        roleDefinitionIdOrName: 'Key Vault Contributor'
        principalId: modSecretDeployIdentity.outputs.principalId
        principalType: 'ServicePrincipal' 
      }:{}
    ]:[]
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}




// =========== //
// Outputs     //
// =========== //
@description('The resource ID of the key vault.')
output resourceId string = modKeyVault.outputs.resourceId


@description('The name of the resource group the key vault was created in.')
output resourceGroupName string = modKeyVault.outputs.resourceGroupName


@description('The name of the key vault.')
output name string = modKeyVault.outputs.name

@description('The URI of the key vault.')
output uri string = modKeyVault.outputs.uri

@description('The location the resource was deployed into.')
output location string = modKeyVault.outputs.location

@description('User-assigned Managed Identity for access to KeyVault.')
output SecretDeployIdentityId string = (parSecretDeployEnabled) ? modSecretDeployIdentity.outputs.resourceId : ''
