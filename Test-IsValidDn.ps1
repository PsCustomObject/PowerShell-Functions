function Test-IsValidDN
{
    <#
        .SYNOPSIS
            Cmdlet will check if the input string is a valid distinguishedname.
        
        .DESCRIPTION
            Cmdlet will check if the input string is a valid distinguishedname.
            
            Cmdlet is intended as a dignostic tool for input validation
        
        .PARAMETER ObjectDN
            A string representing the object distinguishedname.
        
        .EXAMPLE
            PS C:\> Test-IsValidDN -ObjectDN 'Value1'
    #>
    
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('DN', 'DistinguishedName')]
        [string]
        $ObjectDN
    )
    
    # Create new string builder
    [System.Text.StringBuilder]$regexStringBuilder = [System.Text.StringBuilder]::New()
    [void]($regexStringBuilder.Append('^(?:[A-Za-z][\w-]*|\d+(?:\.\d+)*)=(?:#(?:[\dA-Fa-f]{2})+|'))
    [void]($regexStringBuilder.Append('(?:[^,=\+<>#;\\"]|\\[,=\+<>#;\\"]|\\[\dA-Fa-f]{2})*|"(?:'))
    [void]($regexStringBuilder.Append('[^\\"]|\\[,=\+<>#;\\"]|\\[\dA-Fa-f]{2})*")(?:\+(?:[A-Za-z]'))
    [void]($regexStringBuilder.Append('[\w-]*|\d+(?:\.\d+)*)=(?:#(?:[\dA-Fa-f]{2})+|(?:[^,=\+<>#;\\"]'))
    [void]($regexStringBuilder.Append('|\\[,=\+<>#;\\"]|\\[\dA-Fa-f]{2})*|"(?:[^\\"]|\\[,=\+<>#;\\"]|'))
    [void]($regexStringBuilder.Append('\\[\dA-Fa-f]{2})*"))*(?:,(?:[A-Za-z][\w-]*|\d+(?:\.\d+)*)=(?:#'))
    [void]($regexStringBuilder.Append('(?:[\dA-Fa-f]{2})+|(?:[^,=\+<>#;\\"]|\\[,=\+<>#;\\"]|\\[\dA-Fa-f]'))
    [void]($regexStringBuilder.Append('{2})*|"(?:[^\\"]|\\[,=\+<>#;\\"]|\\[\dA-Fa-f]{2})*")(?:\+(?:[A-Za-z]'))
    [void]($regexStringBuilder.Append('[\w-]*|\d+(?:\.\d+)*)=(?:#(?:[\dA-Fa-f]{2})+|(?:[^,=\+<>#;\\"]|\\[,=\'))
    [void]($regexStringBuilder.Append('+<>#;\\"]|\\[\dA-Fa-f]{2})*|"(?:[^\\"]|\\[,=\+<>#;\\"]|\\[\dA-Fa-f]{2})*"))*)*$'))
    
    # Define DN Regex
    [string]$distinguishedNameRegex = $regexStringBuilder.ToString()
    
    return $ObjectDN -match $distinguishedNameRegex
}