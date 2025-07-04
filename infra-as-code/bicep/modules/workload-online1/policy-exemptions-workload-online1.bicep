targetScope = 'subscription'

metadata name = 'Policy Exemptions for Workload Online 1'
metadata description = 'Deploy policy exemptions for Workload Online 1.'

@description('Prefix for management group hierarchy.')
@minLength(2)
@maxLength(10)
param parTopLevelManagementGroupPrefix string = 'alz'

@description('Optional suffix for management group names/IDs.')
@maxLength(10)
param parTopLevelManagementGroupSuffix string = ''

var _dep = deployment().name

// Management Groups Variables - Used For Policy Exemptions
var varManagementGroupIds = {
  intRoot: '${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}'
  platform: '${parTopLevelManagementGroupPrefix}-platform${parTopLevelManagementGroupSuffix}'
  landingZones: '${parTopLevelManagementGroupPrefix}-landingzones${parTopLevelManagementGroupSuffix}'
  landingZonesCorp: '${parTopLevelManagementGroupPrefix}-landingzones-corp${parTopLevelManagementGroupSuffix}'
  landingZonesOnline: '${parTopLevelManagementGroupPrefix}-landingzones-online${parTopLevelManagementGroupSuffix}'
}

var varPolicyExemptionKvIntegratedCA = {
  definitionId: '/providers/Microsoft.Management/managementGroups/${varManagementGroupIds.landingZones}/providers/Microsoft.Authorization/policyAssignments/enforce-gr-keyvault'
  libDefinition: loadJsonContent('../policy/exemptions/lib/policy_exemptions/policy_exemption_es_deny_keyvault_certificate_integrated_ca.tmpl.json')
}

var varPolicyExemptionKvCertExpireDays = {
  definitionId: '/providers/Microsoft.Management/managementGroups/${varManagementGroupIds.landingZones}/providers/Microsoft.Authorization/policyAssignments/enforce-gr-keyvault'
  libDefinition: loadJsonContent('../policy/exemptions/lib/policy_exemptions/policy_exemption_es_deny_keyvault_certificate_expire_days.tmpl.json')
}


module modPolicyExemptionKvIntegratedCA '../../../../../bicep-registry-modules/avm/ptn/authorization/policy-exemption/modules/subscription.bicep' = {
  name: '${_dep}-pol-exempt-KvCA'
  params: {
    name: varPolicyExemptionKvIntegratedCA.libDefinition.name
    exemptionCategory: 'Waiver'
    policyAssignmentId: varPolicyExemptionKvIntegratedCA.definitionId
    displayName: varPolicyExemptionKvIntegratedCA.libDefinition.properties.displayName
    description: varPolicyExemptionKvIntegratedCA.libDefinition.properties.description
    policyDefinitionReferenceIds: varPolicyExemptionKvIntegratedCA.libDefinition.properties.policyDefinitionReferenceIds
  }
}

module modPolicyExemptionKvCertExpireDays '../../../../../bicep-registry-modules/avm/ptn/authorization/policy-exemption/modules/subscription.bicep' = {
  name: '${_dep}-pol-exempt-KvCertExpireDays'
  params: {
    name: varPolicyExemptionKvCertExpireDays.libDefinition.name
    exemptionCategory: 'Waiver'
    policyAssignmentId: varPolicyExemptionKvCertExpireDays.definitionId
    displayName: varPolicyExemptionKvCertExpireDays.libDefinition.properties.displayName
    description: varPolicyExemptionKvCertExpireDays.libDefinition.properties.description
    policyDefinitionReferenceIds: varPolicyExemptionKvCertExpireDays.libDefinition.properties.policyDefinitionReferenceIds
  }
}
