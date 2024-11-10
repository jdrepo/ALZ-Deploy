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


var varSubnetMap = map(range(0, length(parSubnets)), i => {
    name: parSubnets[i].name
    ipAddressRange: parSubnets[i].ipAddressRange
    networkSecurityGroupId: parSubnets[i].?networkSecurityGroupId ?? ''
    routeTableId: parSubnets[i].?routeTableId ?? ''
    delegation: parSubnets[i].?delegation ?? ''
  })

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

    networkSecurityGroup: (empty(subnet.networkSecurityGroupId)) ? null : {
      id: subnet.networkSecurityGroupId
    }

    routeTable: (empty(subnet.routeTableId)) ? null : {
      id: subnet.routeTableId
    }
  }
}]


resource resIdentityVnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  dependsOn: []
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
//   params: {
//     name: parIdentityNetworkName
//     location: parLocation
//     tags: parTags
//     dnsServers: parDnsServerIps
//     addressPrefixes: [
//       parIdentityNetworkAddressPrefix
//     ]
//     subnets: [
//       parSubnets
//     ]
//   }
// }

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
