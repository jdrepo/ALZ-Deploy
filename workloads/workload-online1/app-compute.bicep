metadata name = 'ALZ Iaas Landing Zone Baseline '
metadata description = 'Deploy the compute infrastructure'

targetScope = 'resourceGroup'

extension microsoftGraphV1

import { funcGetResourceInformation } from 'functions/funcs-udts.bicep'

@sys.description('The Azure Region to deploy the resources into.')
param parLocation string = resourceGroup().location

@sys.description('Deployment environment.')
param parEnvironment string = 'canary'

@sys.description('Required. The virtual network resource id to deploy resources into.')
param parVnetResourceId string 

var _dep = deployment().name

// Object containing a mapping for location / region code
var varLocationCodes = {
  germanywestcentral: 'gwc'
  westeurope: 'weu'
}

var varLocationCode = varLocationCodes[parLocation]

var varVirtualNetwork = funcGetResourceInformation(parVnetResourceId)

var varLogWorkSpaceName = 'log-${varLocationCode}-compute-${parEnvironment}'

resource resVnet1 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  scope: resourceGroup(varVirtualNetwork.subscriptionId,varVirtualNetwork.resourceGroupName)
  name: varVirtualNetwork.resourceName
}

module modLogWorkSpace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
  name: '${_dep}-log-workspace'
  scope: resourceGroup()
  params: {
    name: varLogWorkSpaceName
    location: parLocation
    dataRetention: 30
    tables: [
      {
        name: 'WindowsLogsTable_CL'
        schema: { 
          name: 'WindowsLogsTable_CL'
          columns: [
            {
              name: 'TimeGenerated'
              type: 'dateTime'
            }
            {
              name: 'RawData'
              type: 'string'
            }
          ]
        }
      }
    ]
  }
}
