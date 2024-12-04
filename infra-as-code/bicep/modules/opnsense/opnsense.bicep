metadata name = 'ALZ Bicep - OpnSense Module'
metadata description = 'ALZ Bicep Module used to set up OpnSense'

targetScope = 'resourceGroup'

/*** USERDEFINED TYPES ***/

type subnetOptionsType = ({
  @description('Name of subnet.')
  name: string

  @description('IP-address range for subnet.')
  ipAddressRange: string

  @description('Id of Network Security Group to associate with subnet.')
  networkSecurityGroupId: string?

  @description('Id of Route Table to associate with subnet.')
  routeTableId: string?

  @description('Name of the delegation to create for the subnet.')
  delegation: string?
})[]

/*** PARAMETERS ***/

@sys.description('Prefix value which will be prepended to all resource names.')
param parCompanyPrefix string = 'alz'

@description('Prefix for management group hierarchy.')
@minLength(2)
@maxLength(10)
param parTopLevelManagementGroupPrefix string = 'alz'

@description('Optional suffix for management group names/IDs.')
@maxLength(10)
param parTopLevelManagementGroupSuffix string = ''

@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Select a valid scenario. Active Active: Two OPNSenses deployed in HA mode using SLB and ILB. Two Nics: Single OPNSense deployed with two Nics.')
@allowed([
  'Active-Active'
  'TwoNics'
])
param parScenarioOption string = 'TwoNics'

@sys.description('VM size, please choose a size which allow 2 NICs.')
param parVirtualMachineSize string = 'Standard_B2s'

@sys.description('OPN NVA Manchine Name')
param parVirtualMachineName string

@sys.description('Existing Virtual Network Resource Id.')
param parVirtualNetworkResourceId string

@sys.description('Untrusted-Subnet Address Space.')
param parUntrustedSubnetCIDR string = '10.10.251.0/24'

@sys.description('Trusted-Subnet Address Space.')
param parTrustedSubnetCIDR string = '10.10.250.0/24'

@sys.description('Untrusted-Subnet Name.')
param parUntrustedSubnetName string = 'OPNS-Untrusted'

@sys.description('Trusted-Subnet Name.')
param parTrustedSubnetName string = 'OPNS-Trusted'

@sys.description('Specify Public IP SKU either Basic (lowest cost) or Standard (Required for HA LB)"')
@allowed([
  'Basic'
  'Standard'
])
param PublicIPAddressSku string = 'Standard'

@sys.description('URI for Custom OPN Script and Config')
param parOpnScriptURI string = 'https://raw.githubusercontent.com/jdrepo/ALZ-Deploy/refs/heads/main/opnsense/scripts/'

@sys.description('Shell Script to be executed')
param parShellScriptName string = 'configureopnsense.sh'

@sys.description('OPN Version')
param parOpnVersion string = '24.7'

@sys.description('Azure WALinux agent Version')
param parWALinuxVersion string = '2.12.0.2'

@sys.description('Region where to deploy the resources.')
param parLocation string = resourceGroup().location

@sys.description('Region code for resource naming.')
param parLocationCode string = 'gwc'

@sys.description('Admin User for OPNSense.')
param parAdminUser string = 'azureuser'

@description('Optional. Virtual machine time zone')
param parTimeZone string = 'W. Europe Standard Time'

param parTimeNow string = utcNow('u')


/*** VARIABLES ***/

var _dep = deployment().name
var varEnvironment = parTags.?Environment ?? 'canary'
var varPublicIPAddressName = 'pip-${parLocationCode}-${parVirtualMachineName}-${parCompanyPrefix}-${varEnvironment}'
var varTrustedNicName = 'nic-${parLocationCode}-trusted-${parVirtualMachineName}-${parCompanyPrefix}-${varEnvironment}'
var varUntrustedNicName = 'nic-${parLocationCode}-untrusted-${parVirtualMachineName}-${parCompanyPrefix}-${varEnvironment}'
var varDesUserAssignedIdentityName = 'id-${parLocationCode}-des-${parCompanyPrefix}-${varEnvironment}'
var varDesName = 'des-${parLocationCode}-001-${parCompanyPrefix}-${varEnvironment}'

var varNsgName = 'nsg-${parLocationCode}-opnsense-${parCompanyPrefix}-${varEnvironment}'

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

// Management Groups Variables - Used For Policy Exemptions
var varManagementGroupIds = {
  intRoot: '${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}'
  platform: '${parTopLevelManagementGroupPrefix}-platform${parTopLevelManagementGroupSuffix}'
}

var varPolicyExemptionDeployVMMonitoring = {
  definitionId: '/providers/Microsoft.Management/managementGroups/${varManagementGroupIds.platform}/providers/Microsoft.Authorization/policyAssignments/Deploy-VM-Monitoring'
  libDefinition: loadJsonContent('../policy/exemptions/lib/policy_exemptions/policy_exemption_freebsd_es_deploy_vm_monitor.tmpl.json')
}

var varPolicyExemptionDeployMDEndpoints = {
  definitionId: '/providers/Microsoft.Management/managementGroups/${varManagementGroupIds.intRoot}/providers/Microsoft.Authorization/policyAssignments/deploy-mdendpoints'
  libDefinition: loadJsonContent('../policy/exemptions/lib/policy_exemptions/policy_exemption_freebsd_es_deploy_mdeendpoints.tmpl.json')
}

var varPolicyExemptionEnforceACSB = {
  definitionId: '/providers/Microsoft.Management/managementGroups/${varManagementGroupIds.intRoot}/providers/Microsoft.Authorization/policyAssignments/enforce-acsb'
  libDefinition: loadJsonContent('../policy/exemptions/lib/policy_exemptions/policy_exemption_freebsd_es_enforce_acsb.tmpl.json')
}

var varPolicyExemptionAuditTrustedLaunch = {
  definitionId: '/providers/Microsoft.Management/managementGroups/${varManagementGroupIds.intRoot}/providers/Microsoft.Authorization/policyAssignments/audit-trustedlaunch'
  libDefinition: loadJsonContent('../policy/exemptions/lib/policy_exemptions/policy_exemption_freebsd_es_audit_trustedlaunch.tmpl.json')
}

var varPolicyExemptionDeployMDfCConfig = {
  definitionId: '/providers/Microsoft.Management/managementGroups/${varManagementGroupIds.intRoot}/providers/Microsoft.Authorization/policyAssignments/deploy-mdfc-config-h224'
  libDefinition: loadJsonContent('../policy/exemptions/lib/policy_exemptions/policy_exemption_freebsd_es_deploy_mdfc_config.json')
}

/*** EXISTING RESOURCES ***/

@sys.description('Existing connectivity virtual network, as deployed by the platform team into landing zone.')
resource resConnectivityVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: last(split(parVirtualNetworkResourceId, '/'))

  // OPNSense trusted subnet
  resource trustedSubnet 'subnets' existing = {
    name:  parTrustedSubnetName
  }
  // OPNSense trusted subnet
  resource unTrustedSubnet 'subnets' existing = {
    name:  parUntrustedSubnetName
  }
}

/*** NEW RESOURCES ***/

// module modOpnSenseNsg 'br/public:avm/res/network/network-security-group:0.5.0' = {
//   name: '${_dep}-opnsense-nsg'
//   params: {
//     name: varNsgName
//     tags: parTags
//     securityRules: [
//       {
//         name: 'In-Any'
//         properties: {
//           priority: 4096
//           sourceAddressPrefix: '*'
//           protocol: '*'
//           destinationPortRange: '*'
//           access: 'Allow'
//           direction: 'Inbound'
//           sourcePortRange: '*'
//           destinationAddressPrefix: '*'
//         }
//       }
//       {
//         name: 'Out-Any'
//         properties: {
//           priority: 4096
//           sourceAddressPrefix: '*'
//           protocol: '*'
//           destinationPortRange: '*'
//           access: 'Allow'
//           direction: 'Outbound'
//           sourcePortRange: '*'
//           destinationAddressPrefix: '*'
//         }
//       }
//     ]
//   }
// }

// module modTrustedSubnet '../../../../../bicep-registry-modules/avm/res/network/virtual-network/subnet/main.bicep' = {
//   name: '${_dep}-trusted-subnet'
//   params: {
//     name: parTrustedSubnetName
//     virtualNetworkName: resConnectivityVirtualNetwork.name
//     addressPrefix: parTrustedSubnetCIDR
//     networkSecurityGroupResourceId: modOpnSenseNsg.outputs.resourceId
//     serviceEndpoints: [
//       'Microsoft.Storage'
//       'Microsoft.KeyVault'
//     ]
//   }
// }

// module modUntrustedSubnet '../../../../../bicep-registry-modules/avm/res/network/virtual-network/subnet/main.bicep' = {
//   name: '${_dep}-untrusted-subnet'
//   params: {
//     name: parUntrustedSubnetName
//     virtualNetworkName: resConnectivityVirtualNetwork.name
//     addressPrefix: parUntrustedSubnetCIDR
//     networkSecurityGroupResourceId: modOpnSenseNsg.outputs.resourceId
//     serviceEndpoints: [
//       'Microsoft.Storage'
//       'Microsoft.KeyVault'
//     ]
//   }
// }



module modPublicIp 'br/public:avm/res/network/public-ip-address:0.7.0' = {
  name: '${_dep}-publicip'
  params: {
    name: varPublicIPAddressName
    location: parLocation
    tags: parTags
    publicIPAllocationMethod: 'Static'
    skuName: 'Standard'
    skuTier: 'Regional'
  }
}

// module modTrustedNic 'br/public:avm/res/network/network-interface:0.4.0' = {
//   name: '${_dep}-trustednic'
//   params: {
//     name: varTrustedNicName
//     location: parLocation
//     tags: parTags
//     enableIPForwarding: true
//     ipConfigurations: [
//       {
//         name: 'ipconfig01'
//         subnetResourceId: modTrustedSubnet.outputs.resourceId
//         privateIPAllocationMethod: 'Static'
//         privateIPAddress: '10.10.250.4'
//       }
//     ]
//   }
// }

// module modUntrustedNic 'br/public:avm/res/network/network-interface:0.4.0' = {
//   name: '${_dep}-untrustednic'
//   params: {
//     name: varUntrustedNicName
//     location: parLocation
//     tags: parTags
//     enableIPForwarding: true
//     ipConfigurations: [
//       {
//         name: 'ipconfig01'
//         subnetResourceId: modUntrustedSubnet.outputs.resourceId
//         privateIPAllocationMethod: 'Static'
//         privateIPAddress: '10.10.251.4'
//         publicIPAddressResourceId: modPublicIp.outputs.resourceId
//       }
//     ]
//   }
// }

// module modOpnSense 

module modOpnSense 'br/public:avm/res/compute/virtual-machine:0.10.0' = {
  name: '${_dep}-opnsense'
  dependsOn: [
    modKv
  ]
  params: {
    name: parVirtualMachineName
    location: parLocation
    adminUsername: parAdminUser
    adminPassword: resKv.getSecret('${parVirtualMachineName}-password')
    secureBootEnabled: false
    vTpmEnabled: false
    timeZone: parTimeZone
    imageReference: {
      publisher: 'thefreebsdfoundation'
      offer: 'freebsd-14_1'
      sku: '14_1-release-amd64-gen2-zfs'
      version: 'latest'
    }

    nicConfigurations: [
      {
        tags: parTags
        name: varUntrustedNicName
        enableAcceleratedNetworking: false
        enableIPForwarding: true
        ipConfigurations: [{
          name: 'ipconfig01'
          subnetResourceId: resConnectivityVirtualNetwork::unTrustedSubnet.id
          privateIPAllocationMethod: 'Static'
          privateIPAddress: cidrHost(resConnectivityVirtualNetwork::unTrustedSubnet.properties.addressPrefix,3)
          pipConfiguration: {
            publicIPAddressResourceId: modPublicIp.outputs.resourceId
          }
        }]
      }
      {
        tags: parTags
        name: varTrustedNicName
        enableAcceleratedNetworking: false
        enableIPForwarding: true
        ipConfigurations: [{
          name: 'ipconfig01'
          subnetResourceId: resConnectivityVirtualNetwork::trustedSubnet.id
          privateIPAllocationMethod: 'Static'
          privateIPAddress: cidrHost(resConnectivityVirtualNetwork::trustedSubnet.properties.addressPrefix,3)
        }]
        deleteOption: 'Delete'
      }
    ]
    
    osDisk: {
      diskSizeGB: 30
      caching: 'ReadWrite'
      createOption: 'FromImage'
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    
    plan: {
      name: '14_1-release-amd64-gen2-zfs'
      publisher: 'thefreebsdfoundation'
      product: 'freebsd-14_1'
    }
    osType: 'Linux'
    vmSize: parVirtualMachineSize
    zone: 1
    bootDiagnostics: true
    bootDiagnosticStorageAccountName: modSaBootDiag.outputs.name
  }
}

resource resOpnSense 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: parVirtualMachineName
  dependsOn: [modOpnSense]
}
 
resource vmext 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: resOpnSense
  dependsOn: [modOpnSense]
  name: 'CustomScript'
  location: parLocation
  properties: {
    publisher: 'Microsoft.OSTCExtensions'
    type: 'CustomScriptForLinux'
    typeHandlerVersion: '1.5'
    autoUpgradeMinorVersion: false
    settings:{
      fileUris: [
        '${parOpnScriptURI}${parShellScriptName}'
      ]
      commandToExecute: 'sh ${parShellScriptName} ${parOpnScriptURI} ${parOpnVersion} ${parWALinuxVersion} ${parScenarioOption} ${resConnectivityVirtualNetwork::trustedSubnet.properties.addressPrefix} "\'" "\'" "\'"1.1.1.1/32"\'" "\'" "\'" "\'" "\'" '
    }
  }
}



module modSaBootDiag 'br/public:avm/res/storage/storage-account:0.14.3' = {
  name: '${_dep}-sabootdiag'
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
module modKv '../keyVault/keyVault.bicep' = {
  name: '${_dep}-Kv'
  params: {
    parKeyVaultName: take(('kv-${parLocationCode}-001-${parTags.Environment}-${parCompanyPrefix}-${take(uniqueString(resourceGroup().name),4)}'),24)
    parTags: parTags
    parSecretDeployEnabled: true
    parVirtualNetworkRules: []
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
    parSecretName: '${parVirtualMachineName}-password'
    parKeyVaultName: modKv.outputs.name
    parTags: parTags
    parSecretDeployIdentityId: modKv.outputs.SecretDeployIdentityId
    parContentType: 'password'
    parRecoverSecret: 'yes'
    parNewSecretVersion: 'no'
    parExpireDate: dateTimeAdd(parTimeNow,'P90D')
  }
}


module modPolicyExemptionDeployMDEndpoints '../policy/exemptions/policy-exemption-resource-vm.bicep' = {
  name: '${_dep}-policy-exemption-deployMDEndpoints'
  params: {
    name: varPolicyExemptionDeployMDEndpoints.libDefinition.name
    exemptionCategory: 'Waiver'
    policyAssignmentId: varPolicyExemptionDeployMDEndpoints.definitionId
    displayName: varPolicyExemptionDeployMDEndpoints.libDefinition.properties.displayName
    description: varPolicyExemptionDeployMDEndpoints.libDefinition.properties.description
    policyDefinitionReferenceIds: varPolicyExemptionDeployMDEndpoints.libDefinition.properties.policyDefinitionReferenceIds
    resourceId: modOpnSense.outputs.resourceId
  }
}

module modPolicyExemptionDeployVMMonitoring '../policy/exemptions/policy-exemption-resource-vm.bicep' = {
  name: '${_dep}-policy-exemption-deployVMMonitoring'
  params: {
    name: varPolicyExemptionDeployVMMonitoring.libDefinition.name
    exemptionCategory: 'Waiver'
    policyAssignmentId: varPolicyExemptionDeployVMMonitoring.definitionId
    displayName: varPolicyExemptionDeployVMMonitoring.libDefinition.properties.displayName
    description: varPolicyExemptionDeployVMMonitoring.libDefinition.properties.description
    policyDefinitionReferenceIds: varPolicyExemptionDeployVMMonitoring.libDefinition.properties.policyDefinitionReferenceIds
    resourceId: modOpnSense.outputs.resourceId
  }
}

module modPolicyExemptionEnforceACSB '../policy/exemptions/policy-exemption-resource-vm.bicep' = {
  name: '${_dep}-policy-exemption-enforceACSB'
  params: {
    name: varPolicyExemptionEnforceACSB.libDefinition.name
    exemptionCategory: 'Waiver'
    policyAssignmentId: varPolicyExemptionEnforceACSB.definitionId
    displayName: varPolicyExemptionEnforceACSB.libDefinition.properties.displayName
    description: varPolicyExemptionEnforceACSB.libDefinition.properties.description
    policyDefinitionReferenceIds: varPolicyExemptionEnforceACSB.libDefinition.properties.policyDefinitionReferenceIds
    resourceId: modOpnSense.outputs.resourceId
  }
}

module modPolicyExemptionAuditTrustedLaunch '../policy/exemptions/policy-exemption-resource-vm.bicep' = {
  name: '${_dep}-policy-exemption-auditTrustedLaunch'
  params: {
    name: varPolicyExemptionAuditTrustedLaunch.libDefinition.name
    exemptionCategory: 'Waiver'
    policyAssignmentId: varPolicyExemptionAuditTrustedLaunch.definitionId
    displayName: varPolicyExemptionAuditTrustedLaunch.libDefinition.properties.displayName
    description: varPolicyExemptionAuditTrustedLaunch.libDefinition.properties.description
    policyDefinitionReferenceIds: varPolicyExemptionAuditTrustedLaunch.libDefinition.properties.policyDefinitionReferenceIds
    resourceId: modOpnSense.outputs.resourceId
  }
}

module modPolicyExemptionDeployMDfCConfig '../policy/exemptions/policy-exemption-resource-vm.bicep' = {
  name: '${_dep}-policy-exemption-deployMDfCConfig'
  params: {
    name: varPolicyExemptionDeployMDfCConfig.libDefinition.name
    exemptionCategory: 'Waiver'
    policyAssignmentId: varPolicyExemptionDeployMDfCConfig.definitionId
    displayName: varPolicyExemptionDeployMDfCConfig.libDefinition.properties.displayName
    description: varPolicyExemptionDeployMDfCConfig.libDefinition.properties.description
    policyDefinitionReferenceIds: varPolicyExemptionDeployMDfCConfig.libDefinition.properties.policyDefinitionReferenceIds
    resourceId: modOpnSense.outputs.resourceId
  }
}


