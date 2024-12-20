metadata name = 'ALZ Bicep - Identity Module'
metadata description = 'ALZ Bicep Module used to set up Identity resources'

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

@sys.description('The identity virtual network resource Id that will host the VMs NIC')
param parIdentityVnetResourceId string

@sys.description('The identity subnet name that will host the VMs NIC')
param parIdentitySubnetName string = 'identity-subnet1'

@sys.description('VM admin user name')
@secure()
param parAdminUserName string


@description('Optional. Virtual machine time zone')
param parTimeZone string = 'W. Europe Standard Time'

param parTimeNow string = utcNow('u')


/*** VARIABLES ***/

var _dep = deployment().name
var varEnvironment = parTags.?Environment ?? 'canary'
var varDc1Name = 'vm-${parLocationCode}-dc-01'
var varDesUserAssignedIdentityName = 'id-${parLocationCode}-des-${parCompanyPrefix}-${varEnvironment}'
var varDesName = 'des-${parLocationCode}-001-${parCompanyPrefix}-${varEnvironment}'
var varSaUserAssignedIdentityName = 'id-${parLocationCode}-sa-${parCompanyPrefix}-${varEnvironment}'

var varGwcSerialConsoleIps = [
  '20.52.94.114'
  '20.52.94.115'
  '20.52.95.48'
  '20.113.251.155'
  '51.116.75.88'
  '51.116.75.89'
  '51.116.75.90'
  '98.67.183.186'
]

var varPrepareDisksSriptUri = 'https://raw.githubusercontent.com/jensdiedrich/vmdeploy/main/prepareDisks.ps1'

var varContainersToCreate = {
  data: [ 'prepareDisks.ps1', 'sample2.txt', 'sample3.txt' ]
}

var varContainersToCreateFormatted = replace(string(varContainersToCreate), '"', '\\"')


/*** EXISTING SUBSCRIPTION RESOURCES ***/

@sys.description('Existing resource group that holds identity network.')
resource identityResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: split(parIdentityVnetResourceId, '/')[4]
}

/*** EXISTING RESOURCES ***/

// Identity virtual network
@sys.description('Existing identity virtual network, as deployed by the platform team into landing zone and with subnets added by the workload team.')
resource resIdentityVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  scope: identityResourceGroup
  name: last(split(parIdentityVnetResourceId, '/'))

  // Identity network's subnet for the nic vms
  resource identitySubnet 'subnets' existing = {
    name: parIdentitySubnetName
  }
}



/*** NEW RESOURCES ***/

module modDc1 'br/public:avm/res/compute/virtual-machine:0.9.0' = {
  name: '${_dep}-Vm1'
  dependsOn: [modKv,modKvPassword]
  params: {
    location: parLocation
    tags: parTags
    name: varDc1Name
    secureBootEnabled: true
    vTpmEnabled: true
    adminUsername: parAdminUserName
    adminPassword: resKv.getSecret('${varDc1Name}-password')
    timeZone: parTimeZone
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2025-datacenter-azure-edition-smalldisk'
      version: 'latest'
    }
    nicConfigurations: [
      {
        tags: parTags
        enableAcceleratedNetworking: false
        name: 'nic-01-vm-${parLocationCode}-dc-01'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: resIdentityVirtualNetwork::identitySubnet.id
            privateIPAllocationMethod: 'Static'
            privateIPAddress: cidrHost(resIdentityVirtualNetwork::identitySubnet.properties.addressPrefix,3)
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      createOption: 'FromImage'
      diskSizeGB: 35
      managedDisk: {
        diskEncryptionSetResourceId: modDes.outputs.resourceId
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    dataDisks: [
      {
        caching: 'None'
        createOption: 'Empty'
        diskSizeGB: 8
        managedDisk: {
          diskEncryptionSetResourceId: modDes.outputs.resourceId
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    ]
    osType: 'Windows'
    vmSize: 'Standard_B2s'
    zone: 1
    enableAutomaticUpdates: true
    patchMode: 'AutomaticByPlatform'
    bypassPlatformSafetyChecksOnUserSchedule: true
    bootDiagnostics: true
    bootDiagnosticStorageAccountName: modSaBootDiag.outputs.name
  }
}

resource resDc1 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: varDc1Name
  dependsOn: [modDc1]
}

module modPrepareDisksDc1 '../../modules/Compute/virtual-machine/runcommand/main.bicep' = {
  name: '${_dep}-prepare-disks-dc1'
  params: {
    location: parLocation
    tags: parTags
    runCommandName: 'PrepareDisks'
    vmName: modDc1.outputs.name
    scriptUri: varPrepareDisksSriptUri
  }
}

module modSaBootDiag 'br/public:avm/res/storage/storage-account:0.14.3' = {
  name: '${_dep}-sa-boot-diag'
  params: {
    name: take(('sa${parLocationCode}bdiag${take(uniqueString(resourceGroup().name),4)}${parTags.Environment}${parCompanyPrefix}'),24)
    tags: parTags
    location: parLocation
    allowBlobPublicAccess: false
    skuName: 'Standard_LRS'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: [for ip in varGwcSerialConsoleIps : {
          action: 'Allow'
          value: ip
        }
      ]
    } 
  }
}

module modSaDeployArtifacts 'br/public:avm/res/storage/storage-account:0.14.3' = {
  name: '${_dep}-sa-deploy-artifacts'
  params: {
    name: take(('sa${parLocationCode}deploy${take(uniqueString(resourceGroup().name),4)}${parTags.Environment}${parCompanyPrefix}'),24)
    tags: parTags
    location: parLocation
    allowBlobPublicAccess: false
    skuName: 'Standard_LRS'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: []
    }
    blobServices: {
      containers: [
        {
          name: 'scripts'
        }
      ]
    }
    roleAssignments: [
      {
        principalId: modIdSa.outputs.principalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }
    ]
  }
}


module modIdSa 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0'  =  {
  name: '${_dep}-${varSaUserAssignedIdentityName}'
  params: {
    name: varSaUserAssignedIdentityName
    location: parLocation
    tags: parTags
  }}


// module modCopyDeployArtifacts2SaScript 'br/public:avm/res/resources/deployment-script:0.5.0' = {
//   name: '${_dep}-copy-deploy-artifacts'
//   dependsOn: [
//     modSaDeployArtifacts
//   ]
//   params: {
//     tags: parTags
//     location: parLocation
//     name: 'copy-deploy-artifacts-to-sa'
//     kind: 'AzurePowerShell'
//     retentionInterval: 'PT1H'
//     azPowerShellVersion: '12.3'
//     cleanupPreference: 'Always'
//     managedIdentities: {
//       userAssignedResourceIds: [
//         modIdSa.outputs.resourceId
//       ]
//     }
//     scriptContent: loadTextContent('createBlobStorageContainers.ps1')
//   }
// }
module modKv '../keyVault/keyVault.bicep' = {
  name: '${_dep}-Kv'
  params: {
    parKeyVaultName: take(('kv-${parLocationCode}-001-${parTags.Environment}-${parCompanyPrefix}-${take(uniqueString(resourceGroup().name),4)}'),24)
    parTags: parTags
    parSecretDeployEnabled: true
    parRoleAssignments: [
      {
        principalId: modIdDes.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Key Vault Crypto Service Encryption User'
      }
    ]
  }
}



resource resKv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  dependsOn: [
    modKv
  ]
  name: take(('kv-${parLocationCode}-001-${parTags.Environment}-${parCompanyPrefix}-${take(uniqueString(resourceGroup().name),4)}'),24)
}

// Key Encryption Key for DES

module modKekDes '../../../../../bicep-registry-modules/avm/res/key-vault/vault/key/main.bicep' =  {
  name: '${_dep}-kek-des'
  params: {
    name: 'kek-des'
    keyVaultName: modKv.outputs.name
    tags: parTags
    kty: 'RSA'
  }
}

// Disk Encryption Set 


module modIdDes 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0'  =  {
  name: '${_dep}-${varDesUserAssignedIdentityName}'
  params: {
    name: varDesUserAssignedIdentityName
    location: parLocation
    tags: parTags
  }}

module modDes 'br/public:avm/res/compute/disk-encryption-set:0.3.0' = {
  name: '${_dep}-${varDesName}'
  params: {
    keyName: modKekDes.outputs.name
    keyVaultResourceId: modKv.outputs.resourceId
    name: varDesName
    encryptionType: 'EncryptionAtRestWithPlatformAndCustomerKeys'
    rotationToLatestKeyVersionEnabled: true
    managedIdentities: {
      userAssignedResourceIds: [modIdDes.outputs.resourceId]
    }
    location: parLocation
    tags: parTags
  }
}

module modKvPassword '../keyVaultSecret/keyVaultSecret.bicep' = {
  name: '${_dep}-KvPassword'
  params: {
    parSecretName: '${varDc1Name}-password'
    parKeyVaultName: modKv.outputs.name
    parTags: parTags
    parSecretDeployIdentityId: modKv.outputs.SecretDeployIdentityId
    parContentType: 'password'
    parRecoverSecret: 'yes'
    parNewSecretVersion: 'no'
    parExpireDate: dateTimeAdd(parTimeNow,'P90D')
  }
}


output dc1ResourceId string = modDc1.outputs.resourceId
output kv1ResourceId string = modKv.outputs.resourceId

output containersToCreate object = varContainersToCreate
output containersToCreateFormatted string = varContainersToCreateFormatted
