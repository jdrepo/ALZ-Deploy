@sys.description('Region where to deploy the resources.')
param parLocation string

@sys.description('Bastion resource name.')
param parBastionName string

@sys.description('Virtual network resource id to place bastion into.')
param parVnetResourceId string

@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

resource resBastion 'Microsoft.Network/bastionHosts@2024-01-01' = {  
    location: parLocation
    name: parBastionName
    tags: parTags
    properties: {
      virtualNetwork: {
        id: parVnetResourceId
      }
    }
    sku: {
      name: 'Developer'
    }
  }
