function Add-WEPSPrinterPort {
    <#
    .SYNOPSIS
        Ensures a printer port exists on a target system.
    .DESCRIPTION
        Checks whether a specified printer port exists on a target computer and
        creates it if it does not, using either LPR or standard TCP/IP configuration.
    .PARAMETER ComputerName
        The name of the target computer on which to check for and potentially create the printer port. Defaults to the local computer.
    .PARAMETER LocalPrinterName 
        The name of the local printer to associate with the port when using LPR configuration. Required if using the 'LPR' parameter set.
    .PARAMETER RemotePrinterName
        The name of the remote printer queue to associate with the port when using LPR configuration. Required if using the 'LPR' parameter set.
    .PARAMETER IPAddress
        The IP address of the printer port, and must be a valid IP address format.
        If the port is a standard TCP/IP port, this is the address of the printer. If the port is an LPR port, 
        this is the address of the LPD server.
    .NOTES
        Ensure you have the necessary permissions to create printer ports on the target system.
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
            $PortName = 'LPR-{0}' -f $LocalPrinterName
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