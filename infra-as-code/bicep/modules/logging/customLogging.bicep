metadata name = 'ALZ Bicep - Custom Logging Module'
metadata description = 'ALZ Bicep Module used to set up additional custom Logging'

type lockType = {
  @description('Optional. Specify the name of lock.')
  name: string?

  @description('Optional. The lock settings of the service.')
  kind: ('CanNotDelete' | 'ReadOnly' | 'None')

  @description('Optional. Notes about this lock.')
  notes: string?
}

@sys.description('''Global Resource Lock Configuration used for all resources deployed in this module.

- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.

''')
param parGlobalResourceLock lockType = {
  kind: 'None'
  notes: 'This lock was created by the ALZ Bicep Custom Logging Module.'
}

@sys.description('The Azure Region to deploy the resources into.')
param parLocation string = resourceGroup().location

@sys.description('Prefix value which will be prepended to all resource names.')
param parCompanyPrefix string = 'alz'

@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Region code for resource naming.')
param parLocationCode string = 'gwc'

@sys.description('''Resource Lock Configuration for Log Analytics Workspace.

- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.

''')
param parLogStorageAccountLock lockType = {
  kind: 'None'
  notes: 'This lock was created by the ALZ Bicep custom Logging Module.'
}

var _dep = deployment().name
var varEnvironment = parTags.?Environment ?? 'canary'


module modLogStorageAccount 'br/public:avm/res/storage/storage-account:0.15.0' = {
  name: '${_dep}-log-storage-account'
  params: {
    name: take(('sa${parLocationCode}log${take(uniqueString(resourceGroup().name),4)}${parCompanyPrefix}${varEnvironment}'),24)
    location: parLocation
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
    lock: {
      name: parLogStorageAccountLock.?name ?? 'pl-logsa-lock'
      kind: (parGlobalResourceLock.kind != 'None') ? parGlobalResourceLock.kind : parLogStorageAccountLock.kind
    }
  }
}

module modNetworkWatcher 'br/public:avm/res/network/network-watcher:0.3.1' = {
  name: '${_dep}-network-watcher'
  scope: resourceGroup('NetworkWatcherRG')
  params: {
    location: parLocation
    tags: parTags
  }
}

output outLogStorageAccountResourceId string = modLogStorageAccount.outputs.resourceId
output outNetworkWatcherResourceId string = modNetworkWatcher.outputs.resourceId
