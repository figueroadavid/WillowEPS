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
    #>

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string[]]$PrinterName
    )

    foreach ($printer in $PrinterName) {

        # --- Get printer safely ---
        try {
            $printerObj = Get-Printer -Name $printer -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to query printer '$printer'. Error: $($_.Exception.Message)"
            continue
        }

        if ($null -eq $printerObj) {
            Write-Warning "Printer '$printer' not found. Skipping."
            continue
        }

        $portName = $printerObj.PortName

        # --- Get port safely ---
        try {
            $portObj = Get-PrinterPort -Name $portName -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to query port '$portName' for printer '$printer'. Error: $($_.Exception.Message)"
            continue
        }

        if ($null -eq $portObj) {
            Write-Warning "Port '$portName' for printer '$printer' not found. Skipping."
            continue
        }

        # --- Detect LPR more reliably ---
        if ($portObj.PSObject.Properties.Name -contains 'LprQueueName' -and $portObj.LprQueueName) {
            Write-Warning "Printer '$printer' uses an LPR port which is not supported. Skipping."
            continue
        }

        # --- Validate address ---
        if (-not $portObj.PrinterHostAddress) {
            Write-Warning "Printer '$printer' does not have a valid host address. Skipping."
            continue
        }

        $url = "http://{0}" -f $portObj.PrinterHostAddress

        Write-Verbose "Opening web page for printer '$printer' at $url"

        try {
            Start-Process -FilePath $url
        }
        catch {
            Write-Warning "Failed to open web page for printer '$printer'. Error: $($_.Exception.Message)"
        }
    }
}