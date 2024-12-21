metadata name = 'KeyVault Secret Module'
metadata description = 'Secret Deployment in existing KeyVault'

targetScope = 'resourceGroup'

/*** PARAMETERS ***/


@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Region where to deploy the resources.')
param parLocation string = resourceGroup().location

@sys.description('Region code for resource naming.')
param parLocationCode string = 'gwc'

@sys.description('Key Vault name.')
param parKeyVaultName string = 'kv-${parLocationCode}-001-${parTags.Environment}-${take(uniqueString(resourceGroup().name),6)}'

@sys.description('Key Vault name.')
#disable-next-line secure-secrets-in-params //no secret in cleartext
param parSecretDeployIdentityId string = 'kv-${parLocationCode}-001-${parTags.Environment}-${take(uniqueString(resourceGroup().name),6)}'

@sys.description('Key Vault secret to deploy.')
param parSecretName string = 'secretName'

@sys.description('Key Vault secret content type.')
param parContentType string = 'password'

@sys.description('Key Vault secret expiry date.')
param parExpireDate string?

@sys.description('Recover deleted Key Vault secret if exists.')
@allowed([
  'yes'
  'no']
)
#disable-next-line secure-secrets-in-params //no secret in cleartext
param parRecoverSecret string = 'yes'

@sys.description('Create new secret version.')
@allowed([
  'yes'
  'no']
)
#disable-next-line secure-secrets-in-params //no secret in cleartext
param parNewSecretVersion string = 'no'

param parTimeNow string = utcNow('u')

/*** VARIABLES ***/

var _dep = deployment().name
var varExpireDate = dateTimeAdd(parTimeNow,'P90D')

/*** EXISTING RESOURCES ***/


/*** NEW RESOURCES ***/

module modDeployKvSecretScript 'br/public:avm/res/resources/deployment-script:0.5.0' = {
  name: '${_dep}-deployKvSecretScript'
  params: {
    tags: parTags
    location: parLocation
    name: '${parKeyVaultName}-deployKvSecret_${take(uniqueString('${parSecretName}'),3)}'
    kind: 'AzurePowerShell'
    azPowerShellVersion: '12.3'
    retentionInterval: 'PT1H'
    cleanupPreference: 'Always'
    managedIdentities: {
      userAssignedResourceIds:  [
        parSecretDeployIdentityId
      ]
    }
    environmentVariables: [
        {
          name: 'KV_NAME'
          value: parKeyVaultName
        }
        {
          name: 'SECRET_NAME'
          value: parSecretName
        }
        {
          name: 'CONTENT_TYPE'
          value: parContentType
        }
        {
          name: 'EXPIRE_DATE'
          value: parExpireDate ?? varExpireDate
        }
        {
          name: 'RECOVER_ENABLED'
          value: parRecoverSecret
        }
        {
          name: 'NEW_VERSION'
          value: parNewSecretVersion
        }]
    scriptContent: loadTextContent('kv-add-secret.ps1')
  }
}

/*** OUTPUTS ***/
