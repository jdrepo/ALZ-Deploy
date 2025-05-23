metadata name = 'ALZ Bicep - Hub Networking NVA Module'
metadata description = 'ALZ Bicep Module used to set up NVA components in Hub Networking'


@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Name for NVA Trusted Subnet NSG.')
param parNvaTrustedSubnetNsgName string 

@sys.description('Name for NVA Untrusted Subnet NSG.')
param parNvaUntrustedSubnetNsgName string

@sys.description('Region where to deploy the resources.')
param parLocation string = resourceGroup().location

var _dep = deployment().name

module modNsgNvaTrustedSubnet 'br/public:avm/res/network/network-security-group:0.5.1' =  {
  name: '${_dep}-nsg-nva-trusted-subnet'
  params: {
    name: parNvaTrustedSubnetNsgName
    tags: parTags
    location: parLocation
    securityRules: [
      {
        name: 'In-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Out-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

module modNsgNvaUntrustedSubnet 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${_dep}-nsg-nva-untrusted-subnet'
  params: {
    name: parNvaUntrustedSubnetNsgName
    tags: parTags
    securityRules: [
      {
        name: 'In-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Out-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
