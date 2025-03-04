######################
# Wipe-Subscription #
######################

<#
.SYNOPSIS
Fully resets an Azure subscription. BEWARE: THIS WILL DELETE ALL OF YOUR AZURE RESOURCES. USE WITH EXTREME CAUTION.

.DESCRIPTION
Fully resets an Azure subscription. BEWARE: THIS WILL DELETE ALL OF YOUR AZURE RESOURCES. USE WITH EXTREME CAUTION.
.EXAMPLE
# Without SPN Removal
.\Wipe-Subscription -subscriptionId "f73a2b89-6c0e-4382-899f-ea227cd6b68f" -resetMdfcTierOnSubs:$true


.NOTES

# Required PowerShell Modules:
- https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-6.4.0
- Install-Module -Name Az 
- Specifically 'Az.Accounts', 'Az.Resources' & 'Az.ResourceGraph' if you need to limit what is installed


#>

# Check for pre-reqs
#Requires -PSEdition Core
#Requires -Modules @{ ModuleName="Az.Accounts"; ModuleVersion="2.5.2" }
#Requires -Modules @{ ModuleName="Az.Resources"; ModuleVersion="4.3.0" }
#Requires -Modules @{ ModuleName="Az.ResourceGraph"; ModuleVersion="0.7.7" }
#Requires -Modules @{ ModuleName="Az.Security"; ModuleVersion="1.3.0" }


[CmdletBinding()]
param (
    #Added this back into parameters as error occurs if multiple tenants are found when using Get-AzTenant
    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Please the Insert Subscription ID (GUID) of your subscription e.g.'f73a2b89-6c0e-4382-899f-ea227cd6b68f'")]
    [string]
    $subscriptionId = "<Insert the Subscription ID (GUID)",

    [Parameter(Mandatory = $false, Position = 4, HelpMessage = "Do you want to reset the MDFC tiers to Free on each of the Subscriptions in scope?")]
    [bool]
    $resetMdfcTierOnSubs = $true
)

## Orphaned Role Assignements Function
function Invoke-RemoveOrphanedRoleAssignment {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()][String]$SubscriptionId
    )

    $originalCtx = Get-AzContext

    $WhatIfPrefix = ""
    if ($WhatIfPreference) {
        $WhatIfPrefix = "What if: "
    }

    # Get the latest stable API version
    $roleAssignmentsApiVersions = ((Get-AzResourceProvider -ProviderNamespace Microsoft.Authorization).ResourceTypes | Where-Object ResourceTypeName -eq roleAssignments).ApiVersions
    $latestRoleAssignmentsApiVersions = $roleAssignmentsApiVersions | Where-Object { $_ -notlike '*-preview' } | Sort-Object -Descending | Select-Object -First 1
    Write-Information "Using Role Assignments API Version : $($latestRoleAssignmentsApiVersions)" -InformationAction Continue

   

    # Use Rest API to ensure correct permissions are assigned when looking up
    # whether identity exists, otherwise Get-AzRoleAssignment will always
    # return `objectType : "unknown"` for all assignments with no errors.

    # Get Role Assignments
    $getRequestPath = "/subscriptions/$($SubscriptionId)/providers/Microsoft.Authorization/roleAssignments?api-version=$($latestRoleAssignmentsApiVersions)"
    $getResponse = Invoke-AzRestMethod -Method "GET" -Path $getRequestPath
    $roleAssignments = ($getResponse.Content | ConvertFrom-Json).value

    # Check for valid response
    if ($getResponse.StatusCode -ne "200") {
        throw $getResponse.Content
    }
    try {
        # If invalid response, $roleAssignments will be null and throw an error
        $roleAssignments.GetType() | Out-Null
    }
    catch {
        throw $getResponse.Content
    }

    # Get a list of assigned principalId values and lookup against AAD
    $principalsRequestUri = "https://graph.microsoft.com/v1.0/directoryObjects/microsoft.graph.getByIds"
    $principalsRequestBody = @{
        ids = $roleAssignments.properties.principalId
    } | ConvertTo-Json -Depth 10
    $principalsResponse = Invoke-AzRestMethod -Method "POST" -Uri $principalsRequestUri -Payload $principalsRequestBody -WhatIf:$false
    $principalIds = ($principalsResponse.Content | ConvertFrom-Json).value.id

    # Find all Role Assignments where the principalId is not found in AAD
    $orphanedRoleAssignments = $roleAssignments | Where-Object {
            ($_.properties.scope -eq "/subscriptions/$($SubscriptionId)") -and
            ($_.properties.principalId -notin $principalIds)
    }

    Write-Host "Orphaned Role Assignment: $($orphanedRoleAssignments)"
     
    # Delete orphaned Role Assignments
    Write-Information "$($WhatIfPrefix)Deleting [$($orphanedRoleAssignments.Length)] orphaned Role Assignments for Subscription [$($SubscriptionId)]" -InformationAction Continue
    $orphanedRoleAssignments | ForEach-Object {
        if ($PSCmdlet.ShouldProcess("$($_.id)", "Remove-AzRoleAssignment")) {
            $deleteRequestPath = "$($_.id)?api-version=$($latestRoleAssignmentsApiVersions)"
            $deleteResponse = Invoke-AzRestMethod -Method "DELETE" -Path $deleteRequestPath
            # Check for valid response
            if ($deleteResponse.StatusCode -ne "200") {
                throw $deleteResponse.Content
            }
        }
    }
    
    Set-AzContext $originalCtx -WhatIf:$false | Out-Null
}

#Toggle to stop warnings with regards to DisplayName and DisplayId
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

# Start timer
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.Start()


$subscription = Search-AzGraph -Query "resourcecontainers | where type =~ 'microsoft.resources/subscriptions' | where subscriptionId == '$subscriptionId' | mv-expand mgmtGroups=properties.managementGroupAncestorsChain | project subName=name, subID=subscriptionId, subState=properties.state, aadTenantID=tenantId, mgID=mgmtGroups.name, mgDisplayName=mgmtGroups.displayName"

if ($null -ne $subscription) {
    $userConfirmationSubsToMove


    # Remove orphaned/identity not found RBAC role assignments from each subscription
    # Call before long running tasks because of ID token valid time of only 5 minutes
    Write-Host "Before - Removing Oprhaned/Identity Not Found Role Assignments for subscription: '$($subscription.subName)'" -ForegroundColor Yellow
    Invoke-RemoveOrphanedRoleAssignment -SubscriptionId $subscription.subID


    # For each Subscription in the Intermediate Root Management Group's hierarchy tree, remove all Resources, Resource Groups and Deployments
    Write-Host "Removing all Azure Resources, Resource Groups and Deployments from subscription: '$($subscription.subName)'" -ForegroundColor Yellow


    Write-Host "Set context to Subscription: '$($subscription.subName)'" -ForegroundColor Cyan
    Set-AzContext -Subscription $subscription.subID | Out-Null

    # Get all Resource Groups in Subscription
    $resources = Get-AzResourceGroup

    $resources | ForEach-Object -Parallel {
        Write-Host "Deleting " $_.ResourceGroupName "..." -ForegroundColor Red
        Remove-AzResourceGroup -Name $_.ResourceGroupName -Force | Out-Null
    }
    
    # Get Deployments for Subscription
    $subDeployments = Get-AzSubscriptionDeployment

    Write-Host "Removing All Subscription Deployments for: $($subscription.subName)" -ForegroundColor Yellow 
    
    # For each Subscription level deployment, remove it
    $subDeployments | ForEach-Object -Parallel {
        Write-Host "Removing $($_.DeploymentName) ..." -ForegroundColor Red
        Remove-AzSubscriptionDeployment -Id $_.Id
    }

    # Set MDFC tier to Free for each Subscription
    if ($resetMdfcTierOnSubs) {
        Write-Host "Resetting MDFC tier to Free for Subscription: $($subscription.subName)" -ForegroundColor Yellow
        
        $currentMdfcForSubUnfiltered = Get-AzSecurityPricing
        $currentMdfcForSub = $currentMdfcForSubUnfiltered | Where-Object { $_.PricingTier -ne "Free" }

        ForEach ($mdfcPricingTier in $currentMdfcForSub) {
            Write-Host "Resetting $($mdfcPricingTier.Name) to Free MDFC Pricing Tier for Subscription: $($subscription.subName)" -ForegroundColor Yellow
            
            Set-AzSecurityPricing -Name $mdfcPricingTier.Name -PricingTier 'Free'
        }
    }


    # Remove orphaned/identity not found RBAC role assignments from each subscription
    Write-Host "After - Removing Oprhaned/Identity Not Found Role Assignments for subscription: '$($subscription.subName)'" -ForegroundColor Yellow
    Invoke-RemoveOrphanedRoleAssignment -SubscriptionId $subscription.subID

}

else {
    Write-Host "Subscription with ID: $subscriptionId not found"
    Write-Host ""
}

# Stop timer
$StopWatch.Stop()

# Display timer output as table
Write-Host "Time taken to complete task:" -ForegroundColor Yellow
$StopWatch.Elapsed | Format-Table
