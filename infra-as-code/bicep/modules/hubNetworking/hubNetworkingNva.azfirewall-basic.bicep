metadata name = 'ALZ Bicep - Hub Networking Azure Firewall Module'
metadata description = 'ALZ Bicep Module used to set up Azure Firewall components in Hub Networking'


@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Region where to deploy the resources.')
param parLocation string = resourceGroup().location

@sys.description('Prefix value which will be prepended to all resource names.')
param parCompanyPrefix string = 'alz'

@sys.description('Azure Firewall Policies Name.')
param parAzFirewallPoliciesName string = '${parCompanyPrefix}-azfwpolicy-${parLocation}'

@sys.description('Azure Firewall Tier associated with the Firewall Policy to deploy.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param parAzFirewallPolicyTier string = 'Basic'

var _dep = deployment().name

module modFirewallPolicy 'br/public:avm/res/network/firewall-policy:0.2.0' = {
  name: '${_dep}-firewall-policy'
  params: {
    name: parAzFirewallPoliciesName
    location: parLocation
    tier: parAzFirewallPolicyTier
    ruleCollectionGroups: [
      {
        name: 'Platform-Identity'
        priority: 1000
        ruleCollections: [
          {
            action: {
              type: 'Dnat'
            }
            name: 'Platform-Identity-DNAT'
            priority: 100
            ruleCollectionType: 'FirewallPolicyNatRuleCollection'           
            rules: []
          }
          {
            action: {
              type: 'Allow'
            }
            name: 'Platform-Identity-Network-Allow'
            priority: 200
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            rules: [
              {
                name: 'Allow-HTTPS'
                description: ''
                ruleType: 'NetworkRule'
                destinationAddresses: [
                  '*'
                ]
                destinationFqdns: []
                destinationIpGroups: []
                destinationPorts: [
                  '443'
                ]
                ipProtocols: [
                  'TCP'
                ]
                sourceAddresses: [
                  '10.20.1.0/24'
                ]
                sourceIpGroups: []
              }
            ]
          }
          {
            action: {
              type: 'Deny'
            }
            name: 'Platform-Identity-Network-Deny'
            priority: 250
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            rules: []
          }
          {
            action: {
              type: 'Allow'
            }
            name: 'Platform-Identity-Application-Allow'
            priority: 300
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            rules: [
              {
                name: 'Allow-HTTP-HTTPS'
                description: ''
                ruleType: 'ApplicationRule'
                destinationAddresses: []
                fqdnTags: []
                httpHeadersToInsert: []
                protocols: [
                  {
                    port: 80
                    protocolType: 'http'
                  }
                  {
                    port: 443
                    protocolType: 'https'
                  }
                ]
                sourceAddresses: [
                  '10.20.1.0/24'
                ]
                sourceIpGroups: []
                targetFqdns: [
                  '*'
                ]
                targetUrls: []
                terminateTLS: false
                webCategories: []
              }
            ]
          }
          {
            action: {
              type: 'Deny'
            }
            name: 'Platform-Identity-Application-Deny'
            priority: 350
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            rules: []
          }
        ]
      }
    ]
  }
}
