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

@sys.description('VM admin password')
@secure()
param parAdminPassword string

@description('Optional. Virtual machine time zone')
param parTimeZone string = 'W. Europe Standard Time'

/*** VARIABLES ***/

var _dep = deployment().name
var ip = cidrHost(resIdentityVirtualNetwork::identitySubnet.properties.addressPrefix,0)

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

// module modVm1 'br/public:avm/res/compute/virtual-machine:0.9.0' = {
//   name: '${_dep}-Vm1'
//   params: {
//     location: parLocation
//     tags: parTags
//     name: 'vm-${parLocationCode}-dc-01'
//     adminUsername: parAdminUserName
//     adminPassword: parAdminPassword
//     timeZone: parTimeZone
//     imageReference: {
//       offer: 'WindowsServer'
//       publisher: 'MicrosoftWindowsServer'
//       sku: '2025-datacenter-azure-edition-smalldisk'
//       version: 'latest'
//     }
//     nicConfigurations: [
//       {
//         tags: parTags
//         enableAcceleratedNetworking: false
//         ipConfigurations: [
//           {
//             name: 'ipconfig01'
//             subnetResourceId: resIdentityVirtualNetwork::identitySubnet.id
//             privateIPAllocationMethod: 'Static'
//             //privateIPAddress: cidrHost(resIdentityVirtualNetwork::identitySubnet.properties.addressPrefix,0)
//             privateIPAddress: '10.20.1.1'

            
//           }
//         ]
//         nicSuffix: 'nic-01'
//       }
//     ]
//     osDisk: {
//       caching: 'ReadWrite'
//       diskSizeGB: 35
//       managedDisk: {
//         storageAccountType: 'StandardSSD_LRS'
//       }
//     }
//     dataDisks: [
//       {
//         caching: 'None'
//         createOption: 'Empty'
//         diskSizeGB: 8
//         managedDisk: {
//           storageAccountType: 'StandardSSD_LRS'
//         }
//       }
//     ]
//     osType: 'Windows'
//     vmSize: 'Standard_B2s'
//     zone: 1
//     enableAutomaticUpdates: true
//     patchMode: 'AutomaticByPlatform'
//     bypassPlatformSafetyChecksOnUserSchedule: true
//   }
// }

// module modKv1 'br/public:avm/res/key-vault/vault:0.9.0' = {
//   name: '${_dep}-Kv1'
//   params: {
//     name: 'kv-${parLocationCode}-01-${take(uniqueString(resourceGroup().name),6)}'
//   }
// }

output cidr string =  cidrHost(resIdentityVirtualNetwork::identitySubnet.properties.addressPrefix,0)
output ip string = ip
