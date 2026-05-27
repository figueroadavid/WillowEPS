function Get-WEPSDriverConfig {
    <#
    .SYNOPSIS
        Retrieves driver information from the config file used for the Set-WillowEPSPrinterConfig.ps1 script
    .DESCRIPTION
        The script reads in the JSON file containing the names and versions of the driver names,
        and the file path to the configuration file.
    .PARAMETER Name
        The name of the driver to retrieve from the config data.
    .PARAMETER UsePreciseMatching
        By default, the script will use a -Like *$Name* operation with the name to
        match any available driver names.  If there are multiple driver entries with
        similar names, multiple items can be returned.  
        Using this switch causes the script to use RegEx to match the drivername precisely.  
    .NOTES
        The script uses the DriverConfigData variable loaded in the module.
        The data is loaded from the DriverConfig.json file located in the Data folder of the WillowEPS module.
        The format of the JSON file is as follows:
        [
            {
                "Name": "Generic PCL Driver",
                "DriverVersion": 100000000000000,
                "FilePath": "C:\\ProgramData\\WillowEPS\\Cache\\Data\\Driver1.dat"
            },
            {
                "Name": "Generic Universal Print Driver",
                "DriverVersion": 300000000000000,
                "FilePath": "C:\\ProgramData\\WillowEPS\\Cache\\Data\\Driver3.dat"
            }
        ]
    .EXAMPLE
        PS C:\>Get-WEPSDriverConfig -Name Generic -Verbose

        Name                         DriverVersion     FilePath
        ----                         -------------     --------
        Generic Universal Print Driver 300000000000000 C:\ProgramData\WillowEPS\Cache\Data\Driver3.dat
    .EXAMPLE
        PS C:\>Get-WEPSDriverConfig -Name Generic -Verbose -UsePreciseMatching
        PS C:\>
    .EXAMPLE
        PS C:\>Get-WEPSDriverConfig -Name 'Generic Universal Print Driver' -Verbose

        Name                         DriverVersion     FilePath
        ----                         -------------     --------
        Generic Universal Print Driver 300000000000000 C:\ProgramData\WillowEPS\Cache\Data\Driver3.dat
    .EXAMPLE
        PS C:\>Get-WEPSDriverConfig -Name 'Generic Universal Print Driver' -Verbose -UsePreciseMatching

        Name                         DriverVersion     FilePath
        ----                         -------------     --------
        Generic Universal Print Driver 300000000000000 C:\ProgramData\WillowEPS\Cache\Data\Driver3.dat
    #>

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('DriverName', 'Driver')]
        [string]$Name,

        [parameter(ValueFromPipelineByPropertyName)]
        [switch]$UsePreciseMatching
    )

    begin {
        if ($UsePreciseMatching -and $Name) {
            $NameRegEx = [regex]::Escape($Name)
        }
    }

    process {
        if (-not $PSBoundParameters.ContainsKey('Name')) {
            $script:DriverConfigInfo
        }
        elseif ($UsePreciseMatching) {
            $script:DriverConfigInfo | Where-Object Name -match ('^{0}$' -f $NameRegEx)
        }
        else {
            $script:DriverConfigInfo | Where-Object Name -like "*$Name*"
        }
    }
}