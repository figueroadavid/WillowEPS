function Remove-WEPSPrinter {
    <#
    .SYNOPSIS
        Removes printer(s) from specified Willow EPS print servers.
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
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string[]]$PrinterName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Environments
    )

    begin {
        if (-not $script:ServerListData) {
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

            Write-Verbose ('The current user {0} will remove printers from: {1}' -f $currentUser, ($SelectedEnvironments -join ', '))
        }
        else {
            Write-Verbose ('User {0} mapped environments: {1}' -f $currentUser, ($SelectedEnvironments -join ', '))
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
            foreach ($printer in $PrinterName) {

                if (-not $PSCmdlet.ShouldProcess($server, "Remove printer '$printer'")) {
                    continue
                }

                try {
                    $existingPrinter = Get-Printer -ComputerName $server -Name $printer -ErrorAction SilentlyContinue

                    if ($null -eq $existingPrinter) {
                        Write-Verbose "Printer '$printer' does not exist on server '$server'. Skipping."
                        continue
                    }
                }
                catch {
                    Write-Error "Failed to query printer '$printer' on server '$server'. Error: $_"
                    continue
                }

                try {
                    Remove-Printer -Name $printer -ComputerName $server -ErrorAction Stop
                    Write-Verbose ('Printer "{0}" removed from server "{1}".' -f $printer, $server)
                }
                catch {
                    Write-Warning ('Failed to remove printer "{0}" from server "{1}": {2}' -f $printer, $server, $_.Exception.Message)
                }
            }
        }
    }
}
