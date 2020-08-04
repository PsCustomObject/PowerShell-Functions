function Test-IsRegistryKey
{
    <#
        .SYNOPSIS
            Cmdlet will check if the specified registry key is valid.
        
        .DESCRIPTION
            Cmdlet will check if the specified registry path is valid.
        
        .PARAMETER KeyPath
            A string representing the registry path to check in the PSDrive format IE HKLM:\SOFTWARE
        
        .EXAMPLE
            PS C:\> Test-IsRegistryKey -KeyPath 'value1'
    #>
    
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $KeyPath
    )
    
    if (Test-Path -Path $KeyPath)
    {
        return (Get-Item -Path $KeyPath).PsProvider.Name -match 'Registry'
    }
    else
    {
        return $false
    }
}
