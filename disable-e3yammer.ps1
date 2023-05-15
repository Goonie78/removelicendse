Connect-Graph -Scopes User.Read.All, Organization.Read.All

# Get all users with SPE_E5 licenses
$users = Get-MgUser -Filter "assignedLicenses/any(x:x/skuId eq $($e3Sku.SkuId) )" -ConsistencyLevel eventual -CountVariable e3licensedUserCount -All

# Get the new service plans that are going to be disabled
$e3Sku = Get-MgSubscribedSku -All | Where SkuPartNumber -eq 'SPE_E3'
$newDisabledPlans = $e3Sku.ServicePlans |
    Where-Object { $_.ServicePlanName -in ("YAMMER_ENTERPRISE") } |
    Select-Object -ExpandProperty ServicePlanId

foreach ($user in $users) {
    # Get the services that have already been disabled for the user.
    $userLicense = Get-MgUserLicenseDetail -UserId $user.UserPrincipalName
    $userDisabledPlans = $userLicense.ServicePlans |
        Where-Object { $_.ProvisioningStatus -eq "Disabled" } |
        Select-Object -ExpandProperty ServicePlanId

    # Merge the new plans that are to be disabled with the user's current state of disabled plans
    $disabledPlans = ($userDisabledPlans + $newDisabledPlans) | Select-Object -Unique

    $addLicenses = @{
        SkuId = $e3Sku.SkuId
        DisabledPlans = $disabledPlans
    }

    # Update user's license
    Set-MgUserLicense -UserId $user.UserPrincipalName -AddLicenses $addLicenses -RemoveLicenses @()
}