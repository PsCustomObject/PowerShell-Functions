function Test-UPNExist
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UPN,
        
        [string]$Server
    )

    try
    {
        if ($Server)
        {
            $ldapPath = "LDAP://$Server"
        }
        else
        {
            $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
            $gc = $forest.FindGlobalCatalog()
            $ldapPath = "GC://$($gc.Name)"
        }
        $domain = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
        $searcher = New-Object System.DirectoryServices.DirectorySearcher($domain)
        $searcher.SearchScope = "Subtree"
        $searcher.PageSize = 1000
        $searcher.Filter = "(&(objectCategory=person)(userPrincipalName=$UPN))"
        [void]($searcher.PropertiesToLoad.Add("userPrincipalName"))

        $result = $searcher.FindOne()
        return $null -ne $result
    }
    catch
    {
        Write-Error "Error checking UPN existence: $_"
        throw
    }
}
