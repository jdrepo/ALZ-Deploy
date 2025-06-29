targetScope = 'managementGroup'

var _dep = deployment().name

@sys.description('Required. Existing subscription id.')
param parExistingSubscriptionId string

@sys.description('Optional. Whether to use an existing Platform Landing zones environment')
param parUseExistingPlzEnvironment bool = true

@sys.description('The destination Management Group ID for the new Subscription')
param parSubscriptionManagementGroupId string 

@sys.description('Region where to deploy the resources.')
param parLocation string = 'germanywestcentral'

@sys.description('Region code for resource naming.')
param parLocationCode string = 'gwc'

@sys.description('Hub network resource id.')
param parHubNetworkResourceId string

@sys.description('The name of the Resource Group to create the Virtual Network in')
param parVirtualNetworkResourceGroupName string

@sys.description('The name of the virtual network for workload')
param parVirtualNetworkName string = 'vnet-${parLocationCode}-workload-online-001'

@sys.description('Optional. Whether to enable peering/connection with the supplied hub Virtual Network or Virtual WAN Virtual Hub.')
param parVirtualNetworkPeeringEnabled bool = true

@sys.description('The name of the IP Group that will be created for Bastion hosts in hub network.')
param parIpGroupBastionRangesInHubName string

@sys.description('The custom DNS servers to use on the Virtual Network.')
param parVirtualNetworkDnsServers array = []

@sys.description('Hub network NVA ip address.')
param parHubNetworkNvaIpAddress string?

@sys.description('Optional. The address space of the Virtual Network that will be created')
param parVirtualNetworkAddressSpace array = []

@sys.description('Optional. Enables the use of remote gateways in the specified hub virtual network.')
param parVirtualNetworkUseRemoteGateways bool = false


/*** EXISTING HUB RESOURCES ***/

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = if (parUseExistingPlzEnvironment == true) {
  scope: subscription(split(parHubNetworkResourceId,'/')[2])
  name: split(parHubNetworkResourceId,'/')[4]
}

@description('The regional hub network in the Connectivity subscription.')
resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = if (parUseExistingPlzEnvironment == true) {
  scope: hubResourceGroup
  name: last(split(parHubNetworkResourceId,'/'))

  resource bastionHostSubnet 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}

module modSubVending  'br/public:avm/ptn/lz/sub-vending:0.3.3' = {
  name: '${_dep}-sub-vending-online1'
  params: {
    resourceProviders: {
      'Microsoft.Security': []
    }
    existingSubscriptionId: parExistingSubscriptionId
    subscriptionAliasEnabled: false
    subscriptionManagementGroupAssociationEnabled: true
    subscriptionManagementGroupId: parSubscriptionManagementGroupId
    subscriptionWorkload: 'Production'
    virtualNetworkEnabled: true
    virtualNetworkLocation: parLocation
    virtualNetworkResourceGroupName: parVirtualNetworkResourceGroupName
    virtualNetworkName: parVirtualNetworkName
    virtualNetworkAddressSpace: parVirtualNetworkAddressSpace
    virtualNetworkResourceGroupLockEnabled: false
    virtualNetworkPeeringEnabled: parVirtualNetworkPeeringEnabled
    hubNetworkResourceId: parHubNetworkResourceId
    virtualNetworkDnsServers: !empty(parVirtualNetworkDnsServers) ? parVirtualNetworkDnsServers : null
    virtualNetworkUseRemoteGateways: parVirtualNetworkUseRemoteGateways
  }
}

// module modRgWorkloadOnline1 'br/public:avm/res/resources/resource-group:0.4.1' = {
//   scope: subscription(parExistingSubscriptionId)
//   name: '${_dep}-rg-workload-online1'
//   params: {
//     name: 'rg-workload-online1-001'
//     location: parLocation
//   }
// }

module modIpGroupBastionRangesInHub 'br/public:avm/res/network/ip-group:0.3.0' = if (parUseExistingPlzEnvironment == true) {
  scope: resourceGroup(parExistingSubscriptionId,parVirtualNetworkResourceGroupName)
  name: '${_dep}-ip-group-bastion-ranges-in-hub'
  dependsOn: [
    modSubVending
  ]
  params: {
    location: parLocation
    name: parIpGroupBastionRangesInHubName
    ipAddresses: [
      hubVirtualNetwork::bastionHostSubnet.properties.addressPrefix
    ]
  }
}

module modRouteNextHopToHubFirewall 'br/public:avm/res/network/route-table:0.4.1' = if (parUseExistingPlzEnvironment == true) {
  scope: resourceGroup(parExistingSubscriptionId,parVirtualNetworkResourceGroupName)
  name: '${_dep}-route-next-hop-to-hub-firewall'
  dependsOn: [
    modSubVending
  ]
  params: {
    name: 'route-to-connectivity-${parLocation}-hub-fw'
    disableBgpRoutePropagation: true
    location: parLocation
    routes: [
      {
        name: 'default'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: parHubNetworkNvaIpAddress
        }
      }
    ]
  }
}
