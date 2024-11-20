metadata name = 'ALZ Bicep - OpnSense Module'
metadata description = 'ALZ Bicep Module used to set up OpnSense'

targetScope = 'resourceGroup'

/*** USERDEFINED TYPES ***/

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

/*** PARAMETERS ***/

@sys.description('Prefix value which will be prepended to all resource names.')
param parCompanyPrefix string = 'alz'

@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('VM size, please choose a size which allow 2 NICs.')
param parVirtualMachineSize string = 'Standard_B2s'

@sys.description('OPN NVA Manchine Name')
param parVirtualMachineName string

@sys.description('Existing Virtual Network Resource Id.')
param parVirtualNetworkResourceId string

@sys.description('Untrusted-Subnet Address Space.')
param parUntrustedSubnetCIDR string = '10.10.251.0/24'

@sys.description('Trusted-Subnet Address Space.')
param parTrustedSubnetCIDR string = '10.10.250.0/24'

@sys.description('Untrusted-Subnet Name.')
param parUntrustedSubnetName string = 'OPNS-Untrusted'

@sys.description('Trusted-Subnet Name.')
param parTrustedSubnetName string = 'OPNS-Trusted'

@sys.description('Specify Public IP SKU either Basic (lowest cost) or Standard (Required for HA LB)"')
@allowed([
  'Basic'
  'Standard'
])
param PublicIPAddressSku string = 'Standard'

@sys.description('URI for Custom OPN Script and Config')
param OpnScriptURI string = 'https://raw.githubusercontent.com/dmauser/opnazure/master/scripts/'

@sys.description('Shell Script to be executed')
param ShellScriptName string = 'configureopnsense.sh'

@sys.description('OPN Version')
param OpnVersion string = '24.7'

@sys.description('Azure WALinux agent Version')
param WALinuxVersion string = '2.11.1.4'

@sys.description('Region where to deploy the resources.')
param parLocation string = resourceGroup().location

@sys.description('Region code for resource naming.')
param parLocationCode string = 'gwc'

/*** VARIABLES ***/

var _dep = deployment().name
var varEnvironment = parTags.?Environment ?? 'canary'

/*** EXISTING RESOURCES ***/

@sys.description('Existing connectivity virtual network, as deployed by the platform team into landing zone.')
resource resConnectivityVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: last(split(parVirtualNetworkResourceId, '/')) 
}

/*** NEW RESOURCES ***/

module modOpnSenseNsg 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: '${_dep}-opnsense-nsg'
  params: {
    name: 'nsg-${parLocationCode}-opnsense-${parCompanyPrefix}-${varEnvironment}'
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

module modTrustedSubnet '../../../../../bicep-registry-modules/avm/res/network/virtual-network/subnet/main.bicep' = {
  name: '${_dep}-trusted-subnet'
  params: {
    name: parTrustedSubnetName
    virtualNetworkName: resConnectivityVirtualNetwork.name
    addressPrefix: parTrustedSubnetCIDR
    networkSecurityGroupResourceId: modOpnSenseNsg.outputs.resourceId
    
  }
}

module modUntrustedSubnet '../../../../../bicep-registry-modules/avm/res/network/virtual-network/subnet/main.bicep' = {
  name: '${_dep}-untrusted-subnet'
  params: {
    name: parUntrustedSubnetName
    virtualNetworkName: resConnectivityVirtualNetwork.name
    addressPrefix: parUntrustedSubnetCIDR
    networkSecurityGroupResourceId: modOpnSenseNsg.outputs.resourceId
    
  }
}
