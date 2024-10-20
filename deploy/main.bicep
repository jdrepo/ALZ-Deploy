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

module modManagementGroup '../../alz-bicep/infra-as-code/bicep/modules/managementGroups/managementGroups.bicep' = {
  scope: tenant()
  name: 'mg-deployment-${deployment().name}'
  params: {
    parTopLevelManagementGroupPrefix: parTopLevelManagementGroupPrefix
    parTopLevelManagementGroupSuffix: parTopLevelManagementGroupSuffix
    parTopLevelManagementGroupDisplayName: parTopLevelManagementGroupDisplayName
  }
}

module modCustomPolicyDefinitions '../../alz-bicep/infra-as-code/bicep/modules/policy/definitions/customPolicyDefinitions.bicep' = {
  scope: managementGroup('${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}')
  name: 'customPolicyDefinitions-${deployment().name}'
  params: {
    parTargetManagementGroupId: '${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}'
  }
}

module modCustomRoleDefinitions '../../ALz-bicep/infra-as-code/bicep/modules/customRoleDefinitions/customRoleDefinitions.bicep' = {
  scope: managementGroup('${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}')
  name: 'customRoleDefinitions-${deployment().name}'
  params: {
    parAssignableScopeManagementGroupId: '${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}'
  }
}


