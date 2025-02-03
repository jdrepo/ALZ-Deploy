metadata name = 'ALZ Bicep - Onpremise Module'
metadata description = 'ALZ Bicep Module used to set up Onpremise resources'

targetScope = 'subscription'

@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Region where to deploy the resources.')
param parLocation string = 'germanywestcentral'

@sys.description('Name of resource group.')
param parResourceGroupName string = 'rg-onprem'

@sys.description('Region code for resource naming.')
param parLocationCode string = 'gwc'

var _dep = deployment().name
var varEnvironment = parTags.?Environment ?? 'canary'

module modResourceGroup 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: '${_dep}-onprem-resource-group'
  params: {
    name: parResourceGroupName
    location: parLocation
  }
}

module modNsgUntrustedSubnet 'br/public:avm/res/network/network-security-group:0.5.0' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-nsg-${parLocationCode}-untrusted-subnet'
  params: {
    location: modResourceGroup.outputs.location
    name: 'nsg-${parLocationCode}-untrusted-subnet'
  }
}

module modNsgTrustedSubnet 'br/public:avm/res/network/network-security-group:0.5.0' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-nsg-${parLocationCode}-trusted-subnet'
  params: {
    location: modResourceGroup.outputs.location
    name: 'nsg-${parLocationCode}-trusted-subnet'
  }
}

module modVnet 'br/public:avm/res/network/virtual-network:0.5.2' = {
  scope: resourceGroup(parResourceGroupName)
  name: '${_dep}-vnet-${parLocationCode}-onprem'
  params: {
    location: modResourceGroup.outputs.location
    name: 'vnet-${parLocationCode}-onprem'
    addressPrefixes: [
      '172.22.0.0/16'
    ]
    subnets: [
      {
        addressPrefix: '172.22.0.0/27'
        name: 'untrustedSubnet'
        networkSecurityGroupResourceId: modNsgUntrustedSubnet.outputs.resourceId
      }
      {
        addressPrefix: '172.22.0.32/27'
        name: 'trustedSubnet'
        networkSecurityGroupResourceId: modNsgTrustedSubnet.outputs.resourceId
      }
    ]
  }
}
