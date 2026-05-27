function Add-WEPSPrinterPort {
    <#
    .SYNOPSIS
        Ensures a printer port exists on a target system.
    .DESCRIPTION
        Checks whether a specified printer port exists on a target computer and
        creates it if it does not, using either LPR or standard TCP/IP configuration.
    #>

    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Standard')]
    param(
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LPR')]
        [string]$LocalPrinterName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LPR')]
        [string]$RemotePrinterName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'Standard')]
        [Parameter(ParameterSetName = 'LPR')]
        [ValidateScript({ [System.Net.IPAddress]::TryParse($_, [ref]$null) })]
        [string]$IPAddress
    )

    # --- Determine PortName ---
    switch ($PSCmdlet.ParameterSetName) {
        'LPR' {
            $PortName = '{0}-LPR' -f $LocalPrinterName
        }
        'Standard' {
            $PortName = 'IP_{0}' -f $IPAddress
        }
    }

    # --- Check existence using standard module helper ---
    $portExists = $false
    try {
        $portExists = Confirm-WEPSPrinterPort -ComputerName $ComputerName -PortName $PortName
    }
    catch {
        throw "Failed to determine whether port '$PortName' exists on '$ComputerName'. Error: $_"
    }

    if ($portExists) {
        Write-Verbose ('Port "{0}" already exists on computer "{1}".' -f $PortName, $ComputerName)
        return
    }

    Write-Verbose ('Port "{0}" does not exist on computer "{1}". Creating.' -f $PortName, $ComputerName)

    # --- Create port ---
    if (-not $PSCmdlet.ShouldProcess($ComputerName, "Create printer port '$PortName'")) {
        return
    }

    $PortParams = switch ($PSCmdlet.ParameterSetName) {
        'LPR' {
            @{
                Name                   = $PortName
                LprQueueName           = $RemotePrinterName
                LprHostAddress         = $IPAddress
                LprByteCountingEnabled = $true
                ComputerName           = $ComputerName
            }
        }
        'Standard' {
            @{
                Name             = $PortName
                PrinterIPAddress = $IPAddress
                ComputerName     = $ComputerName
            }
        }
    }

    try {
        Add-PrinterPort @PortParams -ErrorAction Stop
        Write-Verbose ('Port "{0}" created on computer "{1}".' -f $PortName, $ComputerName)
    }
    catch {
        throw ('Failed to create port "{0}" on computer "{1}". Error: {2}' -f $PortName, $ComputerName, $_.Exception.Message)
    }
}