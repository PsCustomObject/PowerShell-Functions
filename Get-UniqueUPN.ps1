function Get-UniqueUPN
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "ADObject")]
        [object]$ADObject,
        
        [Parameter(Mandatory = $true, ParameterSetName = "Strings")]
        [string]$FirstName,
        
        [Parameter(Mandatory = $true, ParameterSetName = "Strings")]
        [string]$LastName,
        
        [Parameter(ParameterSetName = "Strings")]
        [string]$MiddleName,
        
        [Parameter(Mandatory = $true)]
        [string]$UPNSuffix,
        
        [string]$FirstNameFormat = "Full",
        [switch]$IncludeMiddleName,
        [string]$DuplicateSuffix = "Numeric",
        [string]$CustomDuplicateSuffix,
        [string]$Server,
        [string]$Separator = "."
    )

    try
    {
        if ($PSCmdlet.ParameterSetName -eq "ADObject")
        {
            Write-Verbose "Processing AD Object"
            switch ($ADObject.GetType().FullName)
            {
                "Microsoft.ActiveDirectory.Management.ADUser"
                {
                    $firstName = $ADObject.GivenName
                    $lastName = $ADObject.Surname
                    $middleName = $ADObject.MiddleName
                    break
                }
                "System.DirectoryServices.DirectoryEntry"
                {
                    $firstName = $ADObject.Properties["givenName"][0]
                    $lastName = $ADObject.Properties["sn"][0]
                    $middleName = $ADObject.Properties["middleName"][0]
                    break
                }
                "System.DirectoryServices.SearchResult"
                {
                    $firstName = $ADObject.Properties["givenName"][0]
                    $lastName = $ADObject.Properties["sn"][0]
                    $middleName = $ADObject.Properties["middleName"][0]
                    break
                }
                default
                {
                    throw "Unsupported AD object type: $($ADObject.GetType().FullName)"
                }
            }
        }
        else
        {
            Write-Verbose "Processing string inputs"
            $firstName = $FirstName
            $lastName = $LastName
            $middleName = $MiddleName
        }

        Write-Verbose "First Name: $firstName, Last Name: $lastName, Middle Name: $middleName"

        $firstName = switch ($FirstNameFormat)
        {
            "Full" { $firstName }
            "FirstLetter" { $firstName.Substring(0, 1) }
            default { $firstName }
        }

        $middleNamePart = if ($IncludeMiddleName -and $middleName)
        {
            "$Separator$middleName"
        }
        else { "" }

        $baseUPN = "$firstName$middleNamePart$Separator$lastName@$UPNSuffix".ToLower()
        Write-Verbose "Base UPN: $baseUPN"

        $uniqueUPN = $baseUPN
        $counter = 1

        while (Test-UPNExist -UPN $uniqueUPN -Server $Server)
        {
            Write-Verbose "UPN $uniqueUPN already exists, generating alternative"
            if ($DuplicateSuffix -eq "Numeric")
            {
                $uniqueUPN = "{0}{1}@{2}" -f ($baseUPN.Split('@')[0]), $counter, $UPNSuffix
            }
            else
            {
                $uniqueUPN = "{0}{1}@{2}" -f ($baseUPN.Split('@')[0]), $CustomDuplicateSuffix, $UPNSuffix
            }
            $counter++
        }

        Write-Verbose "Final Unique UPN: $uniqueUPN"
        return $uniqueUPN
    }
    catch
    {
        Write-Error "Error generating UPN: $_"
        throw
    }
}