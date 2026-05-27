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

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string[]]$PrinterName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]$ShowProgress
    )

    begin {
        $CurrentCounter     = 0
        $ResolvedPrinters   = [System.Collections.Generic.List[string]]::new()
        $rundll32Path       = [system.io.path]::combine($env:SystemRoot,'System32', 'rundll32.exe')

        if (-not (Test-Path -LiteralPath $rundll32Path)) {
            throw "Unable to locate rundll32.exe at '$rundll32Path'."
        }

        if ($null -eq $script:DriverConfigInfo -or
            -not ($script:DriverConfigInfo.PSObject.Properties.Name -contains 'Drivers') -or
            $null -eq $script:DriverConfigInfo.Drivers) {
            throw 'Driver configuration data is not loaded or is invalid.'
        }
    }

    process {
        foreach ($Printer in $PrinterName) {
            if (-not [string]::IsNullOrWhiteSpace($Printer)) {
                $null = $ResolvedPrinters.Add($Printer)
            }
        }
    }

    end {
        $TotalCount = $ResolvedPrinters.Count

        foreach ($Printer in $ResolvedPrinters) {
            $CurrentCounter++

            if ($ShowProgress) {
                $percentComplete = if ($TotalCount -gt 0) {
                    [math]::Round(($CurrentCounter / $TotalCount) * 100, 2)
                } else {
                    0
                }

                $ProgParams = @{
                    Activity         = 'Updating printers with correct DAT file'
                    Status           = '[{0} of {1}]' -f $CurrentCounter, $TotalCount
                    PercentComplete  = $percentComplete
                    CurrentOperation = 'Updating {0}' -f $Printer
                }
                Write-Progress @ProgParams
            }

            try {
                $thisPrinter = Get-Printer -Name $Printer -ErrorAction Stop
            }
            catch {
                Write-Warning -Message ("Printer '{0}' not found. Skipping. {1}" -f $Printer, $_.Exception.Message)
                continue
            }

            try {
                $thisDriver = Get-PrinterDriver -Name $thisPrinter.DriverName -ErrorAction Stop
            }
            catch {
                Write-Warning -Message ("Unable to retrieve driver information for printer '{0}' using driver '{1}'. Skipping. {2}" -f $Printer, $thisPrinter.DriverName, $_.Exception.Message)
                continue
            }

            $thisDriverVersion = $thisDriver.DriverVersion

            $matchingDriverEntries = @(
                $script:DriverConfigInfo.Drivers |
                    Where-Object {
                        $_.Name -eq $thisDriver.Name -and
                        $_.DriverVersion -eq $thisDriverVersion
                    }
            )

            if ($matchingDriverEntries.Count -eq 0) {
                Write-Warning -Message ('Unable to locate a driver entry for printer {0} using driver {1} version {2}; unable to apply anything.' -f $Printer, $thisDriver.Name, $thisDriverVersion)
                continue
            }

            if ($matchingDriverEntries.Count -gt 1) {
                Write-Warning -Message ('Multiple driver entries were found for printer {0} using driver {1} version {2}; skipping to avoid ambiguity.' -f $Printer, $thisDriver.Name, $thisDriverVersion)
                continue
            }

            $ConfigFileLocation = $matchingDriverEntries[0].DATFilePath

            if ([string]::IsNullOrWhiteSpace($ConfigFileLocation)) {
                Write-Warning -Message ('The DAT file path for printer {0} using driver {1} version {2} is empty; skipping.' -f $Printer, $thisDriver.Name, $thisDriverVersion)
                continue
            }

            if (-not (Test-Path -LiteralPath $ConfigFileLocation)) {
                Write-Warning -Message ('The DAT file path "{0}" for printer {1} does not exist; skipping.' -f $ConfigFileLocation, $Printer)
                continue
            }

            if ($PSCmdlet.ShouldProcess($Printer, "Apply config file '$ConfigFileLocation'")) {
                $ArgList = 'PrintUI.dll,PrintUIEntry /Sr /n "{0}" /a "{1}" g u r' -f $Printer, $ConfigFileLocation

                $ProcStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
                $ProcStartInfo.FileName = $rundll32Path
                $ProcStartInfo.Arguments = $ArgList
                $ProcStartInfo.CreateNoWindow = $true
                $ProcStartInfo.Verb = 'RunAs'
                $ProcStartInfo.UseShellExecute = $false
                $ProcStartInfo.RedirectStandardOutput = $true
                $ProcStartInfo.RedirectStandardError = $true

                $Process = [System.Diagnostics.Process]::new()
                $Process.StartInfo = $ProcStartInfo

                try {
                    $null = $Process.Start()
                    $Process.WaitForExit()

                    if ($Process.ExitCode -ne 0) {
                        $stdErr = $Process.StandardError.ReadToEnd()
                        if ([string]::IsNullOrWhiteSpace($stdErr)) {
                            $stdErr = 'No additional error output was returned.'
                        }

                        Write-Warning -Message ("Failed to apply DAT file to printer '{0}'. ExitCode={1}. {2}" -f $Printer, $Process.ExitCode, $stdErr)
                        continue
                    }

                    Write-Verbose -Message ('Updated printer {0} using DAT file {1}' -f $Printer, $ConfigFileLocation)
                }
                catch {
                    Write-Warning -Message ("Failed to apply DAT file '{0}' to printer '{1}'. {2}" -f $ConfigFileLocation, $Printer, $_.Exception.Message)
                    continue
                }
                finally {
                    $Process.Dispose()
                }
            }

            Write-Verbose -Message 'Sleeping for 1.5 seconds'
            Start-Sleep -Seconds 1.5
        }

        if ($ShowProgress) {
            Write-Progress -Activity 'Updating printers with correct DAT file' -Completed
        }
    }
}