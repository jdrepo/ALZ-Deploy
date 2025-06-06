metadata name = 'ALZ Bicep - Hub Networking NVA Module'
metadata description = 'ALZ Bicep Module used to set up NVA components in Hub Networking'


@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}


@sys.description('Region where to deploy the resources.')
param parLocation string = resourceGroup().location

var _dep = deployment().name

