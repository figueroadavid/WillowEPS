function Confirm-WEPSPrinterPort {
    <#
    .SYNOPSIS
        Tests whether a printer port exists on a target computer.
    .DESCRIPTION
        Uses Get-PrinterPort to determine if the specified port exists
        on the target system.
    .PARAMETER ComputerName
        The target computer on which to check for the printer port.
        Defaults to the local computer.
    .PARAMETER PortName
        The name of the printer port to check.
    .EXAMPLE
        Confirm-WEPSPrinterPort -ComputerName "PRINTSERVER01" -PortName "PRN-01-LPR"
        Returns $true if the port exists.
    .EXAMPLE
        Confirm-WEPSPrinterPort -ComputerName "PRINTSERVER01" -PortName "IP_192.0.2.10"
        Returns $false if the port does not exist.
    #>

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$PortName
    )

    try {
        $null = Get-PrinterPort -ComputerName $ComputerName -Name $PortName -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}