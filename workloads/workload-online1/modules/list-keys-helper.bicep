targetScope = 'resourceGroup'

@description('Resource ID of the resource for which keys are to be fetched.')
param resourceId string

@description('API version of the resource for which keys are to be fetched.')
param apiVersion string

var keys = listKeys('${resourceId}/host/default', apiVersion).functionKeys.default

@secure()
output key string = keys
