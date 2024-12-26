param(
    [string]$storageAccountName,
    [string]$containersToCreate,
    [string]$resourceGroupName
)

Connect-AzAccount -Identity
$containers = $containersToCreate | ConvertFrom-Json -AsHashtable
$stg = Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName
$context = $stg.Context

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jdrepo/ALZ-Deploy/main/infra-as-code/bicep/modules/identity/scripts/prepareDisks.ps1" -OutFile "prepareDisks.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jdrepo/ALZ-Deploy/main/infra-as-code/bicep/modules/identity/scripts/Deploy-DomainServices.ps1.zip" -OutFile "Deploy-DomainServices.ps1.zip"
# Invoke-WebRequest -Uri "https://filesamples.com/samples/document/txt/sample3.txt" -OutFile "sample3.txt"


foreach ($container in $containers.keys) {
    if (Get-AzStorageContainer -Name $container -Context $context -ErrorAction Ignore) {
         Write-Host "`n Container - $container - already exists"
    }
    else {
        Write-Host "`n Creating container - $container -"
        New-AzStorageContainer -Name $container -Context $context -Permission Off    
    }  
    Write-Host "`n Creating blobs in - $container - container"
    foreach ($blob in $containers[$container]) {
        Write-Host "`n Creating blob - $blob -"
        $Blob1HT = @{
            File             = "./$blob"
            Container        = $container
            Blob             = $blob
            Context          = $context
            StandardBlobTier = 'Hot'
            Force            = $true
        }
        Set-AzStorageBlobContent @Blob1HT
    }
}
