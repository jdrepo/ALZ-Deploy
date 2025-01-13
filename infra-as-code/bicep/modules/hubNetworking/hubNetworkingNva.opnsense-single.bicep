metadata name = 'ALZ Bicep - Hub Networking NVA Module'
metadata description = 'ALZ Bicep Module used to set up NVA components in Hub Networking'


@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Name for OPNSense Trusted Subnet NSG.')
param parOpnSenseTrustedSubnetNsgName string 

@sys.description('Name for OPNSense Untrusted Subnet NSG.')
param parOpnSenseUntrustedSubnetNsgName string

@sys.description('Region where to deploy the resources.')
param parLocation string = resourceGroup().location

var _dep = deployment().name

module modNsgOpnsTrustedSubnet 'br/public:avm/res/network/network-security-group:0.5.0' =  {
  name: '${_dep}-nsg-OPNS-Trusted-Subnet'
  params: {
    name: parOpnSenseTrustedSubnetNsgName
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

module modNsgOpnsUntrustedSubnet 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: '${_dep}-nsg-OPNS-Untrusted-Subnet'
  params: {
    name: parOpnSenseUntrustedSubnetNsgName
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
