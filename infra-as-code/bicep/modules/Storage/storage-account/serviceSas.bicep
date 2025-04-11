@description('Required. Specifies the name of storage account.')
param parStorageAccountName string

@description('Required. Object with properties for Service SAS Token.')
param parServiceSas object

// Reference existing storage account
resource resStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: parStorageAccountName
}

// Generate Service SAS Token
var varServiceSasUri = resStorageAccount.listServiceSas(resStorageAccount.apiVersion, parServiceSas).serviceSasToken


output serviceSasToken string = varServiceSasUri
