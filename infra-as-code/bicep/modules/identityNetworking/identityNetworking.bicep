metadata name = 'ALZ Bicep - Identity Networking Module'
metadata description = 'ALZ Bicep Module used to set up Identity Networking'

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

type subnetOptionsType2 = ({
  @description('Name of subnet.')
  name: string

  @description('IP-address range for subnet.')
  addressPrefix: string

  @description('Id of Network Security Group to associate with subnet.')
  networkSecurityGroupResourceId: string?

  @description('Id of Route Table to associate with subnet.')
  routeTableResourceId: string?

  @description('Name of the delegation to create for the subnet.')
  delegation: string?
})[]

type lockType = {
  @description('Optional. Specify the name of lock.')
  name: string?

  @description('Optional. The lock settings of the service.')
  kind: ('CanNotDelete' | 'ReadOnly' | 'None')

  @description('Optional. Notes about this lock.')
  notes: string?
}

@sys.description('The Azure Region to deploy the resources into.')
param parLocation string = resourceGroup().location

@sys.description('Prefix value which will be prepended to all resource names.')
param parCompanyPrefix string = 'alz'

@sys.description('Name for Identity Network.')
param parIdentityNetworkName string = 'vnet-${parLocation}-identity-${parCompanyPrefix}'

@sys.description('Name for Network Security Group 1')
param parIdentityNsg1Name string = 'nsg-${parLocation}-001-${parCompanyPrefix}'

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


@sys.description('The IP address range for Identity Network.')
param parIdentityNetworkAddressPrefix string = '10.20.0.0/16'

@sys.description('The name, IP address range, network security group, route table and delegation serviceName for each subnet in the virtual networks.')
param parSubnets subnetOptionsType = [
  {
    name: 'subnet1'
    ipAddressRange: '10.20.1.0/24'
    networkSecurityGroupId: ''
    routeTableId: ''
  }
]

@sys.description('The name, IP address range, network security group, route table and delegation serviceName for each subnet in the virtual networks.')
param parSubnets2 array = [
  {
    name: 'subnet1'
    addressPrefix: '10.20.1.0/24'
    networkSecurityGroupResourceId: '${resourceGroup().id}/providers/Microsoft.Network/networkSecurityGroups/${parIdentityNsg1Name}'
    routeTableResourceId: ''
  }
]

@sys.description('Array of DNS Server IP addresses for VNet.')
param parDnsServerIps array = []

@sys.description('Array of VNet to peer.')
param parPeeredVnetResourceIds array = []

@sys.description('''Resource Lock Configuration for Virtual Network.

- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.

''')
param parVirtualNetworkLock lockType = {
  kind: 'None'
  notes: 'This lock was created by the ALZ Bicep Identity Networking Module.'
}

@sys.description('Name of Route table to create for the default route of Identity Network.')
param parIdentityRouteTableName string = '${parCompanyPrefix}-identity-routetable'

@sys.description('''Resource Lock Configuration for the Identity Route Table.

- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.

''')
param parIdentityRouteTableLock lockType = {
  kind: 'None'
  notes: 'This lock was created by the ALZ Bicep Identity Networking Module.'
}

// @sys.description('Optional. Network security group rules for Identity Network subnets.')
// param parNsg 

var varSubnetMap = map(range(0, length(parSubnets)), i => {
    name: parSubnets[i].name
    ipAddressRange: parSubnets[i].ipAddressRange
    networkSecurityGroupId: parSubnets[i].?networkSecurityGroupId ?? ''
    routeTableId: parSubnets[i].?routeTableId ?? ''
    delegation: parSubnets[i].?delegation ?? ''
  })

  // var varSubnetMap2 = map(range(0, length(parSubnets2)), i => {
  //   name: parSubnets2[i].name
  //   addressPrefix: parSubnets2[i].addressPrefix
  //   networkSecurityGroupResourceId: parSubnets2[i].?networkSecurityGroupResourceId ?? ''
  //   routeTableResourceId: parSubnets2[i].?routeTableResourceId ?? ''
  //   delegation: parSubnets2[i].?delegation ?? ''
  // })

  
var varSubnetProperties = [for subnet in varSubnetMap: {
  name: subnet.name
  properties: {
    addressPrefix: subnet.ipAddressRange

    delegations: (empty(subnet.delegation)) ? null : [
      {
        name: subnet.delegation
        properties: {
          serviceName: subnet.delegation
        }
      }
    ]

    networkSecurityGroup:  {
      id: '${resourceGroup().id}/providers/Microsoft.Network/networkSecurityGroups/${parIdentityNsg1Name}'
    }

    routeTable: (empty(subnet.routeTableId)) ? null : {
      id: subnet.routeTableId
    }
  }
}]

// var varSubnetProperties2 = [for subnet in varSubnetMap2: {
//   name: subnet.name
//   addressPrefix: subnet.addressPrefix
//   delegation: (empty(subnet.delegation)) ? null : subnet.delegation
//   networkSecurityGroupResourceId:  '${resourceGroup().id}/providers/Microsoft.Network/networkSecurityGroups/${parIdentityNsg1Name}'
//   routeTableResourceId: subnet.routeTableResourceId
//   }]


resource resIdentityVnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  dependsOn: [modNSG1]
  name: parIdentityNetworkName
  location: parLocation
  tags: parTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        parIdentityNetworkAddressPrefix
      ]
    }
    dhcpOptions: {
      dnsServers: parDnsServerIps
    }
    subnets: varSubnetProperties
  }
}

// module modIdentityVNetAVM 'br/public:avm/res/network/virtual-network:0.5.1' = {
//   name: 'deploy-Identity-VNet-AVM'
//   dependsOn: [modNSG1]
//   params: {
//     name: parIdentityNetworkName
//     location: parLocation
//     tags: parTags
//     dnsServers: parDnsServerIps
//     addressPrefixes: [
//       parIdentityNetworkAddressPrefix
//     ]
//     subnets: parSubnets2
//     lock: {
//       name: parVirtualNetworkLock.kind.?name ?? '${parIdentityNetworkName}-lock'
//       kind: (parGlobalResourceLock.kind != 'None') ? parGlobalResourceLock.kind : parVirtualNetworkLock.kind
//     }
//   }
// }

module modNSG1 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'deploy-NSG1'
  params: {
    name: parIdentityNsg1Name
  }
}

resource resNsg1 'Microsoft.Network/networkSecurityGroups@2024-01-01' existing = {
  name: parIdentityNsg1Name
}

// Create a virtual network resource lock if parGlobalResourceLock.kind != 'None' or if parVirtualNetworkLock.kind != 'None'
resource resVirtualNetworkLock 'Microsoft.Authorization/locks@2020-05-01' = if (parVirtualNetworkLock.kind != 'None' || parGlobalResourceLock.kind != 'None') {
  scope: resIdentityVnet
  name: parVirtualNetworkLock.?name ?? '${resIdentityVnet.name}-lock'
  properties: {
    level: (parGlobalResourceLock.kind != 'None') ? parGlobalResourceLock.kind : parVirtualNetworkLock.kind
    notes: (parGlobalResourceLock.kind != 'None') ? parGlobalResourceLock.?notes : parVirtualNetworkLock.?notes
  }
}



output outIdentityVirtualNetworkName string = resIdentityVnet.name
output outIdentityVirtualNetworkId string = resIdentityVnet.id


// output outIdentityVirtualNetworkName2 string = modIdentityVNetAVM.outputs.name
// output outIdentityVirtualNetworkId2 string = modIdentityVNetAVM.outputs.resourceId
