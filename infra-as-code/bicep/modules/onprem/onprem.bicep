metadata name = 'ALZ Bicep - Onpremise Module'
metadata description = 'ALZ Bicep Module used to set up Onpremise resources'

targetScope = 'subscription'

@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Region where to deploy the resources.')
param parLocation string = 'germanywestcentral'

@sys.description('Name of resource group.')
param parResourceGroupName string = 'rg-onprem'

@sys.description('Region code for resource naming.')
param parLocationCode string = 'gwc'

var _dep = deployment().name
var varEnvironment = parTags.?Environment ?? 'canary'

module modResourceGroup 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: '${_dep}-resource-group'
  params: {
    name: parResourceGroupName
    location: parLocation
  }
}
