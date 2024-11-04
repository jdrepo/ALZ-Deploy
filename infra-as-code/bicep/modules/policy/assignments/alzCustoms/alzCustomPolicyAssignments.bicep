metadata name = 'ALZ Bicep - Custom Policy Assignments'
metadata description = 'Assigns ALZ Custom Policies to the Management Group hierarchy'

type policyAssignmentSovereigntyGlobalOptionsType = {
  @description('Enable/disable Sovereignty Baseline - Global Policies at root management group.')
  parTopLevelSovereigntyGlobalPoliciesEnable: bool

  @description('Allowed locations for resource deployment. Empty = deployment location only.')
  parListOfAllowedLocations: string[]

  @description('Effect for Sovereignty Baseline - Global Policies.')
  parPolicyEffect: ('Audit' | 'Deny' | 'Disabled' | 'AuditIfNotExists')
}

type policyAssignmentSovereigntyConfidentialOptionsType = {
  @description('Approved Azure resource types (e.g., Confidential Computing SKUs). Empty = allow all.')
  parAllowedResourceTypes: string[]

  @description('Allowed locations for resource deployment. Empty = deployment location only.')
  parListOfAllowedLocations: string[]

  @description('Approved VM SKUs for Azure Confidential Computing. Empty = allow all.')
  parAllowedVirtualMachineSKUs: string[]

  @description('Effect for Sovereignty Baseline - Confidential Policies.')
  parPolicyEffect: ('Audit' | 'Deny' | 'Disabled' | 'AuditIfNotExists')
}

@description('Prefix for management group hierarchy.')
@minLength(2)
@maxLength(10)
param parTopLevelManagementGroupPrefix string = 'alz'

@description('Optional suffix for management group names/IDs.')
@maxLength(10)
param parTopLevelManagementGroupSuffix string = ''

@description('Assign Sovereignty Baseline - Global Policies to root management group.')
param parTopLevelPolicyAssignmentSovereigntyGlobal policyAssignmentSovereigntyGlobalOptionsType = {
  parTopLevelSovereigntyGlobalPoliciesEnable: false
  parListOfAllowedLocations: []
  parPolicyEffect: 'Deny'
}

@description('Assign Sovereignty Baseline - Confidential Policies to confidential landing zone groups.')
param parPolicyAssignmentSovereigntyConfidential policyAssignmentSovereigntyConfidentialOptionsType = {
  parAllowedResourceTypes: []
  parListOfAllowedLocations: []
  parAllowedVirtualMachineSKUs: []
  parPolicyEffect: 'Deny'
}

@description('Apply platform policies to Platform group or child groups.')
param parPlatformMgAlzDefaultsEnable bool = true

@description('Assign policies to Corp & Online Management Groups under Landing Zones.')
param parLandingZoneChildrenMgAlzDefaultsEnable bool = true

@description('Assign policies to Confidential Corp and Online groups under Landing Zones.')
param parLandingZoneMgConfidentialEnable bool = false

@description('Location of Log Analytics Workspace & Automation Account.')
param parLogAnalyticsWorkSpaceAndAutomationAccountLocation string = 'eastus'

@description('Resource ID of Log Analytics Workspace.')
param parLogAnalyticsWorkspaceResourceId string = ''

@description('Resource ID for VM Insights Data Collection Rule.')
param parDataCollectionRuleVMInsightsResourceId string = ''

@description('Resource ID for Change Tracking Data Collection Rule.')
param parDataCollectionRuleChangeTrackingResourceId string = ''

@description('Resource ID for MDFC SQL Data Collection Rule.')
param parDataCollectionRuleMDFCSQLResourceId string = ''

@description('Resource ID for User Assigned Managed Identity.')
param parUserAssignedManagedIdentityResourceId string = ''

@description('Number of days to retain logs in Log Analytics Workspace.')
param parLogAnalyticsWorkspaceLogRetentionInDays string = '365'

@description('Name of the Automation Account.')
param parAutomationAccountName string = 'alz-automation-account'

@description('Email address for Microsoft Defender for Cloud alerts.')
param parMsDefenderForCloudEmailSecurityContact string = 'security_contact@replace_me.com'

@description('Enable/disable DDoS Network Protection. True enforces Enable-DDoS-VNET policy; false disables.')
param parDdosEnabled bool = true

@description('Resource ID of the DDoS Protection Plan for Virtual Networks.')
param parDdosProtectionPlanId string = ''

@description('Resource ID of the Resource Group for Private DNS Zones. Empty to skip assigning the Deploy-Private-DNS-Zones policy.')
param parPrivateDnsResourceGroupId string = ''

@description('List of Private DNS Zones to audit under the Corp Management Group. This overwrites default values.')
param parPrivateDnsZonesNamesToAuditInCorp array = []

@description('Disable all default ALZ policies.')
param parDisableAlzDefaultPolicies bool = false

@description('Disable all default sovereign policies.')
param parDisableSlzDefaultPolicies bool = false

@description('Tag name for excluding VMs from this policy’s scope.')
param parVmBackupExclusionTagName string = ''

@description('Tag value for excluding VMs from this policy’s scope. Comma-separated list for multiple values.')
param parVmBackupExclusionTagValue array = []

@description('Names of policy assignments to exclude. Found in Assigning Policies documentation.')
param parExcludedPolicyAssignments array = []

@description('Opt out of deployment telemetry.')
param parTelemetryOptOut bool = false

var varLogAnalyticsWorkspaceName = split(parLogAnalyticsWorkspaceResourceId, '/')[8]

var varLogAnalyticsWorkspaceResourceGroupName = split(parLogAnalyticsWorkspaceResourceId, '/')[4]

var varLogAnalyticsWorkspaceSubscription = split(parLogAnalyticsWorkspaceResourceId, '/')[2]

var varUserAssignedManagedIdentityResourceName = split(parUserAssignedManagedIdentityResourceId, '/')[8]

// Customer Usage Attribution Id Telemetry
var varCuaid = '98cef979-5a6b-403b-83c7-10c8f04ac9a2'

// ZTN Telemetry
var varZtnP1CuaId = '4eaba1fc-d30a-4e63-a57f-9e6c3d86a318'
//var varZtnP1Trigger = ((!contains(parExcludedPolicyAssignments, varPolicyAssignmentDenySubnetWithoutNsg.libDefinition.name)) && (!contains(parExcludedPolicyAssignments, varPolicyAssignmentDenyStoragehttp.libDefinition.name))) ? true : false

// **Variables**
// Orchestration Module Variables
var varDeploymentNameWrappers = {
  basePrefix: 'ALZBicep'
  #disable-next-line no-loc-expr-outside-params //Policies resources are not deployed to a region, like other resources, but the metadata is stored in a region hence requiring this to keep input parameters reduced. See https://github.com/Azure/ALZ-Bicep/wiki/FAQ#why-are-some-linter-rules-disabled-via-the-disable-next-line-bicep-function for more information
  baseSuffixTenantAndManagementGroup: '${deployment().location}-${uniqueString(deployment().location, parTopLevelManagementGroupPrefix)}'
}

var varModuleDeploymentNames = {
  //modPolicyAssignment
    modPolicyAssignmentLzsCorpDenyPrivateDNSZones: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyPrivateDNSZones-corp-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
}

// Policy Assignments Modules Variables


var varPolicyAssignmentDenyPrivateDNSZones = {
  definitionId: '${varTopLevelManagementGroupResourceId}/providers/Microsoft.Authorization/policyDefinitions/Deny-Private-DNS-Zones'
  libDefinition: loadJsonContent('../../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_private_dns_zones.tmpl.json')
}


// RBAC Role Definitions Variables - Used For Policy Assignments
var varRbacRoleDefinitionIds = {
  owner: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  networkContributor: '4d97b98b-1d4f-4787-a291-c67834d212e7'
  aksContributor: 'ed7f3fbd-7b88-4dd4-9017-9adb7ce333f8'
  logAnalyticsContributor: '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
  sqlSecurityManager: '056cd41c-7e88-42e1-933e-88ba6a50c9c3'
  vmContributor: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
  monitoringContributor: '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
  aksPolicyAddon: '18ed5180-3e48-46fd-8541-4ea054d57064'
  sqlDbContributor: '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec'
  backupContributor: '5e467623-bb1f-42f4-a55d-6e525e11384b'
  rbacSecurityAdmin: 'fb1c8493-542b-48eb-b624-b4c8fea62acd'
  reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  managedIdentityOperator: 'f1a07417-d97a-45cb-824c-7a7467783830'
  connectedMachineResourceAdministrator: 'cd570a14-e51a-42ad-bac8-bafd67325302'
}

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

var varCorpManagementGroupIdsFiltered = parLandingZoneMgConfidentialEnable ? varCorpManagementGroupIds : filter(varCorpManagementGroupIds, mg => !contains(toLower(mg), 'confidential'))

var varTopLevelManagementGroupResourceId = '/providers/Microsoft.Management/managementGroups/${varManagementGroupIds.intRoot}'

// Deploy-Private-DNS-Zones Variables

var varPrivateDnsZonesResourceGroupSubscriptionId = !empty(parPrivateDnsResourceGroupId) ? split(parPrivateDnsResourceGroupId, '/')[2] : ''

var varPrivateDnsZonesBaseResourceId = '${parPrivateDnsResourceGroupId}/providers/Microsoft.Network/privateDnsZones/'



// **Scope**
targetScope = 'managementGroup'



// Modules - Policy Assignments - Intermediate Root Management Group

// Modules - Policy Assignments - Platform Management Group


// Modules - Policy Assignments - Connectivity Management Group


// Modules - Policy Assignments - Identity Management Group


// Modules - Policy Assignments - Management Management Group


// Modules - Policy Assignments - Landing Zones Management Group


// Modules - Policy Assignments - Corp Management Group
// Module - Policy Assignment - Deny-Public-IP-On-NIC
module modPolicyAssignmentLzsCorpDenyPrivateDNSZones '../../../policy/assignments/policyAssignmentManagementGroup.bicep' = [for mgScope in varCorpManagementGroupIdsFiltered: if (!contains(parExcludedPolicyAssignments, varPolicyAssignmentDenyPrivateDNSZones.libDefinition.name) && parLandingZoneChildrenMgAlzDefaultsEnable) {
  scope: managementGroup(mgScope)
  name: varModuleDeploymentNames.modPolicyAssignmentLzsCorpDenyPrivateDNSZones
  params: {
    parPolicyAssignmentDefinitionId: varPolicyAssignmentDenyPrivateDNSZones.definitionId
    parPolicyAssignmentName: varPolicyAssignmentDenyPrivateDNSZones.libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignmentDenyPrivateDNSZones.libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignmentDenyPrivateDNSZones.libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignmentDenyPrivateDNSZones.libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignmentDenyPrivateDNSZones.libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: parDisableAlzDefaultPolicies ? 'DoNotEnforce' : varPolicyAssignmentDenyPrivateDNSZones.libDefinition.properties.enforcementMode
    parTelemetryOptOut: parTelemetryOptOut
  }
}]

// Modules - Policy Assignments - Confidential Online Management Group

// Modules - Policy Assignments - Confidential Corp Management Group


// Modules - Policy Assignments - Decommissioned Management Group


// Modules - Policy Assignments - Sandbox Management Group


// // The following module is used to deploy the policy exemptions
// module modPolicyExemptionsConfidentialOnline '../../exemptions/policyExemptions.bicep' = if (parLandingZoneMgConfidentialEnable) {
//   scope: managementGroup(varManagementGroupIds.landingZonesConfidentialOnline)
//   name: take('${parTopLevelManagementGroupPrefix}-deploy-policy-exemptions${parTopLevelManagementGroupSuffix}', 64)
//   params: {
//     parPolicyAssignmentId: modPolicyAssignmentIntRootEnforceSovereigntyGlobal.outputs.outPolicyAssignmentId
//     parPolicyDefinitionReferenceIds: ['AllowedLocationsForResourceGroups', 'AllowedLocations']
//     parExemptionName: 'Confidential-Online-Location-Exemption'
//     parExemptionDisplayName: 'Confidential Online Location Exemption'
//     parDescription: 'Exempt the confidential online management group from the SLZ Global location policies. The confidential management groups have their own location restrictions and this may result in a conflict if both sets are included.'
//   }
//   dependsOn: [modPolicyAssignmentLzsConfidentialOnlineEnforceSovereigntyConf]
// }

// // The following module is used to deploy the policy exemptions
// module modPolicyExemptionsConfidentialCorp '../../exemptions/policyExemptions.bicep' = if (parLandingZoneMgConfidentialEnable) {
//   scope: managementGroup(varManagementGroupIds.landingZonesConfidentialCorp)
//   name: take('${parTopLevelManagementGroupPrefix}-deploy-policy-exemptions${parTopLevelManagementGroupSuffix}', 64)
//   params: {
//     parPolicyAssignmentId: modPolicyAssignmentIntRootEnforceSovereigntyGlobal.outputs.outPolicyAssignmentId
//     parPolicyDefinitionReferenceIds: ['AllowedLocationsForResourceGroups', 'AllowedLocations']
//     parExemptionName: 'Confidential-Corp-Location-Exemption'
//     parExemptionDisplayName: 'Confidential Corp Location Exemption'
//     parDescription: 'Exempt the confidential corp management group from the SLZ Global Policies location policies. The confidential management groups have their own location restrictions and this may result in a conflict if both sets are included.'
//   }
//   dependsOn: [modPolicyAssignmentLzsConfidentialCorpEnforceSovereigntyConf]
// }
