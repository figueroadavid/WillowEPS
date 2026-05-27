function Add-WEPSPrinterPort {
    <#
    .SYNOPSIS
        Checks for and creates a printer port on a target system if it does not exist.
    .DESCRIPTION
        Ensures that a specified printer port exists on a target computer. If the port
        does not exist, it is created using either LPR or standard TCP/IP configuration.
    .PARAMETER ComputerName
        The target computer on which to manage the printer port.
    .PARAMETER LocalPrinterName
        The local printer name used to construct the LPR port name.
    .PARAMETER RemotePrinterName
        The remote queue name on the LPR host.
    .PARAMETER IPAddress
        The IP address of the printer or LPR host.
    .NOTES
        Supports two modes:
        - LPR Port Mode: Requires LocalPrinterName, RemotePrinterName, and IPAddress.
        - TCP/IP Port Mode: Requires only IPAddress.
    .EXAMPLE
        Add-WEPSPrinterPort -ComputerName "PRINTSERVER01" -IPAddress 192.0.2.10
        Creates a standard TCP/IP port if it does not already exist.
    .EXAMPLE
        Add-WEPSPrinterPort -ComputerName "PRINTSERVER01" -LocalPrinterName "PRN-01" -RemotePrinterName "QUEUE01" -IPAddress 198.51.100.20
        Creates an LPR port if it does not already exist.
    #>

    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Standard')]
    param(
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LPR')]
        [string]$LocalPrinterName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'LPR')]
        [string]$RemotePrinterName,

        [Parameter(ParameterSetName = 'Standard')]
        [Parameter(ParameterSetName = 'LPR')]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({ [System.Net.IPAddress]::TryParse($_, [ref]$null) })]
        [string]$IPAddress
    )

    switch ($PSCmdlet.ParameterSetName) {
        'LPR' {
            $PortName = '{0}-LPR' -f $LocalPrinterName
        }
        'Standard' {
            $PortName = 'IP_{0}' -f $IPAddress
        }
    }

    try {
        $null = Get-PrinterPort -Name $PortName -ComputerName $ComputerName -ErrorAction Stop
        Write-Verbose ('Port "{0}" already exists on computer "{1}".' -f $PortName, $ComputerName)
        return
    }
    catch {
        Write-Verbose ('Port "{0}" does not exist on computer "{1}". Creating.' -f $PortName, $ComputerName)
    }

    if ($PSCmdlet.ShouldProcess($ComputerName, "Create port '$PortName'")) {
        switch ($PSCmdlet.ParameterSetName) {
            'LPR' {
                $PortParams = @{
                    Name                   = $PortName
                    LprQueueName           = $RemotePrinterName
                    LprHostAddress         = $IPAddress
                    LprByteCountingEnabled = $true
                    ComputerName           = $ComputerName
                }
            }
            'Standard' {
                $PortParams = @{
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
}