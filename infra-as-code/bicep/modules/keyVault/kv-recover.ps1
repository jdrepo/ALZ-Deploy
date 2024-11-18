Write-Host "Check for soft-deleted Key Vault"
Write-Host "KeyVault Name: "$env:KV_NAME


$keyVault = Get-AzKeyVault -InRemovedState -VaultName $env:KV_NAME -Location $env:KV_LOCATION
if ($keyVault) {
    $ResourceGroup = $keyVault.ResourceId.Split("/")[4]
    Write-Host "Recover soft-deleted Key Vault: $($env:KV_NAME) in Resource Group: $($ResourceGroup)"
    Undo-AzKeyVaultRemoval -VaultName $env:KV_NAME -ResourceGroupName $ResourceGroup -Location $keyVault.Location -Tag $keyVault.Tags
}
else {
    Write-Host "No soft-deleted Key Vault found"
}