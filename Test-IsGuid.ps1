function Test-IsGuid
{
    <#
        .SYNOPSIS
            Cmdlet will check if input string is a valid GUID.
        
        .DESCRIPTION
            Cmdlet will check if input string is a valid GUID.
        
        .PARAMETER ObjectGuid
            A string representing the GUID to be tested.
        
        .EXAMPLE
            PS C:\> Test-IsGuid -ObjectGuid 'value1'
        
            # Output
            $False
        
        .EXAMPLE
            PS C:\> Test-IsGuid -ObjectGuid '7761bf39-9a9f-42c8-869f-7c6e2689811a'
        
            # Output
            $True
        
        .OUTPUTS
            System.Boolean
        
        .NOTES
            Additional information about the function.
    #>
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ObjectGuid
    )
    
    # Define verification regex
    [regex]$guidRegex = '(?im)^[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$'
    
    # Check guid against regex
    return $ObjectGuid -match $guidRegex
}
