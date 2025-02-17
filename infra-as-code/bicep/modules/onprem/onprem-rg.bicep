metadata name = 'ALZ Bicep - Onpremise Module'
metadata description = 'ALZ Bicep Module used to create resource groups'

targetScope = 'subscription'

@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Region where to deploy the resources.')
param parLocation string = 'northeurope'

@sys.description('Name of resource group.')
param parResourceGroupName string = 'rg-onprem'


var _dep = deployment().name

module modOnpremRg 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: '${_dep}-deploy-onprem-rg'
  params: {
    name: parResourceGroupName
    location: parLocation
    tags: parTags
  }
}
