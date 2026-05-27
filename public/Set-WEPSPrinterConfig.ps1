function Set-WEPSPrinterConfig {
    <#
    .SYNOPSIS
        Applies a DAT file to one or more printers based on their driver configuration.
    .DESCRIPTION
        This is a wrapper script to use the rundll32.exe command to apply a DAT file to one or more printers.
    .NOTES
        The DAT file applied is determined by matching the printer's driver name and version against a JSON configuration file.
        This is a critical protection, because a DAT file is specific to a driver version, and applying an incorrect DAT file
        can corrupt the printer configuration.

        The script depends on the DriverConfigData variable being available in the module scope, which is loaded from the DriverConfig.json file
        located in the Data folder of the WillowEPS module.
    .PARAMETER PrinterName
        The name(s) of the printer(s) to which the DAT file will be applied.
    .PARAMETER ShowProgress
        Switch to indicate whether to show progress during the operation.
	.EXAMPLE
        PS C:\> Set-WEPSPrinterConfig -PrinterName PRN-01

        Applies the correct DAT configuration file to printer PRN-01 based on its
        installed driver name and version, as defined in DriverConfigInfo.json.

    .EXAMPLE
        PS C:\> Set-WEPSPrinterConfig -PrinterName PRN-01,PRN-02

        Applies the correct DAT configuration file to multiple printers in a single operation.

    .EXAMPLE
        PS C:\> Set-WEPSPrinterConfig -PrinterName PRN-01 -Verbose

        Applies the DAT configuration file to PRN-01 and shows detailed output,
        including driver matching and execution steps.

    .EXAMPLE
        PS C:\> Set-WEPSPrinterConfig -PrinterName PRN-01 -WhatIf

        Shows what would happen if the configuration were applied, without making any changes.

    .EXAMPLE
        PS C:\> Get-Printer -Name PRN-* | Set-WEPSPrinterConfig

        Pipes multiple printers into the function and applies the appropriate DAT
        configuration file to each printer.

    .EXAMPLE
        PS C:\> Set-WEPSPrinterConfig -PrinterName PRN-01 -ShowProgress

        Applies the DAT configuration file to PRN-01 and displays progress information during the operation.    
	#>
	
    [cmdletbinding(SupportsShouldProcess)]
    param(
        [parameter(Mandatory, SupportsShouldProcess)]
        [string[]]$PrinterName,

        [parameter(ValueFromPipelineByPropertyName)]
        [switch]$ShowProgress
    )

    foreach ($Printer in $PrinterName) {
        $CurrentCounter ++
        $thisPrinter = Get-Printer -Name $Printer
		if (-not $thisPrinter) {
			Write-Warning -Message "Printer $printer not found, skipping it"
			continue 
		}
        $thisDriver = Get-PrinterDriver -Name $thisPrinter.DriverName
        $thisDriverVersion = $thisDriver.DriverVersion
        $ConfigFileLocation = $script:DriverConfigInfo |
			Where-Object { $_.name -eq $thisDriver.Name -and $_.DriverVersion -eq $thisDriverVersion } |
			Select-Object -ExpandProperty DATFilePath
		if (-not $ConfigFileLocation) {
			Write-Warning -Message ('Unable to locate a driver entry for {0} with version {1}; unable to apply anything' -f $thisPrinter.DriverName, $thisDriverVersion)
			continue 
		}
        if ($ConfigFileLocation) {
            if ($PSCmdlet.ShouldProcess("Apply config file $ConfigFileLocation to printer $Printer")) {
                $ArgList = 'PrintUI.dll,PrintUIEntry /Sr /n "{0}" /a {1} g u r' -f $Printer, $ConfigFileLocation
                $ProcStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
                $ProcStartInfo.FileName = 'rundll32.exe'
                $ProcStartInfo.Arguments = $ArgList
                $ProcStartInfo.CreateNoWindow = $true
                $ProcStartInfo.Verb = 'RunAs'
                $ProcStartInfo.UseShellExecute = $false
               
                $Process = [System.Diagnostics.Process]::new()
                $Process.StartInfo = $ProcStartInfo
                $process.Start()
                $Process.WaitForExit()
            }
        }
        else {
            Write-Warning -Message ('No entry found for printer {0} with driver {1} version {2}' -f $Printer, $thisDriver.Name, $thisDriverVersion)
            Continue
        }
    }
    if ($ShowProgress) {
        $ProgParams = @{
            Activity         = 'Updating printers with correct DAT file'
            Status           = '[{0} of {1}]' -f $CurrentCounter, $PrinterName.Count
            PercentComplete  = [math]::Round($CurrentCount / $PrinterName.Count / 100, 2)
            CurrentOperation = 'Updating {0}' -f $Printer.name
        }
        Write-Progress @ProgParams
    }
    else {
        Write-Verbose -Message ('Updated printer {0}' -f $printer.name)
    }
    Write-Verbose -Message 'Sleeping for 1.5 seconds'
    Start-Sleep -Seconds 1.5
}
