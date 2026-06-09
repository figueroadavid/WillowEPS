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

        {
            "Metadata": {
                "SourceHash": "<HASH>",
                "SchemaVersion": "2.0",
                "ModuleVersion": "0.0.1",
                "LastModified": "2026-01-01T00:00:00Z",
                "ModifiedBy": "user@example.local",
                "LastSyncedAt": "2026-01-01T00:00:00Z"
            },
            "Drivers": [
                {
                "Name": "Generic PCL Driver",
                "DriverVersion": "100000000000000",
                "DriverVersionString": "1.0.0.0",
                "DATFilePath": "C:\\ProgramData\\WillowEPS\\Cache\\Data\\Driver1.dat",
                "SHA256": "<HASH>"
                },
                {
                "Name": "Generic Receipt Printer Driver",
                "DriverVersion": "200000000000000",
                "DriverVersionString": "2.0.0.0",
                "DATFilePath": "C:\\ProgramData\\WillowEPS\\Cache\\Data\\Driver2.dat",
                "SHA256": "<HASH>"
                }
            ]
        }

        The script expects the DriverConfigInfo variable to be a hashtable with a 'Drivers' key containing an array of driver information objects.
        Each driver information object should have the following properties:
        - Name: The name of the driver (string)
        - DriverVersion: A numeric or string representation of the driver version, used for comparison and sorting.
        - DriverVersionString: A human-readable string representation of the driver version.
        - DATFilePath: The file path to the driver's configuration data file.
        - SHA256: The SHA256 hash of the driver's configuration data file for integrity verification.
        The script will return driver information objects that match the specified name criteria.
    .EXAMPLE
        PS C:\>Get-WEPSDriverConfig -Name pcl -Verbose

        Name                      DriverVersion FilePath
        ----                      ------------- --------
        Generic PCL Driver      100000000000000 C:\WEPS\ConfigFiles\Driver1.dat
    .EXAMPLE
        PS C:\> PS C:\>Get-WEPSDriverConfig -Name PCL -Verbose -UsePreciseMatching
        PS C:\>
    .EXAMPLE
        PS C:\>Get-WEPSDriverConfig -Name 'Generic Receipt Printer Driver' -Verbose

        Name                                     DriverVersion FilePath
        ----                                     ------------- --------
        Generic Receipt Printer Driver         200000000000000 C:\WEPS\ConfigFiles\Driver2.dat
    .EXAMPLE
        PS C:\> Get-WEPSDriverConfig -Name 'Generic PCL Driver' -Verbose -UsePreciseMatching

        Name                                     DriverVersion FilePath
        ----                                     ------------- --------
        Generic PCL Driver                     100000000000000 C:\WEPS\ConfigFiles\Driver1.dat
    #>

    [cmdletbinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('DriverName', 'Driver')]
        [string]$Name,

        [parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'byPrefix')]
        [switch]$UsePreciseMatching
    )

    begin {
        $FilePath = $PSCmdlet.GetResolvedProviderPathFromPSPath($FilePath, [ref]$null)
        if ($UsePreciseMatching) {
            $NameRegEx = [regex]::Escape($Name)
        }
    }

    process {
        if (-not $PSBoundParameters.ContainsKey('name')) {
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
