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

@description('Apply platform policies to Platform group or child groups.')
param parPlatformMgAlzDefaultsEnable bool = true

@description('Assign policies to Confidential Corp and Online groups under Landing Zones.')
param parLandingZoneMgConfidentialEnable bool = false

@description('Resource ID of the Resource Group for Private DNS Zones. Empty to skip assigning the Deploy-Private-DNS-Zones policy.')
param parPrivateDnsResourceGroupId string = ''

@description('Resource IDs for Hub Network.')
param parHubNetworkResourceId string = ''

@description('Disable all custom ALZ policies.')
param parDisableAlzCustomPolicies bool = false

@description('Names of policy assignments to exclude. Found in Assigning Policies documentation.')
param parExcludedPolicyAssignments array = []

@description('Opt out of deployment telemetry.')
param parTelemetryOptOut bool = false

@description('Email address for Microsoft Defender for Cloud alerts.')
param parMsDefenderForCloudEmailSecurityContact string = 'security_contact@replace_me.com'

@description('Location of Log Analytics Workspace & Automation Account.')
param parLogAnalyticsWorkSpaceAndAutomationAccountLocation string = 'germanywestcentral'

@description('Resource ID of Log Analytics Workspace.')
param parLogAnalyticsWorkspaceResourceId string = ''

@description('Disable all default ALZ policies.')
param parDisableAlzDefaultPolicies bool = false

@description('Location of Log Analytics Workspace & Automation Account.')
param parPlatformPrimaryLocation string = 'germanywestcentral'

@description('Resource ID of Logging Storage Account.')
param parLogStorageAccountResourceId string = ''

@description('Resource ID of Network Watcher Resource Id.')
param parNetworkWatcherResourceId string = ''

// **Variables**
// Orchestration Module Variables
var varDeploymentNameWrappers = {
  basePrefix: 'ALZBicep'
  #disable-next-line no-loc-expr-outside-params //Policies resources are not deployed to a region, like other resources, but the metadata is stored in a region hence requiring this to keep input parameters reduced. See https://github.com/Azure/ALZ-Bicep/wiki/FAQ#why-are-some-linter-rules-disabled-via-the-disable-next-line-bicep-function for more information
  baseSuffixTenantAndManagementGroup: '${deployment().location}-${uniqueString(deployment().location, parTopLevelManagementGroupPrefix)}'
}

var varModuleDeploymentNames = {
    modPolicyAssignmentIntRootDeployMdfcConfig: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployMDFCConfig-intRoot-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolicyAssignmentIntRootDeployBlobServicesDiagSettingsToLogAnalytics: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployBlobServicesDiagSettingsToLogAnalytics-intRoot-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolicyAssignmentIntRootAuditFlowLogsVnet: take('${varDeploymentNameWrappers.basePrefix}-polAssi-auditFlowLogsVnet-intRoot-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolicyAssignmentLzsCorpDenyPrivateDNSZones: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyPrivateDNSZones-corp-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolicyAssignmentIdentDenyVnetPeeringNonApprovedVNets: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyVnetPeeringtoNonApprovedVnets-identity-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolicyAssignmentPlatformDeployVnetFlowLog: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployVnetFlowLog-platform-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)



}

// Policy Assignments Modules Variables


var varPolicyAssignmentDenyPrivateDNSZones = {
  definitionId: '${varTopLevelManagementGroupResourceId}/providers/Microsoft.Authorization/policyDefinitions/Deny-Private-DNS-Zones'
  libDefinition: loadJsonContent('../../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_private_dns_zones.tmpl.json')
}

var varPolicyAssignmentDenyVnetPeeringNonApprovedVNets = {
  definitionId: '${varTopLevelManagementGroupResourceId}/providers/Microsoft.Authorization/policyDefinitions/Deny-VNET-Peering-To-Non-Approved-VNETs'
  libDefinition: loadJsonContent('../../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_vnet_peering_to_non-approved-vnets.tmpl.json')
}

var varPolicyAssignmentDeployMDFCConfig = {
  definitionId: '${varTopLevelManagementGroupResourceId}/providers/Microsoft.Authorization/policySetDefinitions/Deploy-MDFC-Config_20240319'
  libDefinition: loadJsonContent('../../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_mdfc_config.tmpl.json')
}

var varPolicyAssignmentDeployBlobServicesDiagSettingsToLogAnalytics = {
  definitionId: '/providers/Microsoft.Authorization/policyDefinitions/b4fe1a3b-0715-4c6c-a5ea-ffc33cf823cb'
  libDefinition: loadJsonContent('../../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_blob_diag_setting.tmpl.json')
}

var varPolicyAssignmentDeployVnetFlowLog = {
  definitionId: '/providers/microsoft.authorization/policydefinitions/cd6f7aff-2845-4dab-99f2-6d1754a754b0'
  libDefinition: loadJsonContent('../../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_vnet_flow_logs.tmpl.json')
}

var varPolicyAssignAuditFlowLogsVnet = {
  definitionId: '/providers/Microsoft.Authorization/policyDefinitions/4c3c6c5f-0d47-4402-99b8-aa543dd8bcee'
  libDefinition: loadJsonContent('../../../policy/assignments/lib/policy_assignments/policy_assignment_es_audit_flow_logs_vnets.tmpl.json')
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

// Module - Policy Assignment - Deploy-MDFC-Config-H224
module modPolicyAssignmentIntRootDeployMdfcConfig '../../../policy/assignments/policyAssignmentManagementGroup.bicep' = if (!contains(parExcludedPolicyAssignments, varPolicyAssignmentDeployMDFCConfig.libDefinition.name)) {
  scope: managementGroup(varManagementGroupIds.intRoot)
  name: varModuleDeploymentNames.modPolicyAssignmentIntRootDeployMdfcConfig
  params: {
    parPolicyAssignmentDefinitionId: varPolicyAssignmentDeployMDFCConfig.definitionId
    parPolicyAssignmentName: varPolicyAssignmentDeployMDFCConfig.libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignmentDeployMDFCConfig.libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignmentDeployMDFCConfig.libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignmentDeployMDFCConfig.libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      emailSecurityContact: {
        value: parMsDefenderForCloudEmailSecurityContact
      }
      ascExportResourceGroupLocation: {
        value: parLogAnalyticsWorkSpaceAndAutomationAccountLocation
      }
      logAnalytics: {
        value: parLogAnalyticsWorkspaceResourceId
      }
      enableAscForOssDb : {
        value: 'Disabled'
      }
      enableAscForSql : {
        value: 'Disabled'
      }
      enableAscForAppServices : {
        value: 'Disabled'
      }
      enableAscForStorage : {
        value: 'Disabled'
      }
      enableAscForContainers : {
        value: 'Disabled'
      }
      enableAscForSqlOnVm : {
        value: 'Disabled'
      }
      enableAscForCosmosDbs : {
        value: 'Disabled'
      }
      enableAscForCspm : {
        value: 'Disabled'
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignmentDeployMDFCConfig.libDefinition.identity.type
    parPolicyAssignmentIdentityRoleDefinitionIds: [
      varRbacRoleDefinitionIds.owner
    ]
    parPolicyAssignmentEnforcementMode: parDisableAlzDefaultPolicies ? 'DoNotEnforce' : varPolicyAssignmentDeployMDFCConfig.libDefinition.properties.enforcementMode
    parTelemetryOptOut: parTelemetryOptOut
  }
}

// Module - Policy Assignment - Deploy-Blob-Diag-Setting
module modPolicyAssignmentIntRootDeployBlobServicesDiagSettingsToLogAnalytics '../../../policy/assignments/policyAssignmentManagementGroup.bicep' = if (!contains(parExcludedPolicyAssignments, varPolicyAssignmentDeployBlobServicesDiagSettingsToLogAnalytics.libDefinition.name)) {
  scope: managementGroup(varManagementGroupIds.intRoot)
  name: varModuleDeploymentNames.modPolicyAssignmentIntRootDeployBlobServicesDiagSettingsToLogAnalytics
  params: {
    parPolicyAssignmentDefinitionId: varPolicyAssignmentDeployBlobServicesDiagSettingsToLogAnalytics.definitionId
    parPolicyAssignmentName: varPolicyAssignmentDeployBlobServicesDiagSettingsToLogAnalytics.libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignmentDeployBlobServicesDiagSettingsToLogAnalytics.libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignmentDeployBlobServicesDiagSettingsToLogAnalytics.libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignmentDeployBlobServicesDiagSettingsToLogAnalytics.libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      logAnalytics: {
        value: parLogAnalyticsWorkspaceResourceId
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignmentDeployBlobServicesDiagSettingsToLogAnalytics.libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: parDisableAlzDefaultPolicies ? 'DoNotEnforce' : varPolicyAssignmentDeployBlobServicesDiagSettingsToLogAnalytics.libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIds: [
      varRbacRoleDefinitionIds.logAnalyticsContributor
      varRbacRoleDefinitionIds.monitoringContributor
    ]
    parTelemetryOptOut: parTelemetryOptOut
  }
}

// Module - Policy Assignment - Audit-Flow-Logs-Vnet
module modPolicyAssignmentIntRootAuditFlowLogsVnet '../../../policy/assignments/policyAssignmentManagementGroup.bicep' = if (!contains(parExcludedPolicyAssignments, varPolicyAssignAuditFlowLogsVnet.libDefinition.name)) {
  scope: managementGroup(varManagementGroupIds.intRoot)
  name: varModuleDeploymentNames.modPolicyAssignmentIntRootAuditFlowLogsVnet
  params: {
    parPolicyAssignmentDefinitionId: varPolicyAssignAuditFlowLogsVnet.definitionId
    parPolicyAssignmentName: varPolicyAssignAuditFlowLogsVnet.libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignAuditFlowLogsVnet.libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignAuditFlowLogsVnet.libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignAuditFlowLogsVnet.libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignAuditFlowLogsVnet.libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: parDisableAlzDefaultPolicies ? 'DoNotEnforce' : varPolicyAssignAuditFlowLogsVnet.libDefinition.properties.enforcementMode
    parTelemetryOptOut: parTelemetryOptOut
  }
}


// Modules - Policy Assignments - Platform Management Group
// Module - Policy Assignment - Deploy-Vnet-Flow-Logs
module modPolicyAssignmentPlatformDeployVnetFlowLogs '../../../policy/assignments/policyAssignmentManagementGroup.bicep' = if (!contains(parExcludedPolicyAssignments, varPolicyAssignmentDeployVnetFlowLog.libDefinition.name)) {
  scope: managementGroup(varManagementGroupIds.platform)
  name: varModuleDeploymentNames.modPolicyAssignmentPlatformDeployVnetFlowLog
  params: {
    parPolicyAssignmentDefinitionId: varPolicyAssignmentDeployVnetFlowLog.definitionId
    parPolicyAssignmentName: varPolicyAssignmentDeployVnetFlowLog.libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignmentDeployVnetFlowLog.libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignmentDeployVnetFlowLog.libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignmentDeployVnetFlowLog.libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: { 
      vnetRegion: {
        value: parPlatformPrimaryLocation
      }
      storageId: {
        value: parLogStorageAccountResourceId
      }
      networkWatcherName: {
        value: parNetworkWatcherResourceId
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignmentDeployVnetFlowLog.libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: parDisableAlzCustomPolicies ? 'DoNotEnforce' : varPolicyAssignmentDeployVnetFlowLog.libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIds: [
      varRbacRoleDefinitionIds.contributor
    ]
    parTelemetryOptOut: parTelemetryOptOut
  }
}


// Modules - Policy Assignments - Connectivity Management Group


// Modules - Policy Assignments - Identity Management Group
// Module - Policy Assignment - Deny-VNET-Peering-To-Non-Approved-VNETs
module modPolicyAssignmentIdentDenyVnetPeeringNonApprovedVNets '../../../policy/assignments/policyAssignmentManagementGroup.bicep' = if (!contains(parExcludedPolicyAssignments, varPolicyAssignmentDenyVnetPeeringNonApprovedVNets.libDefinition.name)) {
  scope: managementGroup(varManagementGroupIds.platformIdentity)
  name: varModuleDeploymentNames.modPolicyAssignmentIdentDenyVnetPeeringNonApprovedVNets
  params: {
    parPolicyAssignmentDefinitionId: varPolicyAssignmentDenyVnetPeeringNonApprovedVNets.definitionId
    parPolicyAssignmentName: varPolicyAssignmentDenyVnetPeeringNonApprovedVNets.libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignmentDenyVnetPeeringNonApprovedVNets.libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignmentDenyVnetPeeringNonApprovedVNets.libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignmentDenyVnetPeeringNonApprovedVNets.libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: { 
      allowedVnets: {
        value: [parHubNetworkResourceId]
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignmentDenyVnetPeeringNonApprovedVNets.libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: parDisableAlzCustomPolicies ? 'DoNotEnforce' : varPolicyAssignmentDenyVnetPeeringNonApprovedVNets.libDefinition.properties.enforcementMode
    parTelemetryOptOut: parTelemetryOptOut
  }
}



// Modules - Policy Assignments - Management Management Group


// Modules - Policy Assignments - Landing Zones Management Group


// Modules - Policy Assignments - Corp Management Group
// Module - Policy Assignment - Deny-Public-IP-On-NIC
module modPolicyAssignmentLzsCorpDenyPrivateDNSZones '../../../policy/assignments/policyAssignmentManagementGroup.bicep' = [for mgScope in varCorpManagementGroupIdsFiltered: if (!contains(parExcludedPolicyAssignments, varPolicyAssignmentDenyPrivateDNSZones.libDefinition.name)) {
  scope: managementGroup(mgScope)
  name: varModuleDeploymentNames.modPolicyAssignmentLzsCorpDenyPrivateDNSZones
  params: {
    parPolicyAssignmentDefinitionId: varPolicyAssignmentDenyPrivateDNSZones.definitionId
    parPolicyAssignmentName: varPolicyAssignmentDenyPrivateDNSZones.libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignmentDenyPrivateDNSZones.libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignmentDenyPrivateDNSZones.libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignmentDenyPrivateDNSZones.libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignmentDenyPrivateDNSZones.libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: parDisableAlzCustomPolicies ? 'DoNotEnforce' : varPolicyAssignmentDenyPrivateDNSZones.libDefinition.properties.enforcementMode
    parTelemetryOptOut: parTelemetryOptOut
  }
}]

// Modules - Policy Assignments - Confidential Online Management Group

// Modules - Policy Assignments - Confidential Corp Management Group


// Modules - Policy Assignments - Decommissioned Management Group


// Modules - Policy Assignments - Sandbox Management Group


