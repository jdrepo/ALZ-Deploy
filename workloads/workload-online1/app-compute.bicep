metadata name = 'ALZ Iaas Landing Zone Baseline '
metadata description = 'Deploy the compute infrastructure'

targetScope = 'resourceGroup'

extension microsoftGraphV1

import { funcGetResourceInformation } from 'functions/funcs-udts.bicep'

@sys.description('The Azure Region to deploy the resources into.')
param parLocation string = resourceGroup().location

@sys.description('Deployment environment.')
param parEnvironment string = 'canary'

@sys.description('Required. The virtual network resource id to deploy resources into.')
param parVnetResourceId string

@sys.description('Required. Bastion Host Ip Group Resource Id in spoke resource group.')
param parBastionHostIpGroupResourceId string

@sys.description('Required. Route table Resource Id for egress traffic to internet in spoke resource group.')
param parRouteTableNextHopToFirewallResourceId string

@sys.description('Required. Key Vault Resource Id with certificates.')
param parKeyVaultResourceId string

@description('Optional. KeyVault Secret Identifier for certificate')
#disable-next-line secure-secrets-in-params // Only returning the references, not any secret value
param parKeyVaultSecretId string?

@description('The Entra ID group/user object id (guid) that will be assigned as the admin users for all deployed virtual machines.')
@minLength(36)
param parAdminSecurityPrincipalObjectId string

var _dep = deployment().name

// Object containing a mapping for location / region code
var varLocationCodes = {
  germanywestcentral: 'gwc'
  westeurope: 'weu'
}

var varLocationCode = varLocationCodes[parLocation]
var varVirtualNetwork = funcGetResourceInformation(parVnetResourceId)
var varBastionHostIpGroup = funcGetResourceInformation(parBastionHostIpGroupResourceId)
var varRouteTableNextHopToFirewall = funcGetResourceInformation(parRouteTableNextHopToFirewallResourceId)
var varKeyVault = funcGetResourceInformation(parKeyVaultResourceId)
var varLogWorkSpaceName = 'log-${varLocationCode}-compute-${parEnvironment}'
var varAgwName = 'agw-${varLocationCode}-frontend-${parEnvironment}'
var varIlbName = 'ilb-${parLocation}-backend-${parEnvironment}'
var varIlbPrivateIp = '10.240.4.4'

// RBAC Role Definitions Variables - Used For Policy Assignments
var varRbacRoleDefinitionIds = {
  owner: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  networkContributor: '4d97b98b-1d4f-4787-a291-c67834d212e7'
  aksContributor: 'ed7f3fbd-7b88-4dd4-9017-9adb7ce333f8'
  logAnalyticsContributor: '/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
  sqlSecurityManager: '056cd41c-7e88-42e1-933e-88ba6a50c9c3'
  vmContributor: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
  monitoringContributor: '/providers/Microsoft.Authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa'
  aksPolicyAddon: '18ed5180-3e48-46fd-8541-4ea054d57064'
  sqlDbContributor: '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec'
  backupContributor: '5e467623-bb1f-42f4-a55d-6e525e11384b'
  rbacSecurityAdmin: 'fb1c8493-542b-48eb-b624-b4c8fea62acd'
  reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  managedIdentityOperator: 'f1a07417-d97a-45cb-824c-7a7467783830'
  connectedMachineResourceAdministrator: 'cd570a14-e51a-42ad-bac8-bafd67325302'
  vmAdminLogin: '/providers/Microsoft.Authorization/roleDefinitions/1c0163c0-47e6-4577-8991-ea5c82e286e4'
  keyVaultSecretsUser: '/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6'
  keyVaultReader: '/providers/Microsoft.Authorization/roleDefinitions/21090545-7ca7-4776-b22c-e363652d74d2'
}

var varPolicyAssignmentLogsDeployDcrWindowsVm = {
  definitionId: '/providers/Microsoft.Authorization/policyDefinitions/eab1f514-22e3-42e3-9a1f-e1dc9199355c'
  libDefinition: loadJsonContent('modules/policy/assignments/lib/policy_assignment_app_deploy_logs_dcr_windows_vm.tmpl.json')
}

var varDefaultAdminUserName = 'azadmin'
//var varDefaultAdminUserName = uniqueString('vmss', resourceGroup().id)

@description('Spoke network provided by the platform team. We\'ll be adding our workload\'s subnets to this. Platform team owns this resource.')
resource resVnet1 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  scope: resourceGroup(varVirtualNetwork.subscriptionId, varVirtualNetwork.resourceGroupName)
  name: varVirtualNetwork.resourceName
}

@description('IP Group created by the platform team to help us keep track of what bastion hosts are expected to be used when connecting to our virtual machines.')
resource resBbastionHostIpGroup 'Microsoft.Network/ipGroups@2024-07-01' existing = {
  scope: resourceGroup(varBastionHostIpGroup.subscriptionId, varBastionHostIpGroup.resourceGroupName)
  name: varBastionHostIpGroup.resourceName
}

@description('IP Group created by the platform team to help us keep track of what bastion hosts are expected to be used when connecting to our virtual machines.')
resource resKv1 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  scope: resourceGroup(varKeyVault.resourceGroupName)
  name: varKeyVault.resourceName
}

// resource resAdminGroup 'Microsoft.Graph/groups@v1.0' existing = {
//   uniqueName: 'compute-admins-workload-online-001-canary'
// }

module modLogWorkSpace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
  name: '${_dep}-log-workspace'
  scope: resourceGroup()
  params: {
    name: varLogWorkSpaceName
    location: parLocation
    dataRetention: 30
    tables: [
      {
        name: 'WindowsLogsTable_CL'
        schema: {
          name: 'WindowsLogsTable_CL'
          columns: [
            {
              name: 'TimeGenerated'
              type: 'dateTime'
            }
            {
              name: 'RawData'
              type: 'string'
            }
          ]
        }
      }
    ]
  }
}

module modWindowsVmLogsDataCollectionEndpoints 'br/public:avm/res/insights/data-collection-endpoint:0.5.0' = {
  name: '${_dep}-dce-windows-logs'
  scope: resourceGroup()
  params: {
    name: 'dce-${varLocationCode}-windows-logs'
    kind: 'Windows'
    publicNetworkAccess: 'Enabled'
  }
}

module modWindowsVmLogsCustomDataCollectionRule 'br/public:avm/res/insights/data-collection-rule:0.6.1' = {
  name: '${_dep}-dcr-windows-logs'
  scope: resourceGroup()
  params: {
    name: 'dcr-${varLocationCode}-windows-logs'
    dataCollectionRuleProperties: {
      kind: 'Windows'
      dataCollectionEndpointResourceId: modWindowsVmLogsDataCollectionEndpoints.outputs.resourceId
      streamDeclarations: {
        'Custom-WindowsLogsTable_CL': {
          columns: [
            {
              name: 'TimeGenerated'
              type: 'datetime'
            }
            {
              name: 'RawData'
              type: 'string'
            }
          ]
        }
      }
      dataSources: {
        logFiles: [
          {
            streams: [
              'Custom-WindowsLogsTable_CL'
            ]
            filePatterns: [
              'W:\\nginx\\data\\*.log'
            ]
            format: 'text'
            settings: {
              text: {
                recordStartTimestampFormat: 'yyyy-MM-ddTHH:mm:ssK'
              }
            }
            name: 'Custom-WindowsLogsTable_CL'
          }
        ]
      }
      dataFlows: [
        {
          streams: [
            'Custom-WindowsLogsTable_CL'
          ]
          destinations: [
            modLogWorkSpace.outputs.name
          ]
          transformKql: 'source | extend TimeGenerated = now()'
          outputStream: 'Custom-WindowsLogsTable_CL'
        }
      ]
      destinations: {
        logAnalytics: [
          {
            name: modLogWorkSpace.outputs.name
            workspaceResourceId: modLogWorkSpace.outputs.resourceId
          }
        ]
      }
      description: 'Default data collection rule for Windows virtual machine logs.'
    }
  }
}

module modPolicyAssignmentDeployLogsDcrWindowsVm '../../../bicep-registry-modules/avm/ptn/authorization/policy-assignment/modules/resource-group.bicep' = {
  name: '${_dep}-polAssi-DeployLogsDcrWindowsVm'
  params: {
    policyDefinitionId: varPolicyAssignmentLogsDeployDcrWindowsVm.definitionId
    name: varPolicyAssignmentLogsDeployDcrWindowsVm.libDefinition.name
    displayName: varPolicyAssignmentLogsDeployDcrWindowsVm.libDefinition.properties.displayName
    description: varPolicyAssignmentLogsDeployDcrWindowsVm.libDefinition.properties.description
    parameters: {
      effect: {
        value: 'DeployIfNotExists'
      }
      dcrResourceId: {
        value: modWindowsVmLogsCustomDataCollectionRule.outputs.resourceId
      }
      resourceType: {
        value: '${split(modWindowsVmLogsCustomDataCollectionRule.outputs.resourceId,'/')[6]}/${split(modWindowsVmLogsCustomDataCollectionRule.outputs.resourceId,'/')[7]}'
      }
    }
    roleDefinitionIds: [
      varRbacRoleDefinitionIds.logAnalyticsContributor
      varRbacRoleDefinitionIds.monitoringContributor
    ]
  }
}

module modAsgVmssFrontend 'br/public:avm/res/network/application-security-group:0.2.1' = {
  name: '${_dep}-asg-frontend'
  scope: resourceGroup()
  params: {
    name: 'asg-${varLocationCode}-frontend'
  }
}

module modAsgVmssBackend 'br/public:avm/res/network/application-security-group:0.2.1' = {
  name: '${_dep}-asg-backend'
  scope: resourceGroup()
  params: {
    name: 'asg-${varLocationCode}-backend'
  }
}

module modAsgKeyVault 'br/public:avm/res/network/application-security-group:0.2.1' = {
  name: '${_dep}-asg-keyvault'
  scope: resourceGroup()
  params: {
    name: 'asg-${varLocationCode}-keyvault'
  }
}

module modNsgVmssBackendSubnet 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${_dep}-nsg-backend'
  scope: resourceGroup()
  params: {
    name: 'nsg-${varLocationCode}-backend'
    securityRules: [
      {
        name: 'AllowIlbToToBackenddApplicationSecurityGroupHTTPSInbound'
        properties: {
          description: 'Allow frontend ASG traffic into 443.'
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceApplicationSecurityGroupResourceIds: [
            modAsgVmssFrontend.outputs.resourceId
          ]
          destinationApplicationSecurityGroupResourceIds: [
            modAsgVmssBackend.outputs.resourceId
          ]
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Allow Azure Health Probes in.'
          access: 'Allow'
          direction: 'Inbound'
          priority: 110
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowBastionSubnetSshInbound'
        properties: {
          description: 'Allow Azure Azure Bastion in.'
          access: 'Allow'
          direction: 'Inbound'
          priority: 120
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          destinationApplicationSecurityGroupResourceIds: [
            modAsgVmssBackend.outputs.resourceId
          ]
          sourceAddressPrefixes: resBbastionHostIpGroup.properties.ipAddresses
        }
      }
      {
        name: 'AllowBastionSubnetRdpInbound'
        properties: {
          description: 'Allow Azure Azure Bastion in.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefixes: resBbastionHostIpGroup.properties.ipAddresses
          destinationPortRange: '3389'
          destinationApplicationSecurityGroupResourceIds: [
            modAsgVmssBackend.outputs.resourceId
          ]
          direction: 'Inbound'
          access: 'Allow'
          priority: 121
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          access: 'Deny'
          direction: 'Inbound'
          priority: 1000
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          description: 'Allow all outbound.'
          access: 'Allow'
          direction: 'Outbound'
          priority: 1000
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'
        }
      }
    ]
  }
}

module modNsgFrontEndSubnet 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${_dep}-nsg-frontend'
  scope: resourceGroup()
  params: {
    name: 'nsg-${varLocationCode}-frontend'
    securityRules: [
      {
        name: 'AllowAppGwToToFrontendInbound'
        properties: {
          description: 'Allow AppGw traffic inbound.'
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '10.240.5.0/24'
          destinationPortRanges: [
            '443'
          ]
          destinationApplicationSecurityGroupResourceIds: [
            modAsgVmssFrontend.outputs.resourceId
          ]
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Allow Azure Health Probes in.'
          access: 'Allow'
          direction: 'Inbound'
          priority: 110
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowBastionSubnetSshInbound'
        properties: {
          description: 'Allow Azure Azure Bastion in.'
          access: 'Allow'
          direction: 'Inbound'
          priority: 120
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          destinationApplicationSecurityGroupResourceIds: [
            modAsgVmssBackend.outputs.resourceId
          ]
          sourceAddressPrefixes: resBbastionHostIpGroup.properties.ipAddresses
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          access: 'Deny'
          direction: 'Inbound'
          priority: 1000
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          description: 'Allow all outbound.'
          access: 'Allow'
          direction: 'Outbound'
          priority: 1000
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'
        }
      }
    ]
  }
}

module modNsgInternalLoadBalancerSubnet 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${_dep}-nsg-ilbs'
  scope: resourceGroup()
  params: {
    name: 'nsg-${varLocationCode}-ilbs'
    securityRules: [
      {
        name: 'AllowFrontendApplicationSecurityGroupHTTPSInbound'
        properties: {
          description: 'Allow Frontend ASG web traffic into 443.'
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: varIlbPrivateIp
          destinationPortRanges: [
            '443'
          ]
          destinationApplicationSecurityGroupResourceIds: [
            modAsgVmssFrontend.outputs.resourceId
          ]
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Allow Azure Health Probes in.'
          access: 'Allow'
          direction: 'Inbound'
          priority: 110
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          access: 'Deny'
          direction: 'Inbound'
          priority: 1000
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          description: 'Allow all outbound.'
          access: 'Allow'
          direction: 'Outbound'
          priority: 1000
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'
        }
      }
    ]
  }
}

module modNsgAppGwSubnet 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${_dep}-nsg-appgw'
  scope: resourceGroup()
  params: {
    name: 'nsg-${varLocationCode}-appgw'
    securityRules: [
      {
        name: 'Allow443Inbound'
        properties: {
          description: 'Allow ALL web traffic into 443. (If you wanted to allow-list specific IPs, this is where you\'d list them.).'
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRanges: [
            '443'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowControlPlaneInbound'
        properties: {
          description: 'Allow Azure Control Plane in. (https://learn.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)'
          access: 'Allow'
          direction: 'Inbound'
          priority: 110
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Allow Azure Health Probes in.'
          access: 'Allow'
          direction: 'Inbound'
          priority: 120
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          access: 'Deny'
          direction: 'Inbound'
          priority: 1000
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          description: 'Allow all outbound.'
          access: 'Allow'
          direction: 'Outbound'
          priority: 1000
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'
        }
      }
    ]
  }
}

module modNsgPrivateLinkEndpointsSubnet 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${_dep}-nsg-privatelinkendpoints'
  scope: resourceGroup()
  params: {
    name: 'nsg-${varLocationCode}-privatelinkendpoints'
    securityRules: [
      {
        name: 'Allow443ToKeyVaultFromVnet'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '443'
          ]
          destinationApplicationSecurityGroupResourceIds: [
            modAsgKeyVault.outputs.resourceId
          ]
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          access: 'Deny'
          direction: 'Inbound'
          priority: 1000
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllOutbound'
        properties: {
          access: 'Deny'
          direction: 'Outbound'
          priority: 1000
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'
        }
      }
    ]
  }
}

module modNsgBuildAgentSubnet 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${_dep}-nsg-deploymentagents'
  scope: resourceGroup()
  params: {
    name: 'nsg-${varLocationCode}-deploymentagents'
    securityRules: [
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          access: 'Deny'
          direction: 'Inbound'
          priority: 1000
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllOutbound'
        properties: {
          access: 'Deny'
          direction: 'Outbound'
          priority: 1000
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'
        }
      }
    ]
  }
}

@description('The subnet that contains our front end compute. UDR applied for egress traffic. NSG applied as well.')
module modFrontendSubnet 'br/public:avm/res/network/virtual-network/subnet:0.1.2' = {
  name: '${_dep}-subnet-frontend'
  scope: resourceGroup(varVirtualNetwork.subscriptionId, varVirtualNetwork.resourceGroupName)
  params: {
    virtualNetworkName: resVnet1.name
    name: 'snet-frontend'
    addressPrefix: '10.240.0.0/24'
    routeTableResourceId: parRouteTableNextHopToFirewallResourceId
    networkSecurityGroupResourceId: modNsgFrontEndSubnet.outputs.resourceId
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    serviceEndpointPolicies: []
    serviceEndpoints: []
  }
}

@description('The subnet that contains our back end compute. UDR applied for egress traffic. NSG applied as well.')
module modBackendSubnet 'br/public:avm/res/network/virtual-network/subnet:0.1.2' = {
  name: '${_dep}-subnet-backend'
  scope: resourceGroup(varVirtualNetwork.subscriptionId, varVirtualNetwork.resourceGroupName)
  dependsOn: [modFrontendSubnet]
  params: {
    virtualNetworkName: resVnet1.name
    name: 'snet-backend'
    addressPrefix: '10.240.1.0/24'
    routeTableResourceId: parRouteTableNextHopToFirewallResourceId
    networkSecurityGroupResourceId: modNsgVmssBackendSubnet.outputs.resourceId
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    serviceEndpointPolicies: []
    serviceEndpoints: []
  }
}

@description('The subnet that contains a load balancer to communicate from front end to back end. UDR applied for egress traffic. NSG applied as well.')
module modInternalLoadBalancerSubnet 'br/public:avm/res/network/virtual-network/subnet:0.1.2' = {
  name: '${_dep}-subnet-ilbs'
  scope: resourceGroup(varVirtualNetwork.subscriptionId, varVirtualNetwork.resourceGroupName)
  dependsOn: [modBackendSubnet]
  params: {
    virtualNetworkName: resVnet1.name
    name: 'snet-ilbs'
    addressPrefix: '10.240.4.0/28'
    routeTableResourceId: parRouteTableNextHopToFirewallResourceId
    networkSecurityGroupResourceId: modNsgInternalLoadBalancerSubnet.outputs.resourceId
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    serviceEndpointPolicies: []
    serviceEndpoints: []
  }
}

@description('The subnet that contains private endpoints for PaaS services used in this architecture. UDR applied for egress traffic. NSG applied as well.')
module modPrivateEndpointsSubnet 'br/public:avm/res/network/virtual-network/subnet:0.1.2' = {
  name: '${_dep}-subnet-privatelinkendpoints'
  scope: resourceGroup(varVirtualNetwork.subscriptionId, varVirtualNetwork.resourceGroupName)
  dependsOn: [modInternalLoadBalancerSubnet]
  params: {
    virtualNetworkName: resVnet1.name
    name: 'snet-privatelinkendpoints'
    addressPrefix: '10.240.4.32/28'
    routeTableResourceId: parRouteTableNextHopToFirewallResourceId
    networkSecurityGroupResourceId: modNsgPrivateLinkEndpointsSubnet.outputs.resourceId
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    serviceEndpointPolicies: []
    serviceEndpoints: []
  }
}

@description('The dedicated subnet that contains application gateway used for ingress in this architecture. UDR not applied for egress traffic, per requirements of the service. NSG applied as well.')
module modApplicationGatewaySubnet 'br/public:avm/res/network/virtual-network/subnet:0.1.2' = {
  name: '${_dep}-subnet-applicationgateway'
  scope: resourceGroup(varVirtualNetwork.subscriptionId, varVirtualNetwork.resourceGroupName)
  dependsOn: [modPrivateEndpointsSubnet]
  params: {
    virtualNetworkName: resVnet1.name
    name: 'snet-applicationgateway'
    addressPrefix: '10.240.5.0/24'
    networkSecurityGroupResourceId: modNsgAppGwSubnet.outputs.resourceId
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    serviceEndpointPolicies: []
    serviceEndpoints: []
  }
}

@description('The subnet that contains private build agents for last-mile deployments into this architecture. UDR applied for egress traffic. NSG applied as well.')
module moddeploymentAgentsSubnet 'br/public:avm/res/network/virtual-network/subnet:0.1.2' = {
  name: '${_dep}-subnet-deploymentagents'
  scope: resourceGroup(varVirtualNetwork.subscriptionId, varVirtualNetwork.resourceGroupName)
  dependsOn: [modApplicationGatewaySubnet]
  params: {
    virtualNetworkName: resVnet1.name
    name: 'snet-deploymentagents'
    addressPrefix: '10.240.4.96/28'
    routeTableResourceId: parRouteTableNextHopToFirewallResourceId
    networkSecurityGroupResourceId: modNsgBuildAgentSubnet.outputs.resourceId
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    serviceEndpointPolicies: []
    serviceEndpoints: []
  }
}

@description('This IP is used as the primary public entry point for the workload. Expected to be assigned to an Azure Application Gateway.')
module modPipPrimaryWorkloadIp 'br/public:avm/res/network/public-ip-address:0.9.0' = {
  name: '${_dep}-pip-primary-workload-ip'
  scope: resourceGroup()
  params: {
    name: 'pip-${varLocationCode}-primary-workload-ip'
    location: parLocation
    skuName: 'Standard'
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

@description('Sets up the provided group object id to have access to SSH or RDP into all virtual machines with the Entra ID login extension installed in this resource group.')
module modGrantAdminRbacAccessToRemoteIntoVMs 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.0' = {
  name: '${_dep}-rbac-grant-admin-remote-into-vms'
  scope: resourceGroup()
  params: {
    roleDefinitionIdOrName: varRbacRoleDefinitionIds.vmAdminLogin
    //principalId: resAdminGroup.id
    principalId: parAdminSecurityPrincipalObjectId
    principalType: 'Group'
  }
}

@description('Azure WAF policy to apply to our workload\'s inbound traffic.')
module modWafPolicy 'br/public:avm/res/network/application-gateway-web-application-firewall-policy:0.2.0' = {
  name: '${_dep}-waf-ingress-policy'
  scope: resourceGroup()
  params: {
    name: 'waf-ingress-policy'
    policySettings: {
      fileUploadLimitInMb: 10
      state: 'Enabled'
      mode: 'Prevention'
      customBlockResponseBody: null
      customBlockResponseStatusCode: null
      fileUploadEnforcement: true
      logScrubbing: {
        state: 'Disabled'
        scrubbingRules: []
      }
      maxRequestBodySizeInKb: 128
      requestBodyCheck: true
      requestBodyEnforcement: true
      requestBodyInspectLimitInKb: 128
    }
    managedRules: {
      exclusions: []
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
          ruleGroupOverrides: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.1'
          ruleGroupOverrides: []
        }
      ]
    }
  }
}

@description('User Managed Identity that App Gateway is assigned. Used for Azure Key Vault Access.')
module modIdAppGatewayFrontend 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: '${_dep}-id-appgateway-frontend'
  scope: resourceGroup()
  params: {
    name: 'id-${varLocationCode}-appgateway-frontend'
    location: parLocation
  }
}

@description('The managed identity for all frontend virtual machines.')
module modIdVmssFrontend 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: '${_dep}-id-vmss-frontend'
  scope: resourceGroup()
  params: {
    name: 'id-${varLocationCode}-vmss-frontend'
    location: parLocation
  }
}

@description('The managed identity for all backend virtual machines.')
module modIdVmssBackend 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: '${_dep}-id-vmss-backend'
  scope: resourceGroup()
  params: {
    name: 'id-${varLocationCode}-vmss-backend'
    location: parLocation
  }
}

module modBastion 'br/public:avm/res/network/bastion-host:0.8.0' = {
  name: '${_dep}-bastion'
  params: {
    name: 'bas-${varLocationCode}-001-${parEnvironment}'
    virtualNetworkResourceId: resVnet1.id
    skuName: 'Developer'
    location: parLocation
  }
}

// module modVmssFrontend00 'br/public:avm/res/compute/virtual-machine-scale-set:0.9.0' = {
//   //name: '${_dep}-vmss-frontend-00'
//   //scope: resourceGroup()
//   params: {
//     name: 'vmss-${varLocationCode}-frontend-00'
//     location: parLocation
//     managedIdentities: {
//       userAssignedResourceIds: [
//         modIdVmssFrontend.outputs.resourceId
//       ]
//     }
//     skuName: 'Standard_B2s'
//     // skuName: 'Standard_B8ms'
//     skuCapacity: 1
//     singlePlacementGroup: false
//     ultraSSDEnabled: false
//     orchestrationMode: 'Flexible'
//     scaleSetFaultDomain: 1
//     zoneBalance: false
//     bootDiagnosticEnabled: true
//     vmNamePrefix: 'frontend'
//     disablePasswordAuthentication: true
//     provisionVMAgent: true
//     patchAssessmentMode: 'ImageDefault'
//     bypassPlatformSafetyChecksOnUserSchedule: false
//     rebootSetting: 'IfRequired'
//     patchMode: 'AutomaticByPlatform'
//     adminUsername: varDefaultAdminUserName
//     adminPassword: 'changeme12082025!'
//     customData: loadFileAsBase64('frontendCloudInit.yml')
//     publicKeys: [
//       {
//         keyData: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCW0PvGF59cCsp16Soc2vW+fErUUFlF3BJfSu1x0L89LMhyWbtI3+v2wqYTZB924NrW29acgeo5C953A/9jKChCZXOYhIB0NEtegOm5xto77jzbw0069JJJ0K2TDMfNHGMV3Y0ASUo0kQu0cYQMQXBz99s6eNm6B34tulT9qVonMe2/kDI5pD4WmZNOT00SQn9Nn1ShBQpLULzHO2koB1eKZg9agr4m/brWxygmMiBgYFOnGuhTyYXdRX22IvfGrxOmjrG0AW0x3BWAK880UDd7PPQPe1cAGdGA6+vWDifT69xWV/GDc4AMhdfUOZwMEw74XJY9n+lksm8/GlPgJmlVp9WL7Kom54SMyugXMrF45yXnTRjnAppfXgRJ8hKDt4qxOKwOdMvpIOl0oQ33dwcPGbtlgV6R8bClnTrpsGTKZ5oU5gXQDgqCZUbrfmrhiTUwTe5Y+r5YotpKeb3n5La/N+rSaFLW/Ge4rafRtNSD8WhWW8GW5kPcsJdnmASUBa0='
//         path: '/home/${varDefaultAdminUserName}/.ssh/authorized_keys'
//       }
//     ]
//     osType: 'Linux'
//     osDisk: {
//       diskSizeGB: 30
//       caching: 'ReadOnly'
//       createOption: 'FromImage'
//       managedDisk: {
//         storageAccountType: 'Standard_LRS'
//       }
//       diffDiskSettings: {
//         option: 'Local'
//         placement: 'CacheDisk'
//       }
//     }
//     imageReference: {
//       publisher: 'Canonical'
//       offer: '0001-com-ubuntu-server-focal'
//       sku: '20_04-lts-gen2'
//       version: 'latest'
//     }
//     dataDisks: [
//       {
//         caching: 'None'
//         createOption: 'Empty'
//         deleteOption: 'Delete'
//         diskSizeGB: '4'
//         lun: 0
//         managedDisk: {
//           storageAccountType: 'Premium_ZRS'
//         }
//       }
//     ]
//     nicConfigurations: [
//       {
//         name: 'nic-frontend'
//         nicSuffix: ''
//         primary: true
//         enableIPForwarding: false
//         enableAcceleratedNetworking: false
//         networkSecurityGroup: null
//         deleteOption: 'Delete'
//         ipconfigurations: [
//           {
//             name: 'default'
//             properties: {
//               subnet: {
//                 id: modFrontendSubnet.outputs.resourceId
//               }
//               applicationSecurityGroups: [
//                 {
//                   id: modAsgVmssFrontend.outputs.resourceId
//                 }
//               ]
//             }
//           }
//         ]
//       }
//     ]
//   }
// }

module modVmssBackendend00 'br/public:avm/res/compute/virtual-machine-scale-set:0.10.1' = {
  params: {
    name: 'vmss-${varLocationCode}-backend-00'
    location: parLocation
    managedIdentities: {
      userAssignedResourceIds: [
        modIdVmssBackend.outputs.resourceId
      ]
    }
    skuName: 'Standard_B2s'
    // skuName: 'Standard_B8ms'
    skuCapacity: 0
    singlePlacementGroup: false
    ultraSSDEnabled: false
    orchestrationMode: 'Flexible'
    scaleSetFaultDomain: 1
    zoneBalance: false
    bootDiagnosticEnabled: true
    vmNamePrefix: 'backend'
    disablePasswordAuthentication: true
    provisionVMAgent: true
    patchAssessmentMode: 'ImageDefault'
    bypassPlatformSafetyChecksOnUserSchedule: false
    rebootSetting: 'IfRequired'
    patchMode: 'AutomaticByPlatform'
    adminUsername: varDefaultAdminUserName
    adminPassword: 'changeme12082025!'
    osType: 'Windows'
    osDisk: {
      diskSizeGB: 30
      caching: 'ReadOnly'
      createOption: 'FromImage'
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
      diffDiskSettings: {
        option: 'Local'
        placement: 'CacheDisk'
      }
    }
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition-smalldisk'
      version: 'latest'
    }
    dataDisks: [
      {
        caching: 'None'
        createOption: 'Empty'
        deleteOption: 'Delete'
        diskSizeGB: '4'
        lun: 0
        managedDisk: {
          storageAccountType: 'Premium_ZRS'
        }
      }
    ]
    nicConfigurations: [
      {
        name: 'nic-backend'
        nicSuffix: ''
        primary: true
        enableIPForwarding: false
        enableAcceleratedNetworking: false
        networkSecurityGroup: null
        deleteOption: 'Delete'
        ipconfigurations: [
          {
            name: 'default'
            properties: {
              subnet: {
                id: modBackendSubnet.outputs.resourceId
              }
              applicationSecurityGroups: [
                {
                  id: modAsgVmssBackend.outputs.resourceId
                }
              ]
            }
          }
        ]
      }
    ]
    extensionHealthConfig: {
      // https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/health-extension?tabs=rest-api
      typeHandlerVersion: '1.0' // Binary Health States
      autoUpgradeMinorVersion: true
      enabled: true
      protocol: 'https'
      port: 443
      requestPath: '/favicon.ico'
      intervalInSeconds: 5
      numberOfProbes: 3
    }
    extensionMonitoringAgentConfig: {
      enabled: true
      typeHandlerVersion: '1.36'
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: false
    }
  }
}

module modVmssBackendAADLoginExtension '../../../bicep-registry-modules/avm/res/compute/virtual-machine-scale-set/extension/main.bicep' = {
  params: {
    name: 'AADLogin'
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.ActiveDirectory'
    enableAutomaticUpgrade: false
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.2'
    virtualMachineScaleSetName: modVmssBackendend00.outputs.name
    settings: {
      mdmId: ''
    }
  }
}

module modVmssKeyVaultExtension '../../../bicep-registry-modules/avm/res/compute/virtual-machine-scale-set/extension/main.bicep' = {
  dependsOn: [
    modVmssBackendAADLoginExtension
  ]
  params: {
    name: 'KeyVaultForWindows'
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.KeyVault'
    enableAutomaticUpgrade: true
    type: 'KeyVaultForWindows'
    typeHandlerVersion: '3.3'
    virtualMachineScaleSetName: modVmssBackendend00.outputs.name
    settings: {
      secretsManagementSettings: {
        observedCertificates: [
          {
            certificateStoreName: 'MY'
            certificateStoreLocation: 'LocalMachine'
            keyExportable: true
            url: parKeyVaultSecretId
            accounts: [
              'Network Service'
              'Local Service'
            ]
          }
        ]
        linkOnRenewal: true
        pollingIntervalInS: '3600'
      }
      authenticationSettings: {
        msiEndpoint: 'http://169.254.169.254/metadata/identity/oauth2/token'
        msiClientId: modIdVmssBackend.outputs.clientId
      }
    }
  }
}

module modVmssBackendCustomScriptExtension '../../infra-as-code/bicep/modules/compute/virtual-machine-scale-set/extension/main.bicep' = {
  params: {
    provisionAfterExtensions: [
      modVmssKeyVaultExtension.outputs.name
    ]
    name: 'CustomScript'
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Compute'
    enableAutomaticUpgrade: false
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    virtualMachineScaleSetName: modVmssBackendend00.outputs.name
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File configure-nginx-backend.ps1'
      // The following installs and configure Nginx for the backend Windows machine, which is used as an application stand-in for this reference implementation.
      // Using the CustomScript extension can be useful for bootstrapping VMs in leu of a larger DSC solution, but is generally not recommended for application deployments.
      fileUris: [
        'https://raw.githubusercontent.com/jdrepo/ALZ-Deploy/main/workloads/workload-online1/configure-nginx-backend.ps1'
      ]
    }
  }
}

@description('Grant the Azure Application Gateway managed identity with key vault secrets role permissions; this allows pulling frontend and backend certificates.')
module modRoleAssignAppGwKvSecretsUser '../../../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  scope: resourceGroup(varKeyVault.resourceGroupName)
  params: {
    principalId: modIdAppGatewayFrontend.outputs.principalId
    resourceId: parKeyVaultResourceId
    roleDefinitionId: varRbacRoleDefinitionIds.keyVaultSecretsUser
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the Azure Application Gateway managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.')
module modRoleAssignAppGwKvReader '../../../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  scope: resourceGroup(varKeyVault.resourceGroupName)
  params: {
    principalId: modIdAppGatewayFrontend.outputs.principalId
    resourceId: parKeyVaultResourceId
    roleDefinitionId: varRbacRoleDefinitionIds.keyVaultReader
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the Vmss Frontend managed identity with key vault secrets role permissions; this allows pulling frontend and backend certificates.')
module modRoleAssignFrontendKvSecretsUser '../../../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  scope: resourceGroup(varKeyVault.resourceGroupName)
  params: {
    principalId: modIdVmssFrontend.outputs.principalId
    resourceId: parKeyVaultResourceId
    roleDefinitionId: varRbacRoleDefinitionIds.keyVaultSecretsUser
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the Azure Application Gateway managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.')
module modRoleAssignFrontendKvReader '../../../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  scope: resourceGroup(varKeyVault.resourceGroupName)
  params: {
    principalId: modIdVmssFrontend.outputs.principalId
    resourceId: parKeyVaultResourceId
    roleDefinitionId: varRbacRoleDefinitionIds.keyVaultReader
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the Vmss Backend managed identity with key vault secrets role permissions; this allows pulling frontend and backend certificates.')
module modRoleAssignBackendKvSecretsUser '../../../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  scope: resourceGroup(varKeyVault.resourceGroupName)
  params: {
    principalId: modIdVmssBackend.outputs.principalId
    resourceId: parKeyVaultResourceId
    roleDefinitionId: varRbacRoleDefinitionIds.keyVaultSecretsUser
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the Vmss Backend managed identity with key vault secrets role permissions; this allows pulling frontend and backend certificates.')
module modRoleAssignBackendKvReader '../../../bicep-registry-modules/avm/ptn/authorization/resource-role-assignment/main.bicep' = {
  scope: resourceGroup(varKeyVault.resourceGroupName)
  params: {
    principalId: modIdVmssBackend.outputs.principalId
    resourceId: parKeyVaultResourceId
    roleDefinitionId: varRbacRoleDefinitionIds.keyVaultReader
    principalType: 'ServicePrincipal'
  }
}

@description('Private Endpoint for Key Vault. All compute in the virtual network will use this endpoint.')
module modPrivateEndpointKeyVault 'br/public:avm/res/network/private-endpoint:0.11.0' = {
  params: {
    name: 'pe-${varLocationCode}-${varKeyVault.resourceName}-${parEnvironment}'
    subnetResourceId: modPrivateEndpointsSubnet.outputs.resourceId
    customNetworkInterfaceName: 'nic-pe-${varKeyVault.resourceName}-${parEnvironment}'
    applicationSecurityGroupResourceIds: [
      modAsgKeyVault.outputs.resourceId
    ]
    privateLinkServiceConnections: [
      {
        name: 'to-${varVirtualNetwork.resourceName}'
        properties: {
          groupIds: [
            'vault'
          ]
          privateLinkServiceId: parKeyVaultResourceId
        }
      }
    ]
  }
}



module modPrivateDnsZoneBackend 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  params: {
    name: 'schoolscloud.eu'
    virtualNetworkLinks: [
      {
        name: 'link-to-${varVirtualNetwork.resourceName}'
        virtualNetworkResourceId: parVnetResourceId
        registrationEnabled: false
      }
    ]
    a: [
      {
        name: 'app01'
        aRecords: [
          {
            ipv4Address: varIlbPrivateIp
          }
        ]
      }
      {
        name: 'backend-00'
        aRecords: [
          {
            ipv4Address: varIlbPrivateIp
          }
        ]
      }
    ]
  }
}

// module modAppGw 'br/public:avm/res/network/application-gateway:0.7.0' = {
//   params: {
//     name: varAgwName
//     managedIdentities: {
//       userAssignedResourceIds: [
//         modIdAppGatewayFrontend.outputs.resourceId
//       ]
//     }
//     sslPolicyType: 'Predefined'
//     sslPolicyName: 'AppGwSslPolicy20220101S'
//     gatewayIPConfigurations: [
//       {
//         name: 'ingress-into-${modApplicationGatewaySubnet.outputs.name}'
//         properties: {
//           subnet: {
//             id: modApplicationGatewaySubnet.outputs.resourceId
//           }
//         }
//       }
//     ]
//     frontendIPConfigurations: [
//       {
//         name: 'frontendIPConfig1'
//         properties: {
//           publicIPAddress: {
//             id: modPipPrimaryWorkloadIp.outputs.resourceId
//           }
//         }
//       }
//     ]
//     frontendPorts: [
//       {
//         name: 'https'
//         properties: {
//           port: 443
//         }
//       }
//     ]
//     autoscaleMinCapacity: 0
//     autoscaleMaxCapacity: 10
//     firewallPolicyResourceId: modWafPolicy.outputs.resourceId
//     enableHttp2: false
//     rewriteRuleSets: []
//     redirectConfigurations: []
//     privateLinkConfigurations: []
//     urlPathMaps: []
//     listeners: []
//     sslProfiles: []
//     trustedClientCertificates: []
//     loadDistributionPolicies: []
//     sslCertificates: [
//       {
//         name: 'public-gateway-cert'
//         properties: {
//           keyVaultSecretId: parKeyVaultSecretId
//         }
//       }
//     ]
//     probes: [
//       {
//         name: 'vmss-frontend'
//         properties: {
//           protocol: 'Https'
//           path: '/favicon.ico'
//           interval: 30
//           timeout: 30
//           unhealthyThreshold: 3
//           pickHostNameFromBackendHttpSettings: true
//           minServers: 0
//           match: {}
//         }
//       }
//     ]
//     backendAddressPools: [
//       {
//         name: 'vmss-frontend'
//       }
//     ]
//     backendHttpSettingsCollection: [
//       {
//         name: 'vmss-webserver'
//         properties: {
//           port: 443
//           protocol: 'Https'
//           cookieBasedAffinity: 'Disabled'
//           hostName: 'app01.schoolscloud.eu'
//           pickHostNameFromBackendAddress: false
//           requestTimeout: 20
//           probeEnabled: true
//           probe: {
//             id: resourceId('Microsoft.Network/applicationGateways/probes', varAgwName, 'vmss-frontend')
//           }
//         }
//       }
//     ]
//     httpListeners: [
//       {
//         name: 'https-public-ip'
//         properties: {
//           frontendIPConfiguration: {
//             id: resourceId(
//               'Microsoft.Network/applicationGateways/frontendIPConfigurations',
//               varAgwName,
//               'frontendIPConfig1'
//             )
//           }
//           frontendPort: {
//             id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', varAgwName, 'https')
//           }
//           protocol: 'Https'
//           sslCertificate: {
//             id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', varAgwName, 'public-gateway-cert')
//           }
//           hostName: 'app01.schoolscloud.eu'
//           requireServerNameIndication: true
//         }
//       }
//     ]
//     requestRoutingRules: [
//       {
//         name: 'https-to-vmss-frontend'
//         properties: {
//           ruleType: 'Basic'
//           priority: 100
//           httpListener: {
//             id: resourceId('Microsoft.Network/applicationGateways/httpListeners', varAgwName, 'https-public-ip')
//           }
//           backendAddressPool: {
//             id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', varAgwName, 'vmss-frontend')
//           }
//           backendHttpSettings: {
//             id: resourceId(
//               'Microsoft.Network/applicationGateways/backendHttpSettingsCollection',
//               varAgwName,
//               'vmss-webserver'
//             )
//           }
//         }
//       }
//     ]
//   }
// }

module modInternalLoadBalancer 'br/public:avm/res/network/load-balancer:0.4.2' = {
  params: {
    name: varIlbName
    frontendIPConfigurations: [
      {
        name: 'backend'
        subnetId: modInternalLoadBalancerSubnet.outputs.resourceId
        privateIPAddress: varIlbPrivateIp
        privateAllocationMethod: 'Static'
        privateIPAddressVersion: 'IPv4'
      }
    ]
    backendAddressPools: [
      {
        name: 'vmss-backend'
      }
    ]
    loadBalancingRules: [
      {
        name: 'https'
        backendAddressPoolName: 'vmss-backend'
        frontendIPConfigurationName: 'backend'
        probeName: 'vmss-backend-probe'
        protocol: 'Tcp'
        frontendPort: 443
        backendPort: 443
        idleTimeoutInMinutes: 15
        enableFloatingIP: false
        enableTcpReset: false
        disableOutboundSnat: false
        loadDistribution: 'Default'
      }
    ]
    probes: [
      {
        name: 'vmss-backend-probe'
        protocol: 'Tcp'
        port: 80
        intervalInSeconds: 15
        numberOfProbes: 2
        probeThreshold: 1
      }
    ]
  }
}

// Application Gateway does not inhert the virtual network DNS settings for the parts of the service that
// are responsible for getting Key Vault certs connected at resource deployment time, but it does for other parts
// of the service. To that end, we have a local private DNS zone that is in place just to support Application Gateway.
// No other resources in this virtual network benefit from this.  If this is ever resolved both modKeyVaultPrivateDnsZone and
// modPrivateEndpointKeyVaultForAppGw can be removed.
// https://medium.com/@petrutbelingher/application-gateway-private-dns-resolvers-dns-resolution-private-endpoints-in-azure-489b01f6694c
// https://learn.microsoft.com/en-us/answers/questions/714888/azure-application-gateways-do-not-resolve-private
// https://learn.microsoft.com/en-us/azure/application-gateway/key-vault-certs#verify-firewall-permissions-to-key-vault
// https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-private-deployment?tabs=portal

@description('Deploy Key Vault private DNS zone so that Application Gateway can resolve at resource deployment time.')
module modKeyVaultPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  params: {
    name: 'privatelink.vaultcore.azure.net'
    virtualNetworkLinks: [
      {
        name: 'link-to-${varVirtualNetwork.resourceName}'
        virtualNetworkResourceId: parVnetResourceId
        registrationEnabled: false
      }
    ]
  }
}

@description('Private Endpoint for Key Vault exclusively for the use of Application Gateway, which doesn\'t seem to pick up on DNS settings for Key Vault access.')
module modPrivateEndpointKeyVaultForAppGw 'br/public:avm/res/network/private-endpoint:0.11.0' = {
  params: {
    name: 'pe-${varLocationCode}-${varKeyVault.resourceName}-appgw-${parEnvironment}'
    subnetResourceId: modPrivateEndpointsSubnet.outputs.resourceId
    customNetworkInterfaceName: 'nic-pe-${varKeyVault.resourceName}-appgw-${parEnvironment}'
    applicationSecurityGroupResourceIds: [
      modAsgKeyVault.outputs.resourceId
    ]
    privateLinkServiceConnections: [
      {
        name: 'to-${varVirtualNetwork.resourceName}-for-appgw'
        properties: {
          groupIds: [
            'vault'
          ]
          privateLinkServiceId: parKeyVaultResourceId
        }
      }
    ]
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          privateDnsZoneResourceId: modKeyVaultPrivateDnsZone.outputs.resourceId
        }
      ]
    }
  }
  dependsOn: [
    modPrivateEndpointKeyVault // Deploying both endpoints at the same time can cause ConflictErrors
  ]
}
