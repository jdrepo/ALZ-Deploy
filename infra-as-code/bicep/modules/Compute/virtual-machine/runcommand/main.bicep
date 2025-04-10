@description('Specifies the name of the Run Command.')
param runCommandName string

@description('Specifies the Azure location where Run Command resource should be created.')
param location string = resourceGroup().location

@description('Specifies tags for the Run Command resource.')
param tags object = {}

@description('Specifies the VM where the command should be run.')
param vmName string

@description('Specifies the script Uri.')
param scriptUri string? 

@description('Specifies the inline script .')
param script string? 

@description('Specifies the managed Identity for accessing a script URI .')
param parScriptUriManagedIdentity object? 

resource res_vm 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: vmName
}


resource res_run_command 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = {
  name: runCommandName
  location: location
  tags: tags
  parent: res_vm
  properties: {
    asyncExecution: false
    source: {
      scriptUri: scriptUri
      script: script
      scriptUriManagedIdentity:  parScriptUriManagedIdentity
    }
  }
}
