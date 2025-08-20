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

@description('Location of Private DNS Zones.')
param parPrivateDnsZonesLocation string = ''

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

@description('Specify the minimum number of days that a secret should remain usable prior to expiration.')
param parSecretsMinimumDaysBeforeExpiration int = 90

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
    modPolicyAssignmentIntRootAuditTrafficAnalytics: take('${varDeploymentNameWrappers.basePrefix}-polAssi-auditTrafficAnalytics-intRoot-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolicyAssignmentLzsCorpDenyPrivateDNSZones: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyPrivateDNSZones-corp-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolicyAssignmentIdentDenyVnetPeeringNonApprovedVNets: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyVnetPeeringtoNonApprovedVnets-identity-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolicyAssignmentPlatformDeployVnetFlowLog: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployVnetFlowLog-platform-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolicyAssignmentPlatformDeployTrafficAnalytics: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployTrafficAnalytics-platform-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolicyAssignmentIdentAuditKVSecretExpire: take('${varDeploymentNameWrappers.basePrefix}-polAssi-auditKVSecretExpire-identity-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolicyAssignmentPlatformDeployDiagFirewall: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployDiagnosticsFirewall-conn-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
    modPolAssiLzsOnlineDeployPrivateDnsZones: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployPrivDns-online-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)

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

var varPolicyAssignAuditTrafficAnalytics = {
  definitionId: '/providers/Microsoft.Authorization/policyDefinitions/2f080164-9f4d-497e-9db6-416dc9f7b48a'
  libDefinition: loadJsonContent('../../../policy/assignments/lib/policy_assignments/policy_assignment_es_audit_traffic_analytics.tmpl.json')
}

var varPolicyAssignmentDeployTrafficAnalytics = {
  definitionId: '/providers/Microsoft.Authorization/policyDefinitions/3e9965dc-cc13-47ca-8259-a4252fd0cf7b'
  libDefinition: loadJsonContent('../../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_traffic_analytics.tmpl.json')
}

var varPolicyAssignmentAuditKVSecretExpire = {
  definitionId: '/providers/Microsoft.Authorization/policyDefinitions/b0eb591a-5e70-4534-a8bf-04b9c489584a'
  libDefinition: loadJsonContent('../../../policy/assignments/lib/policy_assignments/policy_assignment_es_audit_keyvault_secret_expiration.tmpl.json')
}
var varPolicyAssignmentDeployDiagFirewall = {
  definitionId: '${varTopLevelManagementGroupResourceId}/providers/Microsoft.Authorization/policyDefinitions/Deploy-Diagnostics-Firewall'
  libDefinition: loadJsonContent('../../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_diag_firewall.tmpl.json')
}

var varPolicyAssignmentDeployPrivateDNSZones = {
  definitionId: '${varTopLevelManagementGroupResourceId}/providers/Microsoft.Authorization/policySetDefinitions/Deploy-Private-DNS-Zones'
  libDefinition: loadJsonContent('../../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_private_dns_zones.tmpl.json')
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

var varOnlineManagementGroupIds = [
   varManagementGroupIds.landingZonesOnline
]

var varCorpManagementGroupIdsFiltered = parLandingZoneMgConfidentialEnable ? varCorpManagementGroupIds : filter(varCorpManagementGroupIds, mg => !contains(toLower(mg), 'confidential'))

var varTopLevelManagementGroupResourceId = '/providers/Microsoft.Management/managementGroups/${varManagementGroupIds.intRoot}'

// Deploy-Private-DNS-Zones Variables

var varPrivateDnsZonesResourceGroupSubscriptionId = !empty(parPrivateDnsResourceGroupId) ? split(parPrivateDnsResourceGroupId, '/')[2] : ''

var varPrivateDnsZonesBaseResourceId = '${parPrivateDnsResourceGroupId}/providers/Microsoft.Network/privateDnsZones/'

var varGeoCodes = {
  australiacentral: 'acl'
  australiacentral2: 'acl2'
  australiaeast: 'ae'
  australiasoutheast: 'ase'
  brazilsoutheast: 'bse'
  brazilsouth: 'brs'
  canadacentral: 'cnc'
  canadaeast: 'cne'
  centralindia: 'inc'
  centralus: 'cus'
  centraluseuap: 'ccy'
  chilecentral: 'clc'
  eastasia: 'ea'
  eastus: 'eus'
  eastus2: 'eus2'
  eastus2euap: 'ecy'
  francecentral: 'frc'
  francesouth: 'frs'
  germanynorth: 'gn'
  germanywestcentral: 'gwc'
  israelcentral: 'ilc'
  italynorth: 'itn'
  japaneast: 'jpe'
  japanwest: 'jpw'
  koreacentral: 'krc'
  koreasouth: 'krs'
  malaysiasouth: 'mys'
  malaysiawest: 'myw'
  mexicocentral: 'mxc'
  newzealandnorth: 'nzn'
  northcentralus: 'ncus'
  northeurope: 'ne'
  norwayeast: 'nwe'
  norwaywest: 'nww'
  polandcentral: 'plc'
  qatarcentral: 'qac'
  southafricanorth: 'san'
  southafricawest: 'saw'
  southcentralus: 'scus'
  southeastasia: 'sea'
  southindia: 'ins'
  spaincentral: 'spc'
  swedencentral: 'sdc'
  swedensouth: 'sds'
  switzerlandnorth: 'szn'
  switzerlandwest: 'szw'
  taiwannorth: 'twn'
  uaecentral: 'uac'
  uaenorth: 'uan'
  uksouth: 'uks'
  ukwest: 'ukw'
  westcentralus: 'wcus'
  westeurope: 'we'
  westindia: 'inw'
  westus: 'wus'
  westus2: 'wus2'
  westus3: 'wus3'
}

var varSelectedGeoCode = !empty(parPrivateDnsZonesLocation) ? varGeoCodes[parPrivateDnsZonesLocation] : null

var varPrivateDnsZonesFinalResourceIds = {
  azureAcrPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.azurecr.io'
  azureAppPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.azconfig.io'
  azureAppServicesPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.azurewebsites.net'
  azureArcGuestconfigurationPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.guestconfiguration.azure.com'
  azureArcHybridResourceProviderPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.his.arc.azure.com'
  azureArcKubernetesConfigurationPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.dp.kubernetesconfiguration.azure.com'
  azureAsrPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.siterecovery.windowsazure.com'
  azureAutomationDSCHybridPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.azure-automation.net'
  azureAutomationWebhookPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.azure-automation.net'
  azureBatchPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.batch.azure.com'
  azureBotServicePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.directline.botframework.com'
  azureCognitiveSearchPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.search.windows.net'
  azureCognitiveServicesPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.cognitiveservices.azure.com'
  azureCosmosCassandraPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.cassandra.cosmos.azure.com'
  azureCosmosGremlinPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.gremlin.cosmos.azure.com'
  azureCosmosMongoPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.mongo.cosmos.azure.com'
  azureCosmosSQLPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.documents.azure.com'
  azureCosmosTablePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.table.cosmos.azure.com'
  azureDataFactoryPortalPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.adf.azure.com'
  azureDataFactoryPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.datafactory.azure.net'
  azureDatabricksPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.azuredatabricks.net'
  azureDiskAccessPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.blob.core.windows.net'
  azureEventGridDomainsPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.eventgrid.azure.net'
  azureEventGridTopicsPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.eventgrid.azure.net'
  azureEventHubNamespacePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.servicebus.windows.net'
  azureFilePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.afs.azure.net'
  azureHDInsightPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.azurehdinsight.net'
  azureIotCentralPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.azureiotcentral.com'
  azureIotDeviceupdatePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.azure-devices.net'
  azureIotHubsPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.azure-devices.net'
  azureIotPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.azure-devices-provisioning.net'
  azureKeyVaultPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.vaultcore.azure.net'
  azureMachineLearningWorkspacePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.api.azureml.ms'
  azureMachineLearningWorkspaceSecondPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.notebooks.azure.net'
  azureManagedGrafanaWorkspacePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.grafana.azure.com'
  azureMediaServicesKeyPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.media.azure.net'
  azureMediaServicesLivePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.media.azure.net'
  azureMediaServicesStreamPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.media.azure.net'
  azureMigratePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.prod.migration.windowsazure.com'
  azureMonitorPrivateDnsZoneId1: '${varPrivateDnsZonesBaseResourceId}privatelink.monitor.azure.com'
  azureMonitorPrivateDnsZoneId2: '${varPrivateDnsZonesBaseResourceId}privatelink.oms.opinsights.azure.com'
  azureMonitorPrivateDnsZoneId3: '${varPrivateDnsZonesBaseResourceId}privatelink.ods.opinsights.azure.com'
  azureMonitorPrivateDnsZoneId4: '${varPrivateDnsZonesBaseResourceId}privatelink.agentsvc.azure-automation.net'
  azureMonitorPrivateDnsZoneId5: '${varPrivateDnsZonesBaseResourceId}privatelink.blob.core.windows.net'
  azureRedisCachePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.redis.cache.windows.net'
  azureServiceBusNamespacePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.servicebus.windows.net'
  azureSignalRPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.service.signalr.net'
  azureSiteRecoveryBackupPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.${varSelectedGeoCode}.backup.windowsazure.com'
  azureSiteRecoveryBlobPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.blob.core.windows.net'
  azureSiteRecoveryQueuePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.queue.core.windows.net'
  azureStorageBlobPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.blob.core.windows.net'
  azureStorageBlobSecPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.blob.core.windows.net'
  azureStorageDFSPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.dfs.core.windows.net'
  azureStorageDFSSecPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.dfs.core.windows.net'
  azureStorageFilePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.file.core.windows.net'
  azureStorageQueuePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.queue.core.windows.net'
  azureStorageQueueSecPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.queue.core.windows.net'
  azureStorageStaticWebPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.web.core.windows.net'
  azureStorageStaticWebSecPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.web.core.windows.net'
  azureStorageTablePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.table.core.windows.net'
  azureStorageTableSecondaryPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.table.core.windows.net'
  azureSynapseDevPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.dev.azuresynapse.net'
  azureSynapseSQLPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.sql.azuresynapse.net'
  azureSynapseSQLODPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.sql.azuresynapse.net'
  azureVirtualDesktopHostpoolPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.wvd.microsoft.com'
  azureVirtualDesktopWorkspacePrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.wvd.microsoft.com'
  azureWebPrivateDnsZoneId: '${varPrivateDnsZonesBaseResourceId}privatelink.webpubsub.azure.com'
}

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

// Module - Policy Assignment - Audit-Traffic-Analytics

module modPolicyAssignmentIntRootAuditTrafficAnalytics '../../../policy/assignments/policyAssignmentManagementGroup.bicep' = if (!contains(parExcludedPolicyAssignments, varPolicyAssignAuditTrafficAnalytics.libDefinition.name)) {
  scope: managementGroup(varManagementGroupIds.intRoot)
  name: varModuleDeploymentNames.modPolicyAssignmentIntRootAuditTrafficAnalytics
  params: {
    parPolicyAssignmentDefinitionId: varPolicyAssignAuditTrafficAnalytics.definitionId
    parPolicyAssignmentName: varPolicyAssignAuditTrafficAnalytics.libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignAuditTrafficAnalytics.libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignAuditTrafficAnalytics.libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignAuditTrafficAnalytics.libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignAuditTrafficAnalytics.libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: parDisableAlzDefaultPolicies ? 'DoNotEnforce' : varPolicyAssignAuditTrafficAnalytics.libDefinition.properties.enforcementMode
    parTelemetryOptOut: parTelemetryOptOut
  }
}

// Modules - Policy Assignments - Platform Management Group

// Module - Policy Assignment - Deploy-Diagnostics-Firewall
module modPolicyAssignmentPlatformDeployDiagFirewall '../../../policy/assignments/policyAssignmentManagementGroup.bicep' = if (!contains(parExcludedPolicyAssignments, varPolicyAssignmentDeployDiagFirewall.libDefinition.name)) {
  scope: managementGroup(varManagementGroupIds.platform)
  name: varModuleDeploymentNames.modPolicyAssignmentPlatformDeployDiagFirewall
  params: {
    parPolicyAssignmentDefinitionId: varPolicyAssignmentDeployDiagFirewall.definitionId
    parPolicyAssignmentName: varPolicyAssignmentDeployDiagFirewall.libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignmentDeployDiagFirewall.libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignmentDeployDiagFirewall.libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignmentDeployDiagFirewall.libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      logAnalytics: {
        value: parLogAnalyticsWorkspaceResourceId
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignmentDeployMDFCConfig.libDefinition.identity.type
    parPolicyAssignmentIdentityRoleDefinitionIds: [
      varRbacRoleDefinitionIds.logAnalyticsContributor
      varRbacRoleDefinitionIds.monitoringContributor
    ]
    parPolicyAssignmentEnforcementMode: parDisableAlzDefaultPolicies ? 'DoNotEnforce' : varPolicyAssignmentDeployMDFCConfig.libDefinition.properties.enforcementMode
    parTelemetryOptOut: parTelemetryOptOut
  }
}

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

// Module - Policy Assignment - Deploy-Vnet-Flow-Logs
module modPolicyAssignmentPlatformDeployTrafficAnalytics '../../../policy/assignments/policyAssignmentManagementGroup.bicep' = if (!contains(parExcludedPolicyAssignments, varPolicyAssignmentDeployTrafficAnalytics.libDefinition.name)) {
  scope: managementGroup(varManagementGroupIds.platform)
  name: varModuleDeploymentNames.modPolicyAssignmentPlatformDeployTrafficAnalytics
  params: {
    parPolicyAssignmentDefinitionId: varPolicyAssignmentDeployTrafficAnalytics.definitionId
    parPolicyAssignmentName: varPolicyAssignmentDeployTrafficAnalytics.libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignmentDeployTrafficAnalytics.libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignmentDeployTrafficAnalytics.libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignmentDeployTrafficAnalytics.libDefinition.properties.parameters
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
      workspaceResourceId: {
        value: parLogAnalyticsWorkspaceResourceId
      }
      workspaceRegion: {
        value: parPlatformPrimaryLocation
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignmentDeployTrafficAnalytics.libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: parDisableAlzCustomPolicies ? 'DoNotEnforce' : varPolicyAssignmentDeployTrafficAnalytics.libDefinition.properties.enforcementMode
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

// Module - Policy Assignment - Audit-KV-Secret-Expire
module modPolicyAssignmentIdentAuditKeyVaultSecretExpiration '../../../policy/assignments/policyAssignmentManagementGroup.bicep' = if (!contains(parExcludedPolicyAssignments, varPolicyAssignmentAuditKVSecretExpire.libDefinition.name)) {
  scope: managementGroup(varManagementGroupIds.platformIdentity)
  name: varModuleDeploymentNames.modPolicyAssignmentIdentAuditKVSecretExpire
  params: {
    parPolicyAssignmentDefinitionId: varPolicyAssignmentAuditKVSecretExpire.definitionId
    parPolicyAssignmentName: varPolicyAssignmentAuditKVSecretExpire.libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignmentAuditKVSecretExpire.libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignmentAuditKVSecretExpire.libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignmentAuditKVSecretExpire.libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: { 
      minimumDaysBeforeExpiration: {
        value: parSecretsMinimumDaysBeforeExpiration
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignmentAuditKVSecretExpire.libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: parDisableAlzDefaultPolicies ? 'DoNotEnforce' : varPolicyAssignmentAuditKVSecretExpire.libDefinition.properties.enforcementMode
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

// Modules - Policy Assignments - Online Management Group
// Module - Policy Assignment - Deploy-Private-DNS-Zones
module modPolAssiConnDeployPrivateDnsZones '../../../policy/assignments/policyAssignmentManagementGroup.bicep' = [for mgScope in varOnlineManagementGroupIds: if (!contains(parExcludedPolicyAssignments, varPolicyAssignmentDeployPrivateDNSZones.libDefinition.name)) {
  scope: managementGroup(mgScope)
  name: varModuleDeploymentNames.modPolAssiLzsOnlineDeployPrivateDnsZones
  params: {
    parPolicyAssignmentDefinitionId: varPolicyAssignmentDeployPrivateDNSZones.definitionId
    parPolicyAssignmentName: varPolicyAssignmentDeployPrivateDNSZones.libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignmentDeployPrivateDNSZones.libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignmentDeployPrivateDNSZones.libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignmentDeployPrivateDNSZones.libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      azureAcrPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureAcrPrivateDnsZoneId
      }
      azureAppPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureAppPrivateDnsZoneId
      }
      azureAppServicesPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureAppServicesPrivateDnsZoneId
      }
      azureArcGuestconfigurationPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureArcGuestconfigurationPrivateDnsZoneId
      }
      azureArcHybridResourceProviderPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureArcHybridResourceProviderPrivateDnsZoneId
      }
      azureArcKubernetesConfigurationPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureArcKubernetesConfigurationPrivateDnsZoneId
      }
      azureAsrPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureAsrPrivateDnsZoneId
      }
      azureAutomationDSCHybridPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureAutomationDSCHybridPrivateDnsZoneId
      }
      azureAutomationWebhookPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureAutomationWebhookPrivateDnsZoneId
      }
      azureBatchPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureBatchPrivateDnsZoneId
      }
      azureBotServicePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureBotServicePrivateDnsZoneId
      }
      azureCognitiveSearchPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureCognitiveSearchPrivateDnsZoneId
      }
      azureCognitiveServicesPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureCognitiveServicesPrivateDnsZoneId
      }
      azureCosmosCassandraPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureCosmosCassandraPrivateDnsZoneId
      }
      azureCosmosGremlinPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureCosmosGremlinPrivateDnsZoneId
      }
      azureCosmosMongoPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureCosmosMongoPrivateDnsZoneId
      }
      azureCosmosSQLPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureCosmosSQLPrivateDnsZoneId
      }
      azureCosmosTablePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureCosmosTablePrivateDnsZoneId
      }
      azureDataFactoryPortalPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureDataFactoryPortalPrivateDnsZoneId
      }
      azureDataFactoryPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureDataFactoryPrivateDnsZoneId
      }
      azureDatabricksPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureDatabricksPrivateDnsZoneId
      }
      azureDiskAccessPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureDiskAccessPrivateDnsZoneId
      }
      azureEventGridDomainsPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureEventGridDomainsPrivateDnsZoneId
      }
      azureEventGridTopicsPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureEventGridTopicsPrivateDnsZoneId
      }
      azureEventHubNamespacePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureEventHubNamespacePrivateDnsZoneId
      }
      azureFilePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureFilePrivateDnsZoneId
      }
      azureHDInsightPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureHDInsightPrivateDnsZoneId
      }
      azureIotCentralPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureIotCentralPrivateDnsZoneId
      }
      azureIotDeviceupdatePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureIotDeviceupdatePrivateDnsZoneId
      }
      azureIotHubsPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureIotHubsPrivateDnsZoneId
      }
      azureIotPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureIotPrivateDnsZoneId
      }
      azureKeyVaultPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureKeyVaultPrivateDnsZoneId
      }
      azureMachineLearningWorkspacePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureMachineLearningWorkspacePrivateDnsZoneId
      }
      azureMachineLearningWorkspaceSecondPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureMachineLearningWorkspaceSecondPrivateDnsZoneId
      }
      azureManagedGrafanaWorkspacePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureManagedGrafanaWorkspacePrivateDnsZoneId
      }
      azureMediaServicesKeyPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureMediaServicesKeyPrivateDnsZoneId
      }
      azureMediaServicesLivePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureMediaServicesLivePrivateDnsZoneId
      }
      azureMediaServicesStreamPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureMediaServicesStreamPrivateDnsZoneId
      }
      azureMigratePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureMigratePrivateDnsZoneId
      }
      azureMonitorPrivateDnsZoneId1: {
        value: varPrivateDnsZonesFinalResourceIds.azureMonitorPrivateDnsZoneId1
      }
      azureMonitorPrivateDnsZoneId2: {
        value: varPrivateDnsZonesFinalResourceIds.azureMonitorPrivateDnsZoneId2
      }
      azureMonitorPrivateDnsZoneId3: {
        value: varPrivateDnsZonesFinalResourceIds.azureMonitorPrivateDnsZoneId3
      }
      azureMonitorPrivateDnsZoneId4: {
        value: varPrivateDnsZonesFinalResourceIds.azureMonitorPrivateDnsZoneId4
      }
      azureMonitorPrivateDnsZoneId5: {
        value: varPrivateDnsZonesFinalResourceIds.azureMonitorPrivateDnsZoneId5
      }
      azureRedisCachePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureRedisCachePrivateDnsZoneId
      }
      azureServiceBusNamespacePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureServiceBusNamespacePrivateDnsZoneId
      }
      azureSignalRPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureSignalRPrivateDnsZoneId
      }
      azureSiteRecoveryBackupPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureSiteRecoveryBackupPrivateDnsZoneId
      }
      azureSiteRecoveryBlobPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureSiteRecoveryBlobPrivateDnsZoneId
      }
      azureSiteRecoveryQueuePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureSiteRecoveryQueuePrivateDnsZoneId
      }
      azureStorageBlobPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureStorageBlobPrivateDnsZoneId
      }
      azureStorageBlobSecPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureStorageBlobSecPrivateDnsZoneId
      }
      azureStorageDFSPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureStorageDFSPrivateDnsZoneId
      }
      azureStorageDFSSecPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureStorageDFSSecPrivateDnsZoneId
      }
      azureStorageFilePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureStorageFilePrivateDnsZoneId
      }
      azureStorageQueuePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureStorageQueuePrivateDnsZoneId
      }
      azureStorageQueueSecPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureStorageQueueSecPrivateDnsZoneId
      }
      azureStorageStaticWebPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureStorageStaticWebPrivateDnsZoneId
      }
      azureStorageStaticWebSecPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureStorageStaticWebSecPrivateDnsZoneId
      }
      azureStorageTablePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureStorageTablePrivateDnsZoneId
      }
      azureStorageTableSecondaryPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureStorageTableSecondaryPrivateDnsZoneId
      }
      azureSynapseDevPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureSynapseDevPrivateDnsZoneId
      }
      azureSynapseSQLPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureSynapseSQLPrivateDnsZoneId
      }
      azureSynapseSQLODPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureSynapseSQLODPrivateDnsZoneId
      }
      azureVirtualDesktopHostpoolPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureVirtualDesktopHostpoolPrivateDnsZoneId
      }
      azureVirtualDesktopWorkspacePrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureVirtualDesktopWorkspacePrivateDnsZoneId
      }
      azureWebPrivateDnsZoneId: {
        value: varPrivateDnsZonesFinalResourceIds.azureWebPrivateDnsZoneId
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignmentDeployPrivateDNSZones.libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: parDisableAlzDefaultPolicies ? 'DoNotEnforce' : varPolicyAssignmentDeployPrivateDNSZones.libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIds: [
      varRbacRoleDefinitionIds.networkContributor
    ]
    parPolicyAssignmentIdentityRoleAssignmentsSubs: [
      varPrivateDnsZonesResourceGroupSubscriptionId
    ]
    parTelemetryOptOut: parTelemetryOptOut
  }
}]

// Modules - Policy Assignments - Confidential Online Management Group

// Modules - Policy Assignments - Confidential Corp Management Group


// Modules - Policy Assignments - Decommissioned Management Group


// Modules - Policy Assignments - Sandbox Management Group


