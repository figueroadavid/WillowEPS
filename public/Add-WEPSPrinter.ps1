function Add-WEPSPrinter {
    <#
        .SYNOPSIS
            Adds a printer to specified Willow EPS print servers.
        .DESCRIPTION
            Adds a printer with the specified name, IP address, and driver to one or more
            Willow EPS environments. It first checks whether the required TCP/IP or LPR
            port already exists and creates it if needed, then adds the printer using the
            specified driver. If port creation fails, printer creation is skipped for that server.
        .PARAMETER PrinterName
            The name of the printer to add.
        .PARAMETER IPAddress
            The IP address of the printer, or the LPD server if appropriate.
        .PARAMETER DriverName
            The driver to use for the printer. It must exist in the driver configuration data.
        .PARAMETER Environments
            One or more Epic environment names to target.
        .PARAMETER RemotePrinterName
            The name of the remote printer queue on the LPD server. If supplied, an LPR port
            is created instead of a standard TCP/IP port.
        .NOTES
            Ensure you have the necessary permissions to add printers on the target print servers.
        .EXAMPLE
            PS C:\> Add-WEPSPrinter -PrinterName 'PRN-01' -IPAddress 192.0.2.10 -DriverName 'Generic Universal Print Driver' -Environments PRD
        .EXAMPLE
            PS C:\> Add-WEPSPrinter -PrinterName 'PRN-02' -IPAddress 192.0.2.11 -DriverName 'Generic Universal Print Driver' -Environments PRD,TST
        .EXAMPLE
            PS C:\> Add-WEPSPrinter -PrinterName 'PRN-03-LPR' -IPAddress 198.51.100.25 -DriverName 'Generic Universal Print Driver' -Environments SUP -RemotePrinterName 'PRN-03'
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$PrinterName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({ [System.Net.IPAddress]::TryParse($_, [ref]$null) })]
        [string]$IPAddress,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$DriverName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$RemotePrinterName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Environments
    )

    begin {
        $driverNames =
            if ($script:DriverConfigInfo.Drivers) {
                $script:DriverConfigInfo.Drivers.Name
            }
            else {
                @()
            }

        if ($DriverName -notin $driverNames) {
            throw ('The specified driver "{0}" is not found in the driver configuration data. The current list of drivers is:{1}{2}' -f $DriverName, $script:CRLF, ($driverNames -join $script:CRLF))
        }

        if (-not $script:ServerListData) {
            throw 'ServerList.json data is not loaded. Unable to determine target environments.'
        }

        $TargetServers = [System.Collections.Generic.List[string]]::new()
        $SelectedEnvironments = [System.Collections.Generic.List[string]]::new()
        $AvailableEnvironments = @($script:AvailableEnvironments)

        if (-not $AvailableEnvironments -or $AvailableEnvironments.Count -eq 0) {
            $AvailableEnvironments = @(
                $script:ServerListData.PSObject.Properties.Name |
                Sort-Object
            )
        }

        $currentUser = $env:USERNAME

        foreach ($environmentName in $AvailableEnvironments) {
            $environmentConfig = $script:ServerListData.$environmentName
            if ($null -ne $environmentConfig -and $environmentConfig.Account -eq $currentUser) {
                if ($SelectedEnvironments -notcontains $environmentName) {
                    $null = $SelectedEnvironments.Add($environmentName)
                }
            }
        }

        if ($SelectedEnvironments.Count -eq 0) {
            if (-not $Environments -or $Environments.Count -eq 0) {
                Write-Warning ('At least one target environment must be specified. Available environments: {0}' -f ($AvailableEnvironments -join ', '))
                return
            }

            foreach ($environmentName in $Environments) {
                if ($environmentName -notin $AvailableEnvironments) {
                    Write-Warning ('Environment "{0}" is not defined in ServerList.json. Available environments: {1}' -f $environmentName, ($AvailableEnvironments -join ', '))
                    continue
                }

                if ($SelectedEnvironments -notcontains $environmentName) {
                    $null = $SelectedEnvironments.Add($environmentName)
                }
            }
        }

        foreach ($environmentName in $SelectedEnvironments) {
            if (-not ($script:ServerListData.PSObject.Properties.Name -contains $environmentName)) {
                continue
            }

            $environmentConfig = $script:ServerListData.$environmentName
            if ($null -eq $environmentConfig -or $null -eq $environmentConfig.Servers) {
                continue
            }

            foreach ($server in $environmentConfig.Servers) {
                if ($TargetServers -notcontains $server) {
                    $null = $TargetServers.Add($server)
                }
            }
        }

        if ($TargetServers.Count -eq 0) {
            Write-Warning ('No target servers were resolved for the requested environment selection. Available environments: {0}' -f ($AvailableEnvironments -join ', '))
            return
        }

        if ($RemotePrinterName) {
            $LocalPrinterName = $PrinterName
            $PortName = '{0}-LPR' -f $LocalPrinterName
        }
        else {
            $PortName = 'IP_{0}' -f $IPAddress
        }

        $BadServers = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($server in $TargetServers) {
            if ($PSCmdlet.ShouldProcess($server, "Configure printer '$PrinterName'")) {
                $portExists = Confirm-WEPSPrinterPort -ComputerName $server -PortName $PortName

                if ($portExists) {
                    Write-Verbose "Port '$PortName' already exists on server '$server'."
                }
                else {
                    if (-not $RemotePrinterName) {
                        $AddPortParams = @{
                            ComputerName = $server
                            IPAddress    = $IPAddress
                        }
                    }
                    else {
                        $AddPortParams = @{
                            ComputerName      = $server
                            LocalPrinterName  = $LocalPrinterName
                            IPAddress         = $IPAddress
                            RemotePrinterName = $RemotePrinterName
                        }
                    }

                    try {
                        Add-WEPSPrinterPort @AddPortParams -Verbose -ErrorAction Stop
                        Write-Verbose "Successfully created port '$PortName' on server '$server'."
                    }
                    catch {
                        Write-Error "Failed to create port '$PortName' on server '$server'. Error: $_"
                        $null = $BadServers.Add($server)
                        continue
                    }
                }

                if ($BadServers -notcontains $server) {
                    try {
                        $existingPrinter = Get-Printer -ComputerName $server -Name $PrinterName -ErrorAction SilentlyContinue
                        if ($null -ne $existingPrinter) {
                            Write-Verbose "Printer '$PrinterName' already exists on server '$server'. Skipping."
                            continue
                        }

                        if ($PSCmdlet.ShouldProcess($server, "Add printer '$PrinterName'")) {
                            Add-Printer -ComputerName $server -Name $PrinterName -DriverName $DriverName -PortName $PortName -ErrorAction Stop
                            Write-Verbose "Successfully added printer '$PrinterName' on server '$server'."
                        }
                    }
                    catch {
                        Write-Error "Failed to add printer '$PrinterName' on server '$server'. Error: $_"
                    }
                }
                else {
                    Write-Warning "Skipping printer addition on server '$server' due to previous port creation issues."
                }
            }
        }
    }
}