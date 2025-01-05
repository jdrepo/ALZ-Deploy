# 

# Install-PackageProvider -Name NuGet -Force
# Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
# Install-Module -name PSDesiredStateConfiguration
# Install-Module -name ActiveDirectoryDsc -force
# Install-Module -name ComputerManagementDsc -force
# Install-Module -name NetworkingDsc -force
# Install-Module -Name DnsServerDsc -force
# Install-Module -Name StorageDsc -force
# Publish-AzVMDscConfiguration ".\Deploy-DomainServices.ps1" -OutputArchivePath ".\Deploy-DomainServices.ps1.zip" -Force

Configuration Deploy-DomainServices
{
    Param
    (
        [Parameter(Mandatory)]
        [String] $domainFQDN,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential] $adminCredential,

        [Parameter()]
        [String] $ADDSFilePath = "C:\Windows",

        [Parameter()]
        [int] $ADDiskId = 0,

        [Parameter()]
        [String] $ForestMode = "WinThreshold",

        [Parameter()]
        [Array] $DNSForwarder = @()
    )

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'ActiveDirectoryDsc'
    Import-DscResource -ModuleName 'ComputerManagementDsc'
    Import-DscResource -ModuleName 'NetworkingDsc'
    Import-DscResource -ModuleName 'DnsServerDsc'
    Import-DscResource -ModuleName 'StorageDsc'

    # Create the NetBIOS name and domain credentials based on the domain FQDN
    [String] $domainNetBIOSName = (Get-NetBIOSName -DomainFQDN $domainFQDN)
    [System.Management.Automation.PSCredential] $domainCredential = New-Object System.Management.Automation.PSCredential ("${domainNetBIOSName}\$($adminCredential.UserName)", $adminCredential.Password)

    $interface = Get-NetAdapter | Where-Object Name -Like "Ethernet*" | Select-Object -First 1
    $interfaceAlias = $($interface.Name)

    Node localhost
    {
        LocalConfigurationManager 
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
            ActionAfterReboot = 'ContinueConfiguration'
        }

        WindowsFeature InstallDNS 
        { 
            Ensure = 'Present'
            Name = 'DNS'
        }

        WindowsFeature InstallDNSTools
        {
            Ensure = 'Present'
            Name = 'RSAT-DNS-Server'
            DependsOn = '[WindowsFeature]InstallDNS'
        }

        DnsServerAddress SetDNS
        { 
            Address = '127.0.0.1'
            InterfaceAlias = $interfaceAlias
            AddressFamily = 'IPv4'
            DependsOn = '[WindowsFeature]InstallDNS'
        }

        DnsServerForwarder SetDNSForwarder
        {
            IsSingleInstance = 'Yes'
            IPAddresses      = $DNSForwarder
            UseRootHint      = $false
            DependsOn = '[WindowsFeature]InstallDNS'
        }

        WindowsFeature InstallADDS
        {
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
            DependsOn = '[WindowsFeature]InstallDNS'
        }

        WindowsFeature InstallADDSTools
        {
            Ensure = 'Present'
            Name = 'RSAT-ADDS-Tools'
            DependsOn = '[WindowsFeature]InstallADDS'
        }

        WindowsFeature ADAdminCenter
        {
            Ensure = "Present"
            Name = "RSAT-AD-AdminCenter"
            DependsOn = "[WindowsFeature]InstallADDSTools"
        }

        OpticalDiskDriveLetter SetFirstOpticalDiskDriveLetterToZ
        {
            DiskId      = 1
            DriveLetter = 'Z'
        }
        WaitForDisk ADDataDisk
        {
             DiskId = $ADDiskId
             RetryIntervalSec = 60
             RetryCount = 60
        }

        Disk ADDataDisk {
            DiskId  = $ADDiskId
            DriveLetter = $ADDSFilePath.Split(":")[0]
            DependsOn   = "[WaitForDisk]ADDataDisk"
        }

        ADDomain CreateADForest
        {
            DomainName = $domainFQDN
            Credential = $domainCredential
            SafemodeAdministratorPassword = $domainCredential
            ForestMode = $ForestMode
            DatabasePath = "$ADDSFilePath\NTDS"
            LogPath = "$ADDSFilePath\NTDS"
            SysvolPath = "$ADDSFilePath\SYSVOL"
            DependsOn = '[DnsServerAddress]SetDNS', '[WindowsFeature]InstallADDS'
        }

        PendingReboot RebootAfterCreatingADForest
        {
            Name = 'RebootAfterCreatingADForest'
            DependsOn = "[ADDomain]CreateADForest"
        }

        WaitForADDomain WaitForDomainController
        {
            DomainName = $domainFQDN
            WaitTimeout = 300
            RestartCount = 3
            Credential = $domainCredential
            WaitForValidCredentials = $true
            DependsOn = "[PendingReboot]RebootAfterCreatingADForest"
        }
    }
}

function Get-NetBIOSName {
    [OutputType([string])]
    param(
        [string] $domainFQDN
    )

    if ($domainFQDN.Contains('.')) {
        $length = $domainFQDN.IndexOf('.')
        if ( $length -ge 16) {
            $length = 15
        }
        return $domainFQDN.Substring(0, $length)
    }
    else {
        if ($domainFQDN.Length -gt 15) {
            return $domainFQDN.Substring(0, 15)
        }
        else {
            return $domainFQDN
        }
    }
}


