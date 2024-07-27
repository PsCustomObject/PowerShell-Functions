function Test-UPNExist
{
<#
    .SYNOPSIS
        Cmdlet will check if a given UPN exists in the forest.
    
    .DESCRIPTION
        Cmdlet is a diagnostic tool to check if a given UPN is already assigned to a user in the forest.
    
    .PARAMETER UPN
        A string representing the UPN to check for uniqueness.
    
    .PARAMETER AdServer
        A string representing the name of the domain controller to be used for the check, if parameter
        is not specified the closest Global Catalog is used.
    
    .EXAMPLE
        PS C:\> Test-UPNExist -UPN 'John.Doe@example.com'
#>
    
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$UPN,
        [ValidateNotNullOrEmpty()]
        [string]$AdServer
    )
    
    if ([string]::IsNullOrEmpty($AdServer) -eq $true)
    {
        $adForest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
        [string]$ldapPath = '{0}{1}' -f 'GC://', $($adForest.FindGlobalCatalog().Name)
    }
    else
    {
        [string]$ldapPath = '{0}{1}' -f 'LDAP://', $AdServer
    }
    
    # Instantiate required objects and run query
    $adDomain = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
    $adSearcher = New-Object System.DirectoryServices.DirectorySearcher($adDomain)
    $adSearcher.SearchScope = 'Subtree'
    $adSearcher.PageSize = 1000
    $adSearcher.Filter = "(&(objectCategory=person)(userPrincipalName=$UPN))"
    [void]($adSearcher.PropertiesToLoad.Add("userPrincipalName"))
    
    [array]$searchResult = $adSearcher.FindOne()
    
    return $null -ne $searchResult
}