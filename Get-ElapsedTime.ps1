function Get-ElapsedTime {
    <#
        .SYNOPSIS
        Returns information about elapsed time for a given Stopwatch.

        .DESCRIPTION
        This function takes a [System.Diagnostics.Stopwatch] object as input and outputs information about elapsed time based on the specified format.

        .PARAMETER ElapsedTime
        The [System.Diagnostics.Stopwatch] object representing the elapsed time for the given stopwatch.

        .PARAMETER Format
        Specifies the format for the output. Possible values are "Full", "Days", "Hours", "Minutes", "Seconds", "TotalDays", "TotalHours", "TotalMinutes", "TotalSeconds", "TotalMilliseconds".

        .EXAMPLE
        PS C:\> Get-ElapsedTime -ElapsedTime $ElapsedTime -Format "Days"

        .OUTPUTS
        System.TimeSpan, System.Double, System.Int32
    #>

    [CmdletBinding(DefaultParameterSetName = 'FullOutput')]
    param (
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Stopwatch]
        $ElapsedTime,

        [ValidateSet("Full", "Days", "Hours", "Minutes", "Seconds", "TotalDays", "TotalHours", "TotalMinutes", "TotalSeconds", "TotalMilliseconds")]
        [string]
        $Format = "Full"
    )

    switch ($Format) {
        'Full' {
            return $ElapsedTime.Elapsed
        }
        default {
            return $ElapsedTime.Elapsed."$Format"
        }
    }
}