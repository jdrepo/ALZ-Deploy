metadata name = 'ALZ Bicep - Onpremise Module'
metadata description = 'ALZ Bicep Module used to set up Onpremise resources'

targetScope = 'subscription'

@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Region where to deploy the resources.')
param parLocation string = 'northeurope'

@sys.description('Name of resource group.')
param parResourceGroupName string = 'rg-onprem'

@sys.description('Region code for resource naming.')
param parLocationCode string = 'neu'

@sys.description('URI for Custom OPN Script and Config')
param parOpnScriptURI string = 'https://raw.githubusercontent.com/jdrepo/ALZ-Deploy/refs/heads/main/opnsense-onprem/scripts/'

@sys.description('Shell Script to be executed')
param parShellScriptName string = 'configureopnsense.sh'

@sys.description('OPN Version')
param parOpnVersion string = '24.7'

@sys.description('Azure WALinux agent Version')
param parWALinuxVersion string = '2.12.0.2'

@sys.description('Admin User for OPNSense.')
param parAdminUserName string = 'azadmin'

@description('Optional. Virtual machine time zone')
param parTimeZone string = 'W. Europe Standard Time'

param parTimeNow string = utcNow('u')

@sys.description('Untrusted-Subnet Name.')
param parUntrustedSubnetName string = 'untrustedSubnet'

@sys.description('Trusted-Subnet Name.')
param parTrustedSubnetName string = 'trustedSubnet'

@sys.description('Trusted-Subnet Name.')
param parTrustedSubnetRange string = '172.22.0.32/27'

@sys.description('Trusted-Subnet Name.')
param parOnpremSubnetName string = 'onpremSubnet'

@sys.description('Define outbound destination ports or ranges for SSH or RDP that you want to access from Azure Bastion.')
param parBastionOutboundSshRdpPorts array = ['22', '3389']

@sys.description('Azure VPN Gateway IP address.')
param parVpnGwPublicIp string = ''


var _dep = deployment().name
var varEnvironment = parTags.?Environment ?? 'canary'
var varOpnsenseName = 'vm-${parLocationCode}-opnsense'
var varVnetName = 'vnet-${parLocationCode}-onprem'
var varDc1Name = 'vm-${parLocationCode}-dc1'

var varSubnets = [
  {
    addressPrefix: '172.22.0.0/27'
    name: parUntrustedSubnetName
    networkSecurityGroupResourceId: modNsgUntrustedSubnet.outputs.resourceId
    routeTableResourceId: ''
  }
  {
    addressPrefix: parTrustedSubnetRange
    name: parTrustedSubnetName
    networkSecurityGroupResourceId: modNsgTrustedSubnet.outputs.resourceId
    routeTableResourceId: ''
  }
  {
    addressPrefix: '172.22.10.0/24'
    name: parOnpremSubnetName
    networkSecurityGroupResourceId: modNsgOnpremSubnet.outputs.resourceId
    routeTableResourceId: modOnpremRouteTable.outputs.resourceId
  }
  {
    addressPrefix: '172.22.0.64/27'
    name: 'AzureBastionSubnet'
    networkSecurityGroupResourceId: modNsgBastion.outputs.resourceId
    routeTableResourceId: ''
  }
]

@sys.description('Select a valid scenario. Active Active: Two OPNSenses deployed in HA mode using SLB and ILB. Two Nics: Single OPNSense deployed with two Nics.')
@allowed([
  'Active-Active'
  'TwoNics'
])
param parScenarioOption string = 'TwoNics'



// module modResourceGroup 'br/public:avm/res/resources/resource-group:0.4.1' = {
//   name: '${_dep}-onprem-resource-group'
//   params: {
//     name: parResourceGroupName
//     location: parLocation
//   }
// }

module modNsgUntrustedSubnet 'br/public:avm/res/network/network-security-group:0.5.0' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-nsg-${parLocationCode}-untrusted-subnet'
  params: {
    location: parLocation
    name: 'nsg-${parLocationCode}-untrusted-subnet'
    securityRules: [
      {
        name: 'Allow-IPsec-ISAKMP'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 4096
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '500'
          destinationAddressPrefix: '172.22.0.4'
          sourceAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-IPsec-NAT-Traversal'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 4095
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '4500'
          destinationAddressPrefix: '172.22.0.4'
          sourceAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-ESP'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 4094
          protocol: 'Esp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '172.22.0.4'
          sourceAddressPrefix: '*'
        }
      }
    ]
  }
}

module modNsgTrustedSubnet 'br/public:avm/res/network/network-security-group:0.5.0' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-nsg-${parLocationCode}-trusted-subnet'
  params: {
    location: parLocation
    name: 'nsg-${parLocationCode}-trusted-subnet'
    securityRules: [
      {
        name: 'In-Vnet-Any'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 4096
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

module modNsgOnpremSubnet 'br/public:avm/res/network/network-security-group:0.5.0' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-nsg-${parLocationCode}-onprem-subnet'
  params: {
    location: parLocation
    name: 'nsg-${parLocationCode}-onprem-subnet'
  }
}


module modNsgBastion 'br/public:avm/res/network/network-security-group:0.5.0' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-nsg-AzureBastionSubnet'
  params: {
    name: 'nsg-AzureBastionSubnet'
    location: parLocation
    securityRules: [
      // Inbound Rules
      {
        name: 'AllowHttpsInbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 120
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 130
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowAzureLoadBalancerInbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 140
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowBastionHostCommunication'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 150
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          access: 'Deny'
          direction: 'Inbound'
          priority: 4096
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
      // Outbound Rules
      {
        name: 'AllowSshRdpOutbound'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 100
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: parBastionOutboundSshRdpPorts
        }
      }
      {
        name: 'AllowAzureCloudOutbound'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 110
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowBastionCommunication'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 120
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
        }
      }
      {
        name: 'AllowGetSessionInformation'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 130
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'DenyAllOutbound'
        properties: {
          access: 'Deny'
          direction: 'Outbound'
          priority: 4096
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}





module modVnet 'br/public:avm/res/network/virtual-network:0.5.2' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-${varVnetName}'
  params: {
    location: parLocation
    name: varVnetName
    addressPrefixes: [
      '172.22.0.0/16'
    ]
    subnets: varSubnets
  }
}

module modPublicIp 'br/public:avm/res/network/public-ip-address:0.7.0' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-pip-${parLocationCode}-opnsense'
  params: {
    name: 'pip-${parLocationCode}-opnsense'
    location: parLocation
    tags: parTags
    publicIPAllocationMethod: 'Static'
    skuName: 'Standard'
    skuTier: 'Regional'
  }
}

module modKv '../keyVault/keyVault.bicep' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-Kv'
  params: {
    parKeyVaultName: take(('kv-${parLocationCode}-001-${parTags.Environment}-${take(uniqueString(parResourceGroupName),4)}'),24)
    parTags: parTags
    parSecretDeployEnabled: true
    parVirtualNetworkRules: []
  }
}

module modKvPasswordOpnsense '../keyVaultSecret/keyVaultSecret.bicep' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-kv-password-opnsensene'
  params: {
    parSecretName: '${varOpnsenseName}-password'
    parKeyVaultName: modKv.outputs.name
    parTags: parTags
    parSecretDeployIdentityId: modKv.outputs.SecretDeployIdentityId
    parContentType: 'password'
    parRecoverSecret: 'yes'
    parNewSecretVersion: 'no'
    parExpireDate: dateTimeAdd(parTimeNow,'P90D')
  }
}


module modKvPasswordDC1 '../keyVaultSecret/keyVaultSecret.bicep' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-kv-password-dc1'
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

resource resKv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  scope: resourceGroup(parResourceGroupName)
  dependsOn: [
    modKv
  ]
  name: take(('kv-${parLocationCode}-001-${parTags.Environment}-${take(uniqueString(parResourceGroupName),4)}'),24)
}

module modOpnSense 'br/public:avm/res/compute/virtual-machine:0.12.0' = {
  name: '${_dep}-opnsense'
  scope: resourceGroup(parResourceGroupName)
  dependsOn: [
    modKv
  ]
  params: {
    name: varOpnsenseName
    location: parLocation
    adminUsername: parAdminUserName
    adminPassword: resKv.getSecret('${varOpnsenseName}-password')
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
        name: 'nic-${parLocationCode}-opnsense-untrusted'
        enableAcceleratedNetworking: false
        enableIPForwarding: true
        ipConfigurations: [{
          name: 'ipconfig01'
          subnetResourceId: modVnet.outputs.subnetResourceIds[0]
          privateIPAllocationMethod: 'Static'
          privateIPAddress: cidrHost(varSubnets[0].addressPrefix,3)
          pipConfiguration: {
            publicIPAddressResourceId: modPublicIp.outputs.resourceId
          }
        }]
      }
      {
        tags: parTags
        name: 'nic-${parLocationCode}-opnsense-trusted'
        enableAcceleratedNetworking: false
        enableIPForwarding: true
        ipConfigurations: [{
          name: 'ipconfig01'
          subnetResourceId: modVnet.outputs.subnetResourceIds[1]
          privateIPAllocationMethod: 'Static'
          privateIPAddress: cidrHost(parTrustedSubnetRange,3)
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
    vmSize: 'Standard_B2als_v2'
    zone: 2
    bootDiagnostics: true
  }
}


module modScriptExtension '../../../../../bicep-registry-modules/avm/res/compute/virtual-machine/extension/main.bicep' = {
  name: '${_dep}-opnsense-script-extension'
  dependsOn: [modOpnSense]
  scope: resourceGroup(parResourceGroupName)
  params: {
    name: 'CustomScript'
    autoUpgradeMinorVersion: false
    enableAutomaticUpgrade: false
    publisher: 'Microsoft.OSTCExtensions'
    type: 'CustomScriptForLinux'
    typeHandlerVersion: '1.5'
    virtualMachineName: varOpnsenseName
    settings: {
      fileUris: [
        '${parOpnScriptURI}${parShellScriptName}'
      ]
      commandToExecute: 'sh ${parShellScriptName} ${parOpnScriptURI} ${parOpnVersion} ${parWALinuxVersion} ${parScenarioOption} ${varSubnets[1].addressPrefix} "\'" "\'" "\'"1.1.1.1/32"\'" "\'" "\'" "\'"9.9.9.9"\'" '
    }
  }
}

module modDc1 'br/public:avm/res/compute/virtual-machine:0.12.0' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-Vm1'
  dependsOn: [modKv]
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
        name: 'nic-01-${varDc1Name}'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: modVnet.outputs.subnetResourceIds[2]
            privateIPAllocationMethod: 'Static'
            privateIPAddress: cidrHost(varSubnets[2].addressPrefix, 4)
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
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    dataDisks: [
      {
        caching: 'None'
        createOption: 'Empty'
        diskSizeGB: 8
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    ]
    osType: 'Windows'
    vmSize: 'Standard_B2als_v2'
    zone: 2
    enableAutomaticUpdates: true
    patchMode: 'AutomaticByPlatform'
    bypassPlatformSafetyChecksOnUserSchedule: true
    bootDiagnostics: true
    managedIdentities: {
      systemAssigned: true
    }
  }
}

module modOnpremRouteTable 'br/public:avm/res/network/route-table:0.4.0' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-rt-${parLocationCode}-onprem'
  params: {
    name: 'rt-${parLocationCode}-onprem'
    routes: [
      {
        name: 'default'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: cidrHost(parTrustedSubnetRange,3)
          nextHopType: 'VirtualAppliance'
        }
      }
    ]
  }
}

module modBastion 'bastion.bicep' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-bastion-${parLocationCode}-onprem'
  params: {
    parBastionName: 'bastion-${parLocationCode}-onprem'
    parLocation: parLocation
    parVnetResourceId: modVnet.outputs.resourceId
    parTags: parTags
  }
}

module modLogAnalytics 'br/public:avm/res/operational-insights/workspace:0.10.0' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-laws-${parLocationCode}-onprem'
  params: {
    name: 'laws-${parLocationCode}-onprem'
    location: parLocation
  }
}

module modSaOnpremDiag 'br/public:avm/res/storage/storage-account:0.17.0' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-sa-${parLocationCode}-diag-onprem'
  params: {
    name: take(('sa${parLocationCode}diagonprem${take(uniqueString(parResourceGroupName),6)}'),24)
    skuName: 'Standard_LRS'
    location: parLocation
  }
}

module modVnetFlowLog 'br/public:avm/res/network/network-watcher:0.4.0' = {
  scope: resourceGroup('NetworkwatcherRG')
  name: '${_dep}-${varVnetName}-flowlog'
  params: {
    location: parLocation
    flowLogs: [
      {
        enabled: true
        storageId: modSaOnpremDiag.outputs.resourceId
        targetResourceId: modVnet.outputs.resourceId
        retentionInDays: 8
        workspaceResourceId: modLogAnalytics.outputs.resourceId
        trafficAnalyticsInterval: 10
      }
    ]
  }
}

