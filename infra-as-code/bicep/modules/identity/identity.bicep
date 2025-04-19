metadata name = 'ALZ Bicep - Identity Module'
metadata description = 'ALZ Bicep Module used to set up Identity resources'

targetScope = 'resourceGroup'

type subnetOptionsType = ({
  @description('Name of subnet.')
  name: string

  @description('IP-address range for subnet.')
  addressPrefix: string

  @description('Name of Network Security Group to associate with subnet.')
  networkSecurityGroupName: string?

  @description('Name of Route Table to associate with subnet.')
  routeTableResourceName: string?

  @description('Delegations to create for the subnet.')
  delegations: string?

  @description('Service endpoints to create for the subnet.')
  serviceEndpoints: array?
})[]

type lockType = {
  @description('Optional. Specify the name of lock.')
  name: string?

  @description('Optional. The lock settings of the service.')
  kind: ('CanNotDelete' | 'ReadOnly' | 'None')

  @description('Optional. Notes about this lock.')
  notes: string?
}

/*** PARAMETERS ***/

@sys.description('''Resource Lock Configuration for Virtual Network.

- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.

''')
param parVirtualNetworkLock lockType = {
  kind: 'None'
  notes: 'This lock was created by the ALZ Bicep Identity Networking Module.'
}

@sys.description('Prefix value which will be prepended to all resource names.')
param parCompanyPrefix string = 'alz'

@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('''Global Resource Lock Configuration used for all resources deployed in this module.

- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.

''')
param parGlobalResourceLock lockType = {
  kind: 'None'
  notes: 'This lock was created by the Identity Networking Module.'
}

@sys.description('Region where to deploy the resources.')
param parLocation string = resourceGroup().location

@sys.description('Region code for resource naming.')
param parLocationCode string = 'gwc'

@sys.description('The identity virtual network resource Id that will host the VMs NIC')
param parIdentityVnetResourceId string

@sys.description('Name for Identity Network.')
param parIdentityNetworkName string = 'vnet-${parLocation}-identity-${parCompanyPrefix}'

@sys.description('Name for Network Security Group for identity network')
param parIdentityNsgName string = 'nsg-${parLocation}-001-${parCompanyPrefix}'

@sys.description('Name for Network Security Group for container network')
param parContainerNsgName string = 'nsg-${parLocation}-container-${parCompanyPrefix}'

@sys.description('Name for Network Security Group for Bastion network')
param parBastionNsgName string = 'nsg-${parLocation}-bastion-${parCompanyPrefix}'

@sys.description('The IP address range for Identity Network.')
param parIdentityNetworkAddressPrefix string = '10.20.0.0/16'

@sys.description('The name, IP address range, network security group, route table, delegation serviceName and serviceEndpoints for each subnet in the virtual networks.')
param parSubnets subnetOptionsType = [
  {
    name: 'identity-subnet1'
    addressPrefix: '10.20.1.0/24'
    networkSecurityGroupName: parIdentityNsgName
    routeTableResourceName: ''
    serviceEndpoints: [
        'Microsoft.Storage'
    ]
    delegations: ''
  }
  {
    name: 'container-subnet1'
    addressPrefix: '10.20.10.0/28'
    networkSecurityGroupName: parContainerNsgName
    routeTableResourceName: ''
    serviceEndpoints: [
        'Microsoft.Storage'
    ]
    delegations: 'Microsoft.ContainerInstance/containerGroups'
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: '10.20.0.64/27'
    networkSecurityGroupName: parBastionNsgName
    routeTableResourceName: ''
    serviceEndpoints: []
    delegations: ''
  }
]

@sys.description('The identity subnet name that will host the VMs NIC')
param parIdentitySubnetName string = 'identity-subnet1'

@sys.description('The subnet name that will host container instances')
param parContainerSubnetName string = 'container-subnet1'

@sys.description('Define outbound destination ports or ranges for SSH or RDP that you want to access from Azure Bastion.')
param parBastionOutboundSshRdpPorts array = ['22', '3389']

@sys.description('Hub VNet Resource Id to peer with.')
param parHubNetworkResourceId string

@allowed([
  'no-vpngw'
  'vpngw-nobgp'
  'vpngw-bgp'
])
@sys.description('Hub VPN Gateway solution.')
param parHubVpnGateway string = 'no-vpngw'

@allowed([
  'no-identity-domain'
  'create-identity-domain'
  'use-onprem-domain'
])
@sys.description('Active Directory Domain scenario for identity subscription.')
param parActiveDirectoryScenario string = 'create-identity-domain'

@sys.description('Array with DNS Server addresses for identity vnet.')
param parOnpremDns array = []

@sys.description('Onprem KeyVault resource id.')
param parOnpremKvId string

@sys.description('Onprem domain admin name.')
param parOnpremDomainAdminName string = 'azadmin'

@sys.description('Onprem domain admin password.')
param parOnpremDomainAdminPasswordSecretName string

@sys.description('VM admin user name')
@secure()
param parAdminUserName string

@description('Optional. Virtual machine time zone')
param parTimeZone string = 'W. Europe Standard Time'

param parTimeNow string = utcNow('u')

/*** VARIABLES ***/

var varSubnetProperties = [ for (subnet, i) in parSubnets : {
  name: subnet.name
  addressPrefix: subnet.addressPrefix
  networkSecurityGroupResourceId:  '${resourceGroup().id}/providers/Microsoft.Network/networkSecurityGroups/${subnet.networkSecurityGroupName}'
  routeTableResourceId: !empty(subnet.routeTableResourceName) ? '${resourceGroup().id}/providers/Microsoft.Network/routeTables/${subnet.routeTableResourceName}' : ''
  serviceEndpoints: subnet.serviceEndpoints
  delegation: subnet.delegations
}
]


var _dep = deployment().name
var varEnvironment = parTags.?Environment ?? 'canary'
var varDc1Name = 'vm-${parLocationCode}-dc-01'
var varDesUserAssignedIdentityName = 'id-${parLocationCode}-des-${parCompanyPrefix}-${varEnvironment}'
var varDesName = 'des-${parLocationCode}-001-${parCompanyPrefix}-${varEnvironment}'
var varSaContributorUserAssignedIdentityName = 'id-${parLocationCode}-sa-contributor-${parCompanyPrefix}-${varEnvironment}'
var varSaReaderUserAssignedIdentityName = 'id-${parLocationCode}-sa-reader-${parCompanyPrefix}-${varEnvironment}'
var varActiveDirectoryDomainName = 'alz-${varEnvironment}.lokal'

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

var varContainersToCreate = {
  scripts: ['prepareDisks.ps1', 'Deploy-DomainServices.ps1.zip', 'Add-DomainServices.ps1.zip']
}

var varContainersToCreateFormatted = replace(string(varContainersToCreate), '"', '\\"')

var varDscSas1 = resSaDeployArtifacts.listServiceSas(resSaDeployArtifacts.apiVersion, {
  canonicalizedResource: '/blob/${resSaDeployArtifacts.name}/scripts/Deploy-DomainServices.ps1.zip'
  signedResource: 'b'
  signedPermission: 'r'
  signedExpiry: dateTimeAdd(parTimeNow, 'PT1H')
  signedProtocol: 'https'
  keyToSign: 'key1'
}).serviceSasToken

var varDscSas2 = resSaDeployArtifacts.listServiceSas(resSaDeployArtifacts.apiVersion, {
  canonicalizedResource: '/blob/${resSaDeployArtifacts.name}/scripts/Add-DomainServices.ps1.zip'
  signedResource: 'b'
  signedPermission: 'r'
  signedExpiry: dateTimeAdd(parTimeNow, 'PT1H')
  signedProtocol: 'https'
  keyToSign: 'key1'
}).serviceSasToken

var varUseRemoteVpnGateway = (parHubVpnGateway == 'vpngw-nobgp' || parHubVpnGateway == 'vpngw-bgp')  ? true : false

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
  // Delegated container network's subnet 
  resource containerSubnet 'subnets' existing = {
    name: parContainerSubnetName
  }
  // Bastion subnet 
  resource bastionSubnet 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}


/*** NEW RESOURCES ***/

module modDc1 'br/public:avm/res/compute/virtual-machine:0.13.0' = if ((parActiveDirectoryScenario == 'create-identity-domain') || (parActiveDirectoryScenario == 'use-onprem-domain')) {
  name: '${_dep}-Vm1'
  dependsOn: [modKvPassword]
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
       //sku: '2022-datacenter-azure-edition-smalldisk'
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
            privateIPAddress: cidrHost(resIdentityVirtualNetwork::identitySubnet.properties.addressPrefix, 3)
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
    vmSize: 'Standard_B2als_v2'
    zone: 1
    enableAutomaticUpdates: true
    patchMode: 'AutomaticByPlatform'
    bypassPlatformSafetyChecksOnUserSchedule: true
    bootDiagnostics: true
    bootDiagnosticStorageAccountName: modSaBootDiag.outputs.name
    managedIdentities: {
      systemAssigned: true
      userAssignedResourceIds: [
        modIdSaReader.outputs.resourceId
      ]
    }
  }
}

// module modPrepareDisksDc1 '../../modules/Compute/virtual-machine/runcommand/main.bicep' = {
//   name: '${_dep}-prepare-disks-dc1'
//   dependsOn: [
//     modCopyDeployArtifacts2SaScript
//   ]
//   params: {
//     location: parLocation
//     tags: parTags
//     runCommandName: 'PrepareDisks'
//     vmName: modDc1.outputs.name
//     scriptUri: '${modSaDeployArtifacts.outputs.primaryBlobEndpoint}scripts/prepareDisks.ps1'
//   }
// }

resource resSaDeployArtifacts 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  dependsOn: [
    modSaDeployArtifacts
  ]
  name: take(
    ('sa${parLocationCode}deploy${take(uniqueString(resourceGroup().name),4)}${parTags.Environment}${parCompanyPrefix}'),
    24
  )
}


module modDscCreateAd './dsc-dc.bicep' = if (parActiveDirectoryScenario == 'create-identity-domain') {
  name: '${_dep}-dsc-create-ad'
  dependsOn: [modCopyDeployArtifacts2SaScript]
  params: {
    location: parLocation
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: false
    name: 'Microsoft.Powershell.DSC'
    virtualMachineName: modDc1.outputs.name
    settings: {
      configuration: {
        url: '${modSaDeployArtifacts.outputs.primaryBlobEndpoint}scripts/Deploy-DomainServices.ps1.zip'
        script: 'Deploy-DomainServices.ps1'
        function: 'Deploy-DomainServices'
      }
      configurationArguments: {
        domainFQDN: varActiveDirectoryDomainName
        ADDSFilePath: 'E:\\'
        ADDiskId: 1
        DNSForwarder: ['168.63.129.16']
        ForestMode: 'WinThreshold'
      }
    }
    adminPassword: resKv.getSecret('${varDc1Name}-password')
    adminUserName: parAdminUserName
    configurationUrlSasToken: '?${varDscSas1}'
  }
}

module modDscAddAd './dsc-dc.bicep' = if (parActiveDirectoryScenario == 'use-onprem-domain') {
  name: '${_dep}-dsc-add-ad'
  dependsOn: [modCopyDeployArtifacts2SaScript]
  params: {
    location: parLocation
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: false
    name: 'Microsoft.Powershell.DSC'
    virtualMachineName: modDc1.outputs.name
    settings: {
      configuration: {
        url: '${modSaDeployArtifacts.outputs.primaryBlobEndpoint}scripts/Add-DomainServices.ps1.zip'
        script: 'Add-DomainServices.ps1'
        function: 'Add-DomainServices'
      }
      configurationArguments: {
        domainFQDN: varActiveDirectoryDomainName
        ADDSFilePath: 'E:\\'
        ADDiskId: 1
        DNSForwarder: ['168.63.129.16']
      }
    }
    // adminPassword: resKv.getSecret('${varDc1Name}-password')
    // adminUserName: parAdminUserName
    adminPassword: resKvOnprem.getSecret(parOnpremDomainAdminPasswordSecretName)
    adminUserName: parOnpremDomainAdminName
    configurationUrlSasToken: '?${varDscSas2}'
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
      ipRules: [
        for ip in varGwcSerialConsoleIps: {
          action: 'Allow'
          value: ip
        }
      ]
    }
  }
}


module modSaDeployArtifacts 'br/public:avm/res/storage/storage-account:0.19.0' = {
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
      virtualNetworkRules: [
        {
          //id: modIdentityVNet.outputs.subnetResourceIds[1]
          id: modContainerSubnet.outputs.resourceId
          action: 'Allow'
        }
        {
          id: resIdentityVirtualNetwork::identitySubnet.id
          action: 'Allow'
        }
      ]
    }
    blobServices: {
      containerDeleteRetentionPolicyEnabled: true
      deleteRetentionPolicyDays: 7
      containerDeleteRetentionPolicyDays: 7
      deleteRetentionPolicyEnabled: true
      containers: [
        {
          name: 'scripts'
          publicAccess: 'None'
        }
      ]
    }
    roleAssignments: [
      {
        principalId: modIdSaContributor.outputs.principalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }
      {
        principalId: modIdSaContributor.outputs.principalId
        roleDefinitionIdOrName: 'Storage Account Contributor'
      }
      {
        principalId: modIdSaContributor.outputs.principalId
        roleDefinitionIdOrName: 'Storage File Data Privileged Contributor'
      }
      {
        principalId: modIdSaReader.outputs.principalId
        roleDefinitionIdOrName: 'Storage Blob Data Reader'
      }
    ]
  }
}




module modIdSaContributor 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: '${_dep}-${varSaContributorUserAssignedIdentityName}'
  params: {
    name: varSaContributorUserAssignedIdentityName
    location: parLocation
    tags: parTags
  }
}

module modIdSaReader 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: '${_dep}-${varSaReaderUserAssignedIdentityName}'
  params: {
    name: varSaReaderUserAssignedIdentityName
    location: parLocation
    tags: parTags
  }
}



module modContainerSubnetNSG 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: '${_dep}-container-subnet1-nsg'
  params: {
    name: parContainerNsgName
  }
}

module modNsgBastion 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: '${_dep}-bastion-subnet-nsg'
  params: {
    name: parBastionNsgName
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

// module modBastion 'bastion.bicep' = {
//   name: '${_dep}-bastion-${parLocationCode}-identity'
//   params: {
//     parBastionName: 'bastion-${parLocationCode}-identity'
//     parLocation: parLocation
//     parVnetResourceId: modVnet.outputs.resourceId
//     parTags: parTags
//   }
// }

module modBastion 'br/public:avm/res/network/bastion-host:0.6.1' = {
  name: '${_dep}-bastion-${parLocationCode}-identity'
  dependsOn: [
    modBastionSubnet
  ]
  params: {
    name: 'bastion-${parLocationCode}-identity'
    virtualNetworkResourceId: resIdentityVirtualNetwork.id
    location: parLocation
    skuName: 'Developer'
  }
}

module modContainerSubnet '../../../../../bicep-registry-modules/avm/res/network/virtual-network/subnet/main.bicep' = {
  name: '${_dep}-container-subnet1'
  params: {
    name: 'container-subnet1'
    virtualNetworkName: resIdentityVirtualNetwork.name
    addressPrefix: parSubnets[1].addressPrefix
    serviceEndpoints: [
      'Microsoft.Storage'
    ]
    delegation: 'Microsoft.ContainerInstance/containerGroups'
    networkSecurityGroupResourceId: modContainerSubnetNSG.outputs.resourceId
  }
}

module modBastionSubnet '../../../../../bicep-registry-modules/avm/res/network/virtual-network/subnet/main.bicep' = {
  name: '${_dep}-bastion-subnet'
  dependsOn: [
    modContainerSubnet
  ]
  params: {
    name: 'AzureBastionSubnet'
    virtualNetworkName: resIdentityVirtualNetwork.name
    addressPrefix: parSubnets[2].addressPrefix
    networkSecurityGroupResourceId: modNsgBastion.outputs.resourceId
  }
}

module modIdentityVNetSetDNSToCloud 'br/public:avm/res/network/virtual-network:0.5.1' = if (parActiveDirectoryScenario == 'create-identity-domain' ) {
  name: 'deploy-Identity-VNet-SetDNSToCloud'
  dependsOn: [
    modContainerSubnetNSG
    modDscCreateAd
  ]
  params: {
    name: parIdentityNetworkName
    location: parLocation
    tags: parTags
    dnsServers: [cidrHost(resIdentityVirtualNetwork::identitySubnet.properties.addressPrefix, 3)]
    addressPrefixes: [
      parIdentityNetworkAddressPrefix
    ]
    lock: {
      name: parVirtualNetworkLock.kind.?name ?? '${parIdentityNetworkName}-lock'
      kind: (parGlobalResourceLock.kind != 'None') ? parGlobalResourceLock.kind : parVirtualNetworkLock.kind
    }
    subnets: varSubnetProperties
    peerings: [
      {
        remoteVirtualNetworkResourceId: parHubNetworkResourceId
        allowForwardedTraffic: true
        // allowGatewayTransit: varUseRemoteVpnGateway
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: true
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        useRemoteGateways: varUseRemoteVpnGateway
        remotePeeringAllowGatewayTransit: varUseRemoteVpnGateway
      }
    ]
  }
}

module modIdentityVNetSetDNSToOnprem 'br/public:avm/res/network/virtual-network:0.5.1' = if (parActiveDirectoryScenario == 'use-onprem-domain' ) {
  name: 'deploy-Identity-VNet-SetDNSToOnprem'
  dependsOn: [modContainerSubnet]
  params: {
    name: parIdentityNetworkName
    location: parLocation
    tags: parTags
    dnsServers: parOnpremDns
    addressPrefixes: [
      parIdentityNetworkAddressPrefix
    ]
    lock: {
      name: parVirtualNetworkLock.kind.?name ?? '${parIdentityNetworkName}-lock'
      kind: (parGlobalResourceLock.kind != 'None') ? parGlobalResourceLock.kind : parVirtualNetworkLock.kind
    }
    subnets: varSubnetProperties
    peerings: [
      {
        remoteVirtualNetworkResourceId: parHubNetworkResourceId
        allowForwardedTraffic: true
        // allowGatewayTransit: varUseRemoteVpnGateway
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: true
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        useRemoteGateways: varUseRemoteVpnGateway
        remotePeeringAllowGatewayTransit: varUseRemoteVpnGateway
      }
    ]
  }
}

// optional: can be deployed instead of identity network deployment job, don´t remove
// module modIdentityVNet 'br/public:avm/res/network/virtual-network:0.5.1' = {
//   name: 'deploy-Identity-VNet'
//   params: {
//     name: parIdentityNetworkName
//     location: parLocation
//     tags: parTags
//     dnsServers: []
//     addressPrefixes: [
//       parIdentityNetworkAddressPrefix
//     ]
//     lock: {
//       name: parVirtualNetworkLock.kind.?name ?? '${parIdentityNetworkName}-lock'
//       kind: (parGlobalResourceLock.kind != 'None') ? parGlobalResourceLock.kind : parVirtualNetworkLock.kind
//     }
//     subnets: varSubnetProperties
//     peerings: [
//       {
//         remoteVirtualNetworkResourceId: parHubNetworkResourceId
//         allowForwardedTraffic: true
//         allowGatewayTransit: false
//         allowVirtualNetworkAccess: true
//         remotePeeringAllowForwardedTraffic: true
//         remotePeeringAllowVirtualNetworkAccess: true
//         remotePeeringEnabled: true
//       }
//     ]
//   }
// }

module modCopyDeployArtifacts2SaScript 'br/public:avm/res/resources/deployment-script:0.5.0' = {
  name: '${_dep}-copy-deploy-artifacts'
  params: {
    tags: parTags
    location: parLocation
    name: 'copy-deploy-artifacts-to-sa'
    kind: 'AzurePowerShell'
    retentionInterval: 'PT1H'
    azPowerShellVersion: '12.3'
    cleanupPreference: 'Always'
    managedIdentities: {
      userAssignedResourceIds: [
        modIdSaContributor.outputs.resourceId
      ]
    }
    subnetResourceIds: [
      resIdentityVirtualNetwork::containerSubnet.id
    ]
    storageAccountResourceId: modSaDeployArtifacts.outputs.resourceId
    arguments: '-storageAccountName ${modSaDeployArtifacts.outputs.name} -resourceGroupName ${resourceGroup().name} -containersToCreate \'${varContainersToCreateFormatted}\''
    scriptContent: loadTextContent('createBlobStorageContainers.ps1')
  }
}
module modKv '../keyVault/keyVault.bicep' = {
  name: '${_dep}-Kv'
  params: {
    parKeyVaultName: take(
      ('kv-${parLocationCode}-001-${parTags.Environment}-${parCompanyPrefix}-${take(uniqueString(resourceGroup().name),4)}'),
      24
    )
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
  name: take(
    ('kv-${parLocationCode}-001-${parTags.Environment}-${parCompanyPrefix}-${take(uniqueString(resourceGroup().name),4)}'),
    24
  )
}

// KeyVault from onprem subscriptions with domain join credentials (use-onprem-domain)
resource resKvOnprem 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (parActiveDirectoryScenario == 'use-onprem-domain') {
  scope: resourceGroup(split(parOnpremKvId,'/')[2],split(parOnpremKvId,'/')[4])
  name: last(split(parOnpremKvId,'/'))
}


// Key Encryption Key for DES

module modKekDes '../../../../../bicep-registry-modules/avm/res/key-vault/vault/key/main.bicep' = {
  name: '${_dep}-kek-des'
  params: {
    name: 'kek-des'
    keyVaultName: modKv.outputs.name
    tags: parTags
    kty: 'RSA'
  }
}

// Disk Encryption Set 

module modIdDes 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: '${_dep}-${varDesUserAssignedIdentityName}'
  params: {
    name: varDesUserAssignedIdentityName
    location: parLocation
    tags: parTags
  }
}

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
    parExpireDate: dateTimeAdd(parTimeNow, 'P90D')
  }
}


output dc1ResourceId string = ((parActiveDirectoryScenario == 'create-identity-domain') || (parActiveDirectoryScenario == 'use-onprem-domain')) ? modDc1.outputs.resourceId : ''
output kv1ResourceId string = modKv.outputs.resourceId

output containersToCreate object = varContainersToCreate
output containersToCreateFormatted string = varContainersToCreateFormatted
output varDscSas string = varDscSas1
output dscUrl string = '${modSaDeployArtifacts.outputs.primaryBlobEndpoint}scripts/Deploy-DomainServices.ps1.zip?${varDscSas1}'
