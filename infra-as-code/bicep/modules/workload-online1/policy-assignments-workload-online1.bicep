targetScope = 'subscription'

metadata name = 'Custom Policy Assignments for Workload Online 1'
metadata description = 'Deploy custom policy assignments for Workload Online 1.'

@description('Prefix for management group hierarchy.')
@minLength(2)
@maxLength(10)
param parTopLevelManagementGroupPrefix string = 'alz'

@description('Optional suffix for management group names/IDs.')
@maxLength(10)
param parTopLevelManagementGroupSuffix string = ''

var _dep = deployment().name

// Management Groups Variables - Used For Policy Assignments
var varManagementGroupIds = {
  intRoot: '${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}'
  platform: '${parTopLevelManagementGroupPrefix}-platform${parTopLevelManagementGroupSuffix}'
  landingZones: '${parTopLevelManagementGroupPrefix}-landingzones${parTopLevelManagementGroupSuffix}'
  landingZonesCorp: '${parTopLevelManagementGroupPrefix}-landingzones-corp${parTopLevelManagementGroupSuffix}'
  landingZonesOnline: '${parTopLevelManagementGroupPrefix}-landingzones-online${parTopLevelManagementGroupSuffix}'
}

var varPolicyAssignmentKvCertExpireDays = {
  definitionId: '/providers/Microsoft.Authorization/policyDefinitions/f772fb64-8e40-40ad-87bc-7706e1949427'
  libDefinition: loadJsonContent('../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_keyvault_certificate_expire_days.tmpl.json')
}

module modPolicyAssignmentDenyKvCertExpireDays '../../../../../bicep-registry-modules/avm/ptn/authorization/policy-assignment/modules/subscription.bicep' = {
  name: 'polAssi-DenyKvCertExpireDays'
  params: {
    policyDefinitionId: varPolicyAssignmentKvCertExpireDays.definitionId
    name: varPolicyAssignmentKvCertExpireDays.libDefinition.name
    displayName: varPolicyAssignmentKvCertExpireDays.libDefinition.properties.displayName
    description: varPolicyAssignmentKvCertExpireDays.libDefinition.properties.description
    parameters: {
      effect: {
        value: 'Deny'
      }
      daysToExpire: {
        value: 31
      }
    }
  }
}
