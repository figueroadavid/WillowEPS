# Connect-WEPSPrinterWebPage

## Description

`Connect-WEPSPrinterWebPage` is a public function within the WillowEPS module used to open the web interface of one or more printers in the default browser. The function retrieves the printer object, resolves its associated port, and determines the host address required to access the device’s web interface. It is designed for quick access to printer management pages without requiring manual lookup of IP addresses.

The function performs validation at each step to ensure the printer and its associated port are valid and accessible. Printers configured with LPR ports are not supported, as LPR ports do not provide a direct host address suitable for browser access. Unsupported printers are skipped with a warning.

## Parameters

`PrinterName` (string[], optional)
One or more printer names to connect to. Supports pipeline input by property name and alias "Name". Each printer name must exist on the system where the function is executed.

## Notes

* Only printers using standard TCP/IP ports are supported.
* Printers using LPR ports are automatically skipped.
* Requires that the printer port exposes a valid PrinterHostAddress.
* Uses Get-Printer to retrieve printer metadata.
* Uses Get-PrinterPort to resolve port configuration details.
* Uses Start-Process to launch the default browser.
* Warning messages are generated for:
    - Missing printers
    - Missing ports
    - Unsupported LPR ports
    - Missing or invalid host addresses
* Errors related to process execution are handled and converted to warnings.
* Function does not modify system state; it is read-only with respect to printer configuration.

## Behavior

- Iterates through each supplied printer name
- Retrieves the printer object using Get-Printer
- Extracts the associated port name
- Retrieves port details using Get-PrinterPort
- Determines whether the port is LPR-based:
  - If LPR → skip with warning
- Validates that a PrinterHostAddress exists
- Constructs a URL using the format http://<PrinterHostAddress>
- Launches the URL using the system default browser

## Examples

Open the web page for a single printer:
```powershell
Connect-WEPSPrinterWebPage -PrinterName 'PRN-01'
```

Open web pages for multiple printers:
```powershell
Connect-WEPSPrinterWebPage -PrinterName 'PRN-01','PRN-02'
```

Pipeline usage with direct property binding:
```powershell
[pscustomobject]@{ Name='PRN-03' } | Connect-WEPSPrinterWebPage
```

Bulk usage pattern:
```powershell
@('PRN-04','PRN-05','PRN-06') | ForEach-Object { Connect-WEPSPrinterWebPage -PrinterName $_ }
```

Use with verbose output:
```powershell
Connect-WEPSPrinterWebPage -PrinterName 'PRN-07' -Verbose
```