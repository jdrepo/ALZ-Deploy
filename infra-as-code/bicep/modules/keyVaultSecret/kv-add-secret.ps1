function Get-RandomCharacters($length, $characters) {
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs=""
    return [String]$characters[$random]
}
function Scramble-String([string]$inputString){     
$characterArray = $inputString.ToCharArray()   
$scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
$outputString = -join $scrambledStringArray
return $outputString 
}

$password = Get-RandomCharacters -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
$password += Get-RandomCharacters -length 2 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
$password += Get-RandomCharacters -length 3 -characters '1234567890'
$password += Get-RandomCharacters -length 2 -characters '@#*+'

#not allowed character " ' ` / \ < % ~ | $ & !

$password = Scramble-String $password

$NBF =(Get-Date).ToUniversalTime()

Write-Host "Adding the current public ip to the key vault allow list"
Write-Host "##################################################"
Write-Host "- KeyVault Name:              $env:KV_NAME"
Write-Host "- Secret Name:                $env:SECRET_NAME"
Write-Host "- Content Type:               $env:CONTENT_TYPE"
Write-Host "- Expiry Date:                $env:EXPIRE_DATE"
Write-Host "- Recover deleted secret:     $env:RECOVER_ENABLED"
Write-Host "- Create new secret version:  $env:NEW_VERSION"
Write-Host "##################################################"


$publicIp = "$((Invoke-WebRequest -Uri https://ifconfig.me/ip).content)/32"
Write-Host 'My public ip: '$publicIp
Add-AzKeyVaultNetworkRule -VaultName $env:KV_NAME -IpAddressRange $publicIp

$secretvalue = ConvertTo-SecureString $password -AsPlainText -Force

# Do what you want with secrets, certs

$existing_secret = Get-AzKeyVaultSecret -VaultName $env:KV_NAME -Name $env:SECRET_NAME 
$deleted_secret = Get-AzKeyVaultSecret -VaultName $env:KV_NAME -Name $env:SECRET_NAME -InRemovedState


if (!$existing_secret -and !$deleted_secret) {
    Write-Host "Secret not exists -> create"
    Set-AzKeyVaultSecret -VaultName $env:KV_NAME -Name $env:SECRET_NAME -SecretValue $secretvalue `
      -ContentType $env:CONTENT_TYPE -NotBefore $NBF -Expires $env:EXPIRE_DATE
}
else {
    if ($deleted_secret -and $env:RECOVER_ENABLED -eq "yes") {
         Write-Host "Secret -$env:SECRET_NAME- exists in deleted state and recover enabled -> recover"
         Undo-AzKeyVaultSecretRemoval -VaultName $env:KV_NAME -Name $env:SECRET_NAME
        Start-Sleep -Seconds 10
    }
    if ($env:NEW_VERSION -eq "yes") {
        Write-Host "Secret -$env:SECRET_NAME- exists -> create new version"
        Set-AzKeyVaultSecret -VaultName $env:KV_NAME -Name $env:SECRET_NAME -SecretValue $secretvalue `
         -ContentType $env:CONTENT_TYPE -NotBefore $NBF -Expires $env:EXPIRE_DATE
    }
}
if ($existing_secret -and !$deleted_secret) {
Write-Host "Secret -$env:SECRET_NAME- exists -> do nothing"
}
Write-Host "Removing current public ip address from allow list"
Remove-AzKeyVaultNetworkRule -VaultName $env:KV_NAME -IpAddressRange $publicIp 
