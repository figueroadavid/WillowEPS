function Remove-WEPSPrinter {
    <#
        .SYNOPSIS
            The script removes printer(s) from specified Willow EPS print servers.
        .DESCRIPTION
            Based on the user running the script, it will remove a given printer from the
            environments associated with the current account, or from the environments
            explicitly specified with -Environments.
        .PARAMETER PrinterName
            The name of the printer(s) to be removed.
        .PARAMETER Environments
            One or more environment names from ServerList.json.
            If the current user matches an Account entry in ServerList.json, those
            mapped environments are used automatically and this parameter is ignored.
        .NOTES
            Ensure you have the necessary permissions to remove printers on the target print servers.
            If the script is run under one of the configured service accounts, it will only remove
            printers from the servers associated with that account.
        .EXAMPLE
            PS C:\> Remove-WEPSPrinter -PrinterName PRN-01, PRN-02 -Environments PRD

            Removes printers named PRN-01 and PRN-02 from the PRD Willow EPS print servers.
        .EXAMPLE
            PS C:\> Remove-WEPSPrinter -PrinterName PRN-03 -Environments PRD,TST
            Removes a printer named PRN-03 from the PRD and TST Willow EPS print servers.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string[]]$PrinterName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Environments
    )

    begin {
        if (-not $script:ServerListData) {
            throw 'ServerList.json data is not loaded. Unable to determine target environments.'
        }

        $TargetServers = [System.Collections.Generic.List[string]]::new()
        $SelectedEnvironments = [System.Collections.Generic.List[string]]::new()
        $AvailableEnvironments = @($script:AvailableEnvironments)

        foreach ($environmentName in $AvailableEnvironments) {
            $environmentConfig = $script:ServerListData.$environmentName
            if ($null -ne $environmentConfig -and $environmentConfig.Account -eq $env:USERNAME) {
                if ($SelectedEnvironments -notcontains $environmentName) {
                    $null = $SelectedEnvironments.Add($environmentName)
                }
            }
        }

        if ($SelectedEnvironments.Count -eq 0) {
            if (-not $Environments -or $Environments.Count -eq 0) {
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

            $Message = 'The current user {0} will be used to remove printer(s) from the following Willow EPS environments in a single operation: {1}' -f $env:USERNAME, ($SelectedEnvironments -join ', ')
            Write-Verbose -Message $Message
        }
        else {
            $Message = 'The current user {0} is mapped to the following Willow EPS environments and those targets will be used: {1}' -f $env:USERNAME, ($SelectedEnvironments -join ', ')
            Write-Verbose -Message $Message
        }

        foreach ($environmentName in $SelectedEnvironments) {
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
            Write-Warning ('No target servers were resolved. Available environments: {0}' -f ($AvailableEnvironments -join ', '))
            return
        }
    }

    process {
        foreach ($server in $TargetServers) {
            $PSMessage = 'Remove printer(s) [{0}] on {1}' -f ($PrinterName -join ','), $server
            if ($PSCmdlet.ShouldProcess($PSMessage, '', '')) {
                foreach ($printer in $PrinterName) {
                    try {
                        Remove-Printer -Name $printer -ComputerName $server -ErrorAction Stop
                        Write-Verbose -Message ('Printer "{0}" removed from computer "{1}".' -f $printer, $server)
                    }
                    catch {
                        Write-Warning -Message ('Failed to remove printer(s) [{0}] from computer "{1}": {2}' -f ($PrinterName -join ','), $server, $_)
                    }
                }
            }
        }
    }
}