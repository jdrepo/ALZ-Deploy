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
    parTargetManagementGroupId: '${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}'
  }
}

module modCustomRoleDefinitions '../../ALZ-Bicep/infra-as-code/bicep/modules/customRoleDefinitions/customRoleDefinitions.bicep' = {
  scope: managementGroup('${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}')
  name: 'customRoleDefinitions-${deployment().name}'
  params: {
    parAssignableScopeManagementGroupId: '${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}'
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
  params: {
    parLogAnalyticsWorkspaceLocation: deployment().location
    parAutomationAccountLocation: deployment().location
  }
}

module modMgDiagSettings '../../ALZ-Bicep/infra-as-code/bicep/orchestration/mgDiagSettingsAll/mgDiagSettingsAll.bicep' = {
  scope: managementGroup('${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}')
  name: 'mgDiagSettings-${deployment().name}'
  params: {
    parLogAnalyticsWorkspaceResourceId: modLoggingResources.outputs.outLogAnalyticsWorkspaceId
    parTopLevelManagementGroupPrefix: parTopLevelManagementGroupPrefix
    parTopLevelManagementGroupSuffix: parTopLevelManagementGroupSuffix
  }
}

