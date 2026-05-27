function Remove-WEPSPrinterPort {
    <#
    .SYNOPSIS
        Script removes printer port(s) from specified Willow EPS print servers.
    .DESCRIPTION
        The script removes printer port(s) from one or more Willow EPS environments.
        The environments are determined either by the current user's mapped account
        in ServerList.json or explicitly via the -Environments parameter.
    .PARAMETER PortName
        The name of the printer port(s) to be removed.
    .PARAMETER Environments
        One or more Willow EPS environments to target. Available environments are
        sourced from the ServerList.json data loaded into the module.
        If the current user is mapped to environments via account name, this parameter is ignored.
    .NOTES
        Ensure you have the necessary permissions to remove printer ports on the target print servers.
        If the script is run under one of the service accounts, it will only remove printer ports from the servers
        associated with that account.
    .EXAMPLE
        PS C:\> Remove-WEPSPrinterPort -PortName IP_192.0.2.10 -Environments PRD

        Removes the printer port named IP_192.0.2.10 from the PRD Willow EPS print servers.
    .EXAMPLE
        PS C:\> Remove-WEPSPrinterPort -PortName IP_192.0.2.11 -Environments PRD,TST

        Removes the printer port named IP_192.0.2.11 from both the PRD and TST Willow EPS print servers.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$PortName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Environments
    )

    begin {
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
                Write-Warning ('You must specify -Environments. Available environments: {0}' -f ($AvailableEnvironments -join ', '))
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
                Write-Warning ('No valid environments were specified. Available environments: {0}' -f ($AvailableEnvironments -join ', '))
                return
            }

            Write-Verbose ('The current user {0} will be used to remove printer port(s) from the following Willow EPS environments: {1}' -f $currentUser, ($SelectedEnvironments -join ', '))
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
            Write-Warning ('No target servers were resolved. Available environments: {0}' -f ($AvailableEnvironments -join ', '))
            return
        }
    }

    process {
        foreach ($server in $TargetServers) {
            if (-not $PSCmdlet.ShouldProcess($server, "Remove printer port '$PortName'")) {
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

            if (-not $portExists) {
                Write-Warning "Port '$PortName' does not exist on server '$server'. Skipping."
                continue
            }

            try {
                Remove-PrinterPort -Name $PortName -ComputerName $server -ErrorAction Stop
                Write-Verbose "Port '$PortName' removed from server '$server'."
            }
            catch {
                Write-Warning "Failed to remove port '$PortName' from server '$server'. Error: $_"
            }
        }
    }
}