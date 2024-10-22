targetScope = 'tenant'

@sys.description('Prefix used for the management group hierarchy. This management group will be created as part of the deployment.')
@minLength(2)
@maxLength(10)
param parTopLevelManagementGroupPrefix string = 'alz'

@sys.description('Optional suffix for the management group hierarchy. This suffix will be appended to management group names/IDs. Include a preceding dash if required. Example: -suffix')
@maxLength(10)
param parTopLevelManagementGroupSuffix string = ''

@sys.description('Display name for top level management group. This name will be applied to the management group prefix defined in parTopLevelManagementGroupPrefix parameter.')
@minLength(2)
param parTopLevelManagementGroupDisplayName string = 'Azure Landing Zones'

@sys.description('Subscription Id for Platform logging resources.')
param parLoggingSubscriptionId string = ''

@sys.description('Resource group name for Platform logging resources.')
param parLoggingResourceGroupName string = 'alz-logging-001'

@sys.description('Subscription Id for Platform connectivity resources.')
param parConnectivitySubscriptionId string = ''

@sys.description('Resource group name for Platform connectivity resources.')
param parHubNetworkResourceGroupName string = 'alz-hub-networking-001'

@sys.description('Subscription Id for Platform management resources.')
param parMgmtSubscriptionId string = ''

@sys.description('Subscription Id for Platform identity resources.')
param parIdentitySubscriptionId string = ''

@description('Email address for Microsoft Defender for Cloud alerts.')
param parMsDefenderForCloudEmailSecurityContact string = 'security_contact@replace_me.com'


module modManagementGroup '../../ALZ-Bicep/infra-as-code/bicep/modules/managementGroups/managementGroups.bicep' = {
  scope: tenant()
  name: 'mg-deployment-${deployment().name}'
  params: {
    parTopLevelManagementGroupPrefix: parTopLevelManagementGroupPrefix
    parTopLevelManagementGroupSuffix: parTopLevelManagementGroupSuffix
    parTopLevelManagementGroupDisplayName: parTopLevelManagementGroupDisplayName
  }
}

module modCustomPolicyDefinitions '../../ALZ-Bicep/infra-as-code/bicep/modules/policy/definitions/customPolicyDefinitions.bicep' = {
  scope: managementGroup('${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}')
  name: 'customPolicyDefinitions-${deployment().name}'
  params: {
    parTargetManagementGroupId: modManagementGroup.outputs.outTopLevelManagementGroupName
  }
}

module modCustomRoleDefinitions '../../ALZ-Bicep/infra-as-code/bicep/modules/customRoleDefinitions/customRoleDefinitions.bicep' = {
  scope: managementGroup('${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}')
  name: 'customRoleDefinitions-${deployment().name}'
  params: {
    parAssignableScopeManagementGroupId: modManagementGroup.outputs.outTopLevelManagementGroupName
  }
}

module modLoggingResourceGroup '../../ALZ-Bicep/infra-as-code/bicep/modules/resourceGroup/resourceGroup.bicep' = {
  scope: subscription(parLoggingSubscriptionId)
  name: 'loggingResourceGroup-${deployment().name}'
  params: {
    parLocation: deployment().location
    parResourceGroupName: parLoggingResourceGroupName
  }
}

module modLoggingResources '../../ALZ-Bicep/infra-as-code/bicep/modules/logging/logging.bicep' = {
  scope: resourceGroup(parLoggingSubscriptionId,parLoggingResourceGroupName)
  name: 'loggingResourceGroup-${deployment().name}'
  dependsOn: [
    modLoggingResourceGroup
  ]
  params: {
    parLogAnalyticsWorkspaceLocation: deployment().location
    parAutomationAccountLocation: deployment().location
  }
}

module modMgDiagSettings '../../ALZ-Bicep/infra-as-code/bicep/orchestration/mgDiagSettingsAll/mgDiagSettingsAll.bicep' = {
  scope: managementGroup('${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}')
  name: 'mgDiagSettings-${deployment().name}'
  dependsOn: [
    modManagementGroup
  ]
  params: {
    parLogAnalyticsWorkspaceResourceId: modLoggingResources.outputs.outLogAnalyticsWorkspaceId
    parTopLevelManagementGroupPrefix: parTopLevelManagementGroupPrefix
    parTopLevelManagementGroupSuffix: parTopLevelManagementGroupSuffix
  }
}

module modHubNetworkResourceGroup '../../ALZ-Bicep/infra-as-code/bicep/modules/resourceGroup/resourceGroup.bicep' = {
  scope: subscription(parConnectivitySubscriptionId)
  name: 'hubNetworkResourceGroup-${deployment().name}'
  params: {
    parLocation: deployment().location
    parResourceGroupName: parHubNetworkResourceGroupName
  }
}

module modHubNetwork '../../ALZ-Bicep/infra-as-code/bicep/modules/hubNetworking/hubNetworking.bicep' = {
  scope: resourceGroup(parConnectivitySubscriptionId,parHubNetworkResourceGroupName)
  name: 'hubNetwork-${deployment().name}'
  params: {
    parCompanyPrefix: parTopLevelManagementGroupPrefix
    parHubNetworkName: '${parTopLevelManagementGroupPrefix}-hub-${deployment().location}'
    parAzBastionEnabled: false
    parDdosEnabled: false
    parAzFirewallName: '${parTopLevelManagementGroupPrefix}-azfw-${deployment().location}'
    parAzFirewallPoliciesName: '${parTopLevelManagementGroupPrefix}-azfwpolicy-${deployment().location}'
    parHubRouteTableName: '${parTopLevelManagementGroupPrefix}-hub-routetable-${deployment().location}'
    parVpnGatewayEnabled: false
    parExpressRouteGatewayEnabled: false
    parPrivateDnsZoneAutoMergeAzureBackupZone: true
    parPrivateDnsZonesEnabled: true
    parPrivateDnsZones: [
      'privatelink.file.core.windows.net'
      'privatelink.wvd.microsoft.com'
    ]
    parLocation: deployment().location
  }
}

module modSubPlacement '../../ALZ-Bicep/infra-as-code/bicep/orchestration/subPlacementAll/subPlacementAll.bicep' = {
  scope: managementGroup('${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}')
  dependsOn: [
    modManagementGroup
  ]
  name: 'subPlacement-${deployment().name}'
  params: {
    parTopLevelManagementGroupPrefix: parTopLevelManagementGroupPrefix
    parTopLevelManagementGroupSuffix: parTopLevelManagementGroupSuffix
    parPlatformIdentityMgSubs: [
      parIdentitySubscriptionId
    ]
    parPlatformConnectivityMgSubs: [
      parConnectivitySubscriptionId
    ]
    parPlatformMgSubs: [
      parMgmtSubscriptionId
    ]
  }
}

output outUserAssignedManagedIdentityId string = modLoggingResources.outputs.outUserAssignedManagedIdentityId
output outUserAssignedManagedIdentityPrincipalId string = modLoggingResources.outputs.outUserAssignedManagedIdentityPrincipalId

output outDataCollectionRuleVMInsightsName string = modLoggingResources.outputs.outDataCollectionRuleVMInsightsName
output outDataCollectionRuleVMInsightsId string = modLoggingResources.outputs.outDataCollectionRuleVMInsightsId

output outDataCollectionRuleChangeTrackingName string = modLoggingResources.outputs.outDataCollectionRuleChangeTrackingName
output outDataCollectionRuleChangeTrackingId string = modLoggingResources.outputs.outDataCollectionRuleChangeTrackingId

output outDataCollectionRuleMDFCSQLName string = modLoggingResources.outputs.outDataCollectionRuleMDFCSQLName
output outDataCollectionRuleMDFCSQLId string = modLoggingResources.outputs.outDataCollectionRuleMDFCSQLId

output outLogAnalyticsWorkspaceName string = modLoggingResources.outputs.outLogAnalyticsWorkspaceName
output outLogAnalyticsWorkspaceId string = modLoggingResources.outputs.outLogAnalyticsWorkspaceId
output outLogAnalyticsCustomerId string = modLoggingResources.outputs.outLogAnalyticsCustomerId
output outLogAnalyticsSolutions array = modLoggingResources.outputs.outLogAnalyticsSolutions

output outAutomationAccountName string = modLoggingResources.outputs.outAutomationAccountName
output outAutomationAccountId string = modLoggingResources.outputs.outAutomationAccountId

output outHubNetworkResourceGroupName string = modHubNetworkResourceGroup.outputs.outResourceGroupName
output outHubNetworkResourceGroupId string = modHubNetworkResourceGroup.outputs.outResourceGroupId
