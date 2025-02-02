metadata name = 'ALZ Bicep - Default Policy Exemptions'
metadata description = 'Exempts ALZ Default Policies from the Management Group hierarchy'



@description('Prefix for management group hierarchy.')
@minLength(2)
@maxLength(10)
param parTopLevelManagementGroupPrefix string = 'alz'

@description('Optional suffix for management group names/IDs.')
@maxLength(10)
param parTopLevelManagementGroupSuffix string = ''

@description('Apply platform policies to Platform group or child groups.')
param parPlatformMgAlzDefaultsEnable bool = true

// **Variables**
// Orchestration Module Variables
var varDeploymentNameWrappers = {
  basePrefix: 'ALZBicep'
  #disable-next-line no-loc-expr-outside-params //Policies resources are not deployed to a region, like other resources, but the metadata is stored in a region hence requiring this to keep input parameters reduced. See https://github.com/Azure/ALZ-Bicep/wiki/FAQ#why-are-some-linter-rules-disabled-via-the-disable-next-line-bicep-function for more information
  baseSuffixTenantAndManagementGroup: '${deployment().location}-${uniqueString(deployment().location, parTopLevelManagementGroupPrefix)}'
}

var varModuleDeploymentNames = {
    modPolicyExemptionPlatformAuditKVSecretExpire: take('${varDeploymentNameWrappers.basePrefix}-polExempt-auditKVSecretExpire-platform-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolicyExemptionPlatformDeployFWDiag: take('${varDeploymentNameWrappers.basePrefix}-polExempt-DeployFWDiag-platform-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)




}

// Policy Exemptions Modules Variables

var varPolicyExemptionAuditKVSecretExpire = {
  assignmentId: '/providers/microsoft.management/managementgroups/alz-platform-canary/providers/microsoft.authorization/policyassignments/enforce-gr-keyvault'
  libDefinition: loadJsonContent('./lib/policy_exemptions/policy_exemption_es_audit_keyvault_secret_expiration_tmpl.json')
}

var varPolicyExemptionDeployFWDiag = {
  assignmentId: '/providers/microsoft.management/managementgroups/alz-canary/providers/microsoft.authorization/policyassignments/deploy-diag-logs'
  libDefinition: loadJsonContent('./lib/policy_exemptions/policy_exemption_es_deploy_firewall_diag-settings_tmpl.json')
}


// // RBAC Role Definitions Variables - Used For Policy Assignments
// var varRbacRoleDefinitionIds = {
//   owner: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
//   contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
//   networkContributor: '4d97b98b-1d4f-4787-a291-c67834d212e7'
//   aksContributor: 'ed7f3fbd-7b88-4dd4-9017-9adb7ce333f8'
//   logAnalyticsContributor: '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
//   sqlSecurityManager: '056cd41c-7e88-42e1-933e-88ba6a50c9c3'
//   vmContributor: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
//   monitoringContributor: '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
//   aksPolicyAddon: '18ed5180-3e48-46fd-8541-4ea054d57064'
//   sqlDbContributor: '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec'
//   backupContributor: '5e467623-bb1f-42f4-a55d-6e525e11384b'
//   rbacSecurityAdmin: 'fb1c8493-542b-48eb-b624-b4c8fea62acd'
//   reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
//   managedIdentityOperator: 'f1a07417-d97a-45cb-824c-7a7467783830'
//   connectedMachineResourceAdministrator: 'cd570a14-e51a-42ad-bac8-bafd67325302'
// }

// Management Groups Variables - Used For Policy Assignments
var varManagementGroupIds = {
  intRoot: '${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}'
  platform: '${parTopLevelManagementGroupPrefix}-platform${parTopLevelManagementGroupSuffix}'
  platformManagement: parPlatformMgAlzDefaultsEnable ? '${parTopLevelManagementGroupPrefix}-platform-management${parTopLevelManagementGroupSuffix}' : '${parTopLevelManagementGroupPrefix}-platform${parTopLevelManagementGroupSuffix}'
  platformConnectivity: parPlatformMgAlzDefaultsEnable ? '${parTopLevelManagementGroupPrefix}-platform-connectivity${parTopLevelManagementGroupSuffix}' : '${parTopLevelManagementGroupPrefix}-platform${parTopLevelManagementGroupSuffix}'
  platformIdentity: parPlatformMgAlzDefaultsEnable ? '${parTopLevelManagementGroupPrefix}-platform-identity${parTopLevelManagementGroupSuffix}' : '${parTopLevelManagementGroupPrefix}-platform${parTopLevelManagementGroupSuffix}'
  landingZones: '${parTopLevelManagementGroupPrefix}-landingzones${parTopLevelManagementGroupSuffix}'
  landingZonesCorp: '${parTopLevelManagementGroupPrefix}-landingzones-corp${parTopLevelManagementGroupSuffix}'
  landingZonesOnline: '${parTopLevelManagementGroupPrefix}-landingzones-online${parTopLevelManagementGroupSuffix}'
  landingZonesConfidentialCorp: '${parTopLevelManagementGroupPrefix}-landingzones-confidential-corp${parTopLevelManagementGroupSuffix}'
  landingZonesConfidentialOnline: '${parTopLevelManagementGroupPrefix}-landingzones-confidential-online${parTopLevelManagementGroupSuffix}'
  decommissioned: '${parTopLevelManagementGroupPrefix}-decommissioned${parTopLevelManagementGroupSuffix}'
  sandbox: '${parTopLevelManagementGroupPrefix}-sandbox${parTopLevelManagementGroupSuffix}'
}

var varCorpManagementGroupIds = [
  varManagementGroupIds.landingZonesCorp
  varManagementGroupIds.landingZonesConfidentialCorp
]


var varTopLevelManagementGroupResourceId = '/providers/Microsoft.Management/managementGroups/${varManagementGroupIds.intRoot}'


// **Scope**
targetScope = 'managementGroup'



// Modules - Policy Exemptions - Intermediate Root Management Group


// Modules - Policy Exemptions - Platform Management Group
// Module - Policy Exemption - Audit-KV-Secret-Expire
module modPolicyExemptionPlatformAuditKeyVaultSecretExpiration '../../../../../../ALZ-Bicep/infra-as-code/bicep/modules/policy/exemptions/policyExemptions.bicep' = {
  scope: managementGroup(varManagementGroupIds.platform)
  name: varModuleDeploymentNames.modPolicyExemptionPlatformAuditKVSecretExpire
  params: {
    parPolicyAssignmentId: varPolicyExemptionAuditKVSecretExpire.assignmentId
    parExemptionCategory: varPolicyExemptionAuditKVSecretExpire.libDefinition.properties.ExemptionCategory
    parDescription: varPolicyExemptionAuditKVSecretExpire.libDefinition.properties.description
    parAssignmentScopeValidation: varPolicyExemptionAuditKVSecretExpire.libDefinition.properties.assignmentScopeValidation
    parPolicyDefinitionReferenceIds: varPolicyExemptionAuditKVSecretExpire.libDefinition.properties.policyDefinitionReferenceIds
    parExemptionName: varPolicyExemptionAuditKVSecretExpire.libDefinition.name
    parExemptionDisplayName: varPolicyExemptionAuditKVSecretExpire.libDefinition.properties.displayName
  }
}

// Module - Policy Exemption - Deploy-FW-Diag-Settings
module modPolicyExemptionPlatformPolicyExemptionDeployFWDiag '../../../../../../ALZ-Bicep/infra-as-code/bicep/modules/policy/exemptions/policyExemptions.bicep' = {
  scope: managementGroup(varManagementGroupIds.platform)
  name: varModuleDeploymentNames.modPolicyExemptionPlatformDeployFWDiag
  params: {
    parPolicyAssignmentId: varPolicyExemptionDeployFWDiag.assignmentId
    parExemptionCategory: varPolicyExemptionDeployFWDiag.libDefinition.properties.ExemptionCategory
    parDescription: varPolicyExemptionDeployFWDiag.libDefinition.properties.description
    parAssignmentScopeValidation: varPolicyExemptionDeployFWDiag.libDefinition.properties.assignmentScopeValidation
    parPolicyDefinitionReferenceIds: varPolicyExemptionDeployFWDiag.libDefinition.properties.policyDefinitionReferenceIds
    parExemptionName: varPolicyExemptionDeployFWDiag.libDefinition.name
    parExemptionDisplayName: varPolicyExemptionDeployFWDiag.libDefinition.properties.displayName
  }
}

// Modules - Policy Exemptions - Connectivity Management Group


// Modules - Policy Exemptions - Identity Management Group



// Modules - Policy Exemptions - Management Management Group


// Modules - Policy Exemptions - Landing Zones Management Group


// Modules - Policy Exemptions - Corp Management Group



// Modules - Policy Exemptions - Decommissioned Management Group


// Modules - Policy Exemptions - Sandbox Management Group


