function Import-WEPSXeroxConfig {
    <#
    .SYNOPSIS
        Imports printer configuration data from a JSON file previously exported by Export-WEPSXeroxConfig.
    .DESCRIPTION
        Imports a set of registry values from a JSON file and applies them to one or more printers.
        The spooler service is stopped to allow safe registry updates and optionally restarted afterward.
    .PARAMETER PrinterName
        The name(s) of the printer(s) to which the configuration should be applied.
    .PARAMETER FilePath
        The path to the JSON file containing the printer configuration data.
    .PARAMETER RestartSpooler
        Restarts the Print Spooler after import is complete.
    .PARAMETER RequireXeroxGPD
        If specified, ensures that only printers using the Xerox Global Print Driver PCL6 are modified.
    .NOTES
        This was built around the specific registry configuration patterns observed for Xerox printers, 
        particularly those using the Global Print Driver. It is not suitable for non-Xerox printers
        and may not cover all possible registry values. Review the JSON before importing.

        Because the script imports a binary Default DevMode value, it updates the embedded
        device name to match the target printer name.

        The script is intended to be run after standard printer configuration tasks.
    .EXAMPLE
        PS C:\>Import-WEPSXeroxConfig -PrinterName PRN-01 -FilePath C:\Temp\PrinterConfig.json -RestartSpooler -Verbose -RequireXeroxGPD
        VERBOSE: Starting validation phase
        VERBOSE: Stopping Print Spooler
        VERBOSE: Applying registry configuration
        VERBOSE: Import complete
        VERBOSE: Starting Spooler
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string[]]$PrinterName,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter()]
        [switch]$RestartSpooler,

        [Parameter()]
        [switch]$RequireXeroxGPD
    )

    begin {
        function Set-DevModeDeviceName {
            param(
                [Parameter(Mandatory)]
                [byte[]]$DevModeBytes,

                [Parameter(Mandatory)]
                [string]$NewPrinterName
            )

            if ($DevModeBytes.Length -lt 64) {
                throw "Default DevMode data is too small."
            }

            $name = $NewPrinterName.Substring(0, [Math]::Min(31, $NewPrinterName.Length))
            $nameBytes = [System.Text.Encoding]::Unicode.GetBytes($name)

            $buf = New-Object byte[] 64
            [array]::Copy($nameBytes, $buf, [Math]::Min($nameBytes.Length, 62))

            [array]::Copy($buf, 0, $DevModeBytes, 0, 64)
            return $DevModeBytes
        }

        function ConvertTo-ValueKind {
            param([Parameter(Mandatory)]$Kind)

            if ($Kind -is [string]) {
                return [Microsoft.Win32.RegistryValueKind]::$Kind
            }
            else {
                return [Microsoft.Win32.RegistryValueKind]([int]$Kind)
            }
        }

        if (-not (Test-Path -LiteralPath $FilePath)) {
            throw "File not found: $FilePath"
        }

        $items = Get-Content -LiteralPath $FilePath -Raw | ConvertFrom-Json
        if ($items -isnot [System.Array]) { $items = @($items) }

        $validatedPrinters = @()
    }

    process {
        foreach ($printer in $PrinterName) {
            try {
                $p = Get-Printer -Name $printer -ErrorAction Stop

                if ($RequireXeroxGPD -and ($p.DriverName -notmatch '^Xerox Global Print Driver PCL6$')) {
                    Write-Warning "Skipping '$printer' due to driver mismatch."
                    continue
                }

                $validatedPrinters += $p.Name
            }
            catch {
                Write-Warning "Skipping '$printer' (not found)."
            }
        }
    }

    end {
        if ($validatedPrinters.Count -eq 0) {
            Write-Warning "No valid printers found."
            return
        }

        if ($PSCmdlet.ShouldProcess("Spooler", "Stop")) {
            Stop-Service -Name Spooler -Force -ErrorAction Stop
        }

        try {
            foreach ($printer in $validatedPrinters) {
                $baseKey = "registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Print\Printers\$printer"

                foreach ($item in $items) {
                    $targetKey = if ([string]::IsNullOrWhiteSpace($item.SubKey)) {
                        $baseKey
                    }
                    else {
                        Join-Path $baseKey $item.SubKey
                    }

                    $kind = ConvertTo-ValueKind $item.Kind
                    $data = $item.Data

                    if ($kind -eq [Microsoft.Win32.RegistryValueKind]::Binary) {
                        if ($data -eq '<BINARY_DATA_REDACTED>') { continue }
                        $valueToWrite = [Convert]::FromBase64String([string]$data)

                        if ($item.Name -eq 'Default DevMode') {
                            $valueToWrite = Set-DevModeDeviceName $valueToWrite $printer
                        }
                    }
                    elseif ($kind -eq [Microsoft.Win32.RegistryValueKind]::MultiString) {
                        $valueToWrite = [string[]]$data
                    }
                    elseif ($kind -eq [Microsoft.Win32.RegistryValueKind]::DWord) {
                        $valueToWrite = [int]$data
                    }
                    else {
                        $valueToWrite = [string]$data
                    }

                    if ($PSCmdlet.ShouldProcess($targetKey, "Set '$($item.Name)'")) {
                        Set-ItemProperty -Path $targetKey -Name $item.Name -Value $valueToWrite -Type $kind
                    }
                }

                Write-Verbose "Import complete for '$printer'"
            }
        }
        finally {
            if ($RestartSpooler -and $PSCmdlet.ShouldProcess("Spooler", "Start")) {
                Start-Service -Name Spooler
            }
        }

        Write-Verbose "Import process completed."
    }
}