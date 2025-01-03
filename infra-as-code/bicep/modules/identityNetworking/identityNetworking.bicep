metadata name = 'ALZ Bicep - Identity Networking Module'
metadata description = 'ALZ Bicep Module used to set up Identity Networking'



type subnetOptionsType = ({
  @description('Name of subnet.')
  name: string

  @description('IP-address range for subnet.')
  addressPrefix: string

  @description('Id of Network Security Group to associate with subnet.')
  networkSecurityGroupResourceId: string?

  @description('Id of Route Table to associate with subnet.')
  routeTableResourceId: string?

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

@sys.description('The Azure Region to deploy the resources into.')
param parLocation string = resourceGroup().location

@sys.description('Prefix value which will be prepended to all resource names.')
param parCompanyPrefix string = 'alz'

@sys.description('Name for Identity Network.')
param parIdentityNetworkName string = 'vnet-${parLocation}-identity-${parCompanyPrefix}'

@sys.description('Name for Network Security Group ')
param parIdentityNsgName string = 'nsg-${parLocation}-001-${parCompanyPrefix}'

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



@sys.description('The name, IP address range, network security group, route table, delegation serviceName and serviceEndpoints for each subnet in the virtual networks.')
param parSubnets subnetOptionsType = [
  {
    name: 'identity-subnet1'
    addressPrefix: '10.20.1.0/24'
    networkSecurityGroupResourceId: ''
    routeTableResourceId: ''
    serviceEndpoints: [
        'Microsoft.Storage'
    ]
    delegations: ''
  }
]

@sys.description('Array of DNS Server IP addresses for VNet.')
param parDnsServerIps array = []

@sys.description('Hub VNet Resource Id to peer with.')
param parHubNetworkResourceId string

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

var varSubnetProperties = [ for (subnet, i) in parSubnets : {
  name: subnet.name
  addressPrefix: subnet.addressPrefix
  networkSecurityGroupResourceId:  '${resourceGroup().id}/providers/Microsoft.Network/networkSecurityGroups/${parIdentityNsgName}'
  routeTableResourceId: subnet.routeTableResourceId
  serviceEndpoints: subnet.serviceEndpoints
}
]

module modIdentityVNetAVM 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: 'deploy-Identity-VNet-AVM'
  params: {
    name: parIdentityNetworkName
    location: parLocation
    tags: parTags
    dnsServers: parDnsServerIps
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
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: true
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
      }
    ]
  }
}

module modNSG1 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'deploy-NSG1'
  params: {
    name: parIdentityNsgName
  }
}

output outIdentityVirtualNetworkName string = modIdentityVNetAVM.outputs.name
output outIdentityVirtualNetworkId string = modIdentityVNetAVM.outputs.resourceId


