targetScope = 'tenant'

@sys.description('Prefix used for the management group hierarchy. This management group will be created as part of the deployment.')
@minLength(2)
@maxLength(10)
param parTopLevelManagementGroupPrefix string = 'alz'

@sys.description('Optional suffix for the management group hierarchy. This suffix will be appended to management group names/IDs. Include a preceding dash if required. Example: -suffix')
@maxLength(10)
param parTopLevelManagementGroupSuffix string = ''

@description('Email address for Microsoft Defender for Cloud alerts.')
param parMsDefenderForCloudEmailSecurityContact string = 'security_contact@replace_me.com'

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

@description('Resource ID of the Resource Group for Private DNS Zones. Empty to skip assigning the Deploy-Private-DNS-Zones policy.')
param parPrivateDnsResourceGroupId string = ''

module modDefaultPolicyAssignment '../../ALZ-Bicep/infra-as-code/bicep/modules/policy/assignments/alzDefaults/alzDefaultPolicyAssignments.bicep' = {
  scope: managementGroup('${parTopLevelManagementGroupPrefix}${parTopLevelManagementGroupSuffix}')
  name: 'DefaultPolicyAssignment-${deployment().name}'
  params: {
    parTopLevelManagementGroupSuffix: parTopLevelManagementGroupSuffix
    parTopLevelManagementGroupPrefix: parTopLevelManagementGroupPrefix
    parDdosEnabled: false
    parLogAnalyticsWorkSpaceAndAutomationAccountLocation: deployment().location
    parLogAnalyticsWorkspaceResourceId: parLogAnalyticsWorkspaceResourceId
    parDataCollectionRuleVMInsightsResourceId: parDataCollectionRuleVMInsightsResourceId
    parDataCollectionRuleChangeTrackingResourceId: parDataCollectionRuleChangeTrackingResourceId
    parDataCollectionRuleMDFCSQLResourceId: parDataCollectionRuleMDFCSQLResourceId
    parUserAssignedManagedIdentityResourceId: parUserAssignedManagedIdentityResourceId
    parMsDefenderForCloudEmailSecurityContact: parMsDefenderForCloudEmailSecurityContact
    parPrivateDnsResourceGroupId: parPrivateDnsResourceGroupId
  }
}
