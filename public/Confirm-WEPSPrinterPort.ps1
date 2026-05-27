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
    catch [Microsoft.Management.Infrastructure.CimException] {
        # Expected case: port does not exist
        return $false
    }
    catch {
        # Unexpected failure → propagate
        throw "Failed to query printer port '$PortName' on '$ComputerName'. Error: $($_.Exception.Message)"
    }
}