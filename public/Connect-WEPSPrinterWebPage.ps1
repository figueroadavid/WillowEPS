function Connect-WEPSPrinterWebPage {
    <#
    .SYNOPSIS
        Connects to a printer's web page.
    .DESCRIPTION
        Retrieves the printer's port information and opens the device web interface
        in the default browser using the resolved host address. Printers using LPR
        ports are not supported and are skipped.
    .PARAMETER PrinterName
        One or more printer names to connect to.
    .EXAMPLE
        Connect-WEPSPrinterWebPage -PrinterName "PRN-01","PRN-02"
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$PrinterName
    )

    foreach ($printer in $PrinterName) {
        $thisPortName = (Get-Printer -Name $printer -ErrorAction SilentlyContinue).PortName

        if (-not $thisPortName) {
            Write-Warning "Printer '$printer' not found. Skipping."
            continue
        }

        $thisPort = Get-PrinterPort -Name $thisPortName -ErrorAction SilentlyContinue

        if (-not $thisPort) {
            Write-Warning "Port '$thisPortName' for printer '$printer' not found. Skipping."
            continue
        }

        if ($thisPort.PortNumber -eq 515) {
            Write-Warning "Printer '$printer' uses an LPR port which is not supported. Skipping."
            continue
        }

        $url = "http://{0}" -f $thisPort.PrinterHostAddress
        Start-Process -FilePath $url
    }
}