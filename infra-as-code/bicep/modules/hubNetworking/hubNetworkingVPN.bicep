metadata name = 'ALZ Bicep - Hub Networking VPN Module'
metadata description = 'ALZ Bicep Module used to set up VPN connection to onpremise in Hub Networking'

@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Region where to deploy the resources.')
param parLocation string = resourceGroup().location

@sys.description('Region code for resource naming.')
param parLocationCode string

@sys.description('Prefix value which will be prepended to all resource names.')
param parCompanyPrefix string = 'alz'

@sys.description('Array with onpremise address space (no BGP).')
param parOnpremAddressSpace array

@sys.description('BGP peer IP address.')
param parOnpremBgpPeerAddress string

@sys.description('Enable BGP.')
param parEnableBgp bool = false

@sys.description('Onprem BGP ASN')
param parOnpremAsn string = '65000'

@sys.description('DNS name of onpremise VPN Gateway')
param parOnpremVPNGatewayDNS string

@sys.description('IP address of onpremise VPN Gateway')
param parOnpremVPNGatewayIP string = ''

@sys.description('IP address of onpremise VPN Gateway')
param parVPNGatewayResourceId string

var _dep = deployment().name

module modLocalNetworkGw 'br/public:avm/res/network/local-network-gateway:0.3.0' = {
  name: '${_dep}-lngw-${parLocationCode}-onprem'
  params: {
    name: 'lngw-${parLocationCode}-onprem'
    localAddressPrefixes: !empty(parOnpremBgpPeerAddress) ? ['${parOnpremBgpPeerAddress}/32'] : parOnpremAddressSpace
    fqdn: parOnpremVPNGatewayDNS
    localGatewayPublicIpAddress: empty(parOnpremVPNGatewayDNS) ? parOnpremVPNGatewayIP : ''
    localAsn: parEnableBgp ? parOnpremAsn : ''
    localBgpPeeringAddress: parOnpremBgpPeerAddress
  }
}

module modVpnConnection 'br/public:avm/res/network/connection:0.1.3' = {
  name: '${_dep}-conn-${parLocationCode}-onprem'
  params: {
    name: 'conn-${parLocationCode}-onprem'
    virtualNetworkGateway1: { 
      id: parVPNGatewayResourceId 
    }
    localNetworkGateway2: {
      id: modLocalNetworkGw.outputs.resourceId
    } 
    vpnSharedKey: 'A1b2c3d4'
    enableBgp: parEnableBgp
  }
}
