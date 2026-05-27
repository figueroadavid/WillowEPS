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
        [Alias('Name')]
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
        if (
            ($null -eq $script:DriverConfigInfo) -or
            (-not ($script:DriverConfigInfo.PSObject.Properties.Name -contains 'Drivers')) -or
            ($null -eq $script:DriverConfigInfo.Drivers)
        ) {
            throw 'Driver configuration data is not loaded or is not in the expected wrapper format.'
        }

        $driverNames = @($script:DriverConfigInfo.Drivers.Name)

        if ($DriverName -notin $driverNames) {
            throw ('The specified driver "{0}" is not found in the driver configuration data. The current list of drivers is:{1}{2}' -f $DriverName, $script:CRLF, ($driverNames -join $script:CRLF))
        }

        if ($null -eq $script:ServerListData) {
            throw 'ServerList.json data is not loaded. Unable to determine target environments.'
        }

        $TargetServers         = [System.Collections.Generic.List[string]]::new()
        $SelectedEnvironments  = [System.Collections.Generic.List[string]]::new()
        $AvailableEnvironments = @($script:AvailableEnvironments)

        if (@($AvailableEnvironments).Count -eq 0) {
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
            if (-not $Environments -or @($Environments).Count -eq 0) {
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

            if ($SelectedEnvironments.Count -eq 0) {
                Write-Warning ('No valid environments were resolved. Available environments: {0}' -f ($AvailableEnvironments -join ', '))
                return
            }

            Write-Verbose ('The current user {0} will target the following Willow EPS environments: {1}' -f $currentUser, ($SelectedEnvironments -join ', '))
        }
        else {
            Write-Verbose ('The current user {0} is mapped to the following Willow EPS environments and those targets will be used: {1}' -f $currentUser, ($SelectedEnvironments -join ', '))
        }

        foreach ($environmentName in $SelectedEnvironments) {
            if (-not ($script:ServerListData.PSObject.Properties.Name -contains $environmentName)) {
                continue
            }

            $environmentConfig = $script:ServerListData.$environmentName
            if ($null -eq $environmentConfig -or $null -eq $environmentConfig.Servers) {
                continue
            }

            foreach ($server in @($environmentConfig.Servers)) {
                if ($TargetServers -notcontains $server) {
                    $null = $TargetServers.Add($server)
                }
            }
        }

        if ($TargetServers.Count -eq 0) {
            Write-Warning ('No target servers were resolved for the requested environment selection. Available environments: {0}' -f ($AvailableEnvironments -join ', '))
            return
        }

        if (-not [string]::IsNullOrWhiteSpace($RemotePrinterName)) {
            $LocalPrinterName = $PrinterName
            $PortName         = '{0}-LPR' -f $LocalPrinterName
        }
        else {
            $LocalPrinterName = $PrinterName
            $PortName         = 'IP_{0}' -f $IPAddress
        }
    }

    process {
        foreach ($server in $TargetServers) {
            if (-not $PSCmdlet.ShouldProcess($server, "Configure printer '$PrinterName'")) {
                continue
            }

            $portExists = $false
            try {
                $portExists = Confirm-WEPSPrinterPort -ComputerName $server -PortName $PortName
            }
            catch {
                Write-Error "Failed to determine whether port '$PortName' exists on server '$server'. Error: $_"
                continue
            }

            if ($portExists) {
                Write-Verbose "Port '$PortName' already exists on server '$server'."
            }
            else {
                if ([string]::IsNullOrWhiteSpace($RemotePrinterName)) {
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
                    Add-WEPSPrinterPort @AddPortParams -ErrorAction Stop
                    Write-Verbose "Successfully created port '$PortName' on server '$server'."
                }
                catch {
                    Write-Error "Failed to create port '$PortName' on server '$server'. Error: $_"
                    continue
                }
            }

            try {
                $existingPrinter = Get-Printer -ComputerName $server -Name $PrinterName -ErrorAction SilentlyContinue
                if ($null -ne $existingPrinter) {
                    Write-Verbose "Printer '$PrinterName' already exists on server '$server'. Skipping."
                    continue
                }
            }
            catch {
                Write-Error "Failed to query printer '$PrinterName' on server '$server'. Error: $_"
                continue
            }

            if (-not $PSCmdlet.ShouldProcess($server, "Add printer '$PrinterName'")) {
                continue
            }

            try {
                Add-Printer -ComputerName $server -Name $PrinterName -DriverName $DriverName -PortName $PortName -ErrorAction Stop
                Write-Verbose "Successfully added printer '$PrinterName' on server '$server'."
            }
            catch {
                Write-Error "Failed to add printer '$PrinterName' on server '$server'. Error: $_"
            }
        }
    }
}