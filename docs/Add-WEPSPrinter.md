# Add-WEPSPrinter

## Description

Add-WEPSPrinter is a public function within the WillowEPS module used to deploy printers across one or more Willow EPS environments. It handles the full lifecycle of printer creation, including port validation, port creation (TCP/IP or LPR), and printer installation using a validated driver configuration.

The function determines target environments automatically based on user-to-environment mappings when available, or uses explicitly supplied environments when necessary. It ensures that required ports exist on each target server before attempting to create the printer. If port creation fails, printer creation is skipped for that server.

---

## Parameters

- `PrinterName` (string, required)
  The name of the printer to create on the target print servers.

- `IPAddress` (string, required)
  The IP address of the printer or LPD server. Must be a valid IPv4 or IPv6 address.

- `DriverName` (string, required)
  The driver to assign to the printer. This must exist in the loaded DriverConfigInfo.json data.

- `Environments` (string[], optional)
  One or more Willow EPS environments to target. If not supplied, environments are resolved automatically based on the current user mapping in ServerList.json, or if the user is not listed, the user is presented with a menu of environments to select from.

- `RemotePrinterName` (string, optional)
  If specified, an LPR port is created instead of a standard TCP/IP port. This represents the remote queue name on the LPD server.

---

## Notes

- `DriverConfigInfo.json` must be loaded prior to execution.
- `ServerList.json` must be loaded to resolve environments and target servers.
- The specified driver must exist in the driver configuration data.
- The current user mapping may override manual environment selection.
- Port creation failures prevent printer creation on that server.
- Supports `-WhatIf` and `-Confirm` due to SupportsShouldProcess.
- Requires administrative privileges on target print servers.

---

## Behavior

- Resolves target environments:
  - If user mapping exists → automatically select environments
  - Otherwise → use provided Environments parameter
- Resolves all servers associated with selected environments
- Determines port type:
  - TCP/IP port if RemotePrinterName is not provided
  - LPR port if RemotePrinterName is provided
- Checks if port exists:
  - If not → creates port
  - If creation fails → skips printer creation
- Checks if printer already exists:
  - If exists → skips creation
- Creates printer using Add-Printer on each target server

---

## Examples

Add a printer to a single environment using TCP/IP port:
```powershell
Add-WEPSPrinter -PrinterName 'PRN-01' -IPAddress 192.0.2.10 -DriverName 'Generic Universal Print Driver' -Environments PRD
```

Add a printer to multiple environments:
```powershell
Add-WEPSPrinter -PrinterName 'PRN-02' -IPAddress 192.0.2.11 -DriverName 'Generic Universal Print Driver' -Environments PRD,TST
```

Add a printer using an LPR port:
```powershell
Add-WEPSPrinter -PrinterName 'PRN-03-LPR' -IPAddress 198.51.100.25 -DriverName 'Generic Universal Print Driver' -Environments SUP -RemotePrinterName 'PRN-03'
```

Automatic environment resolution based on user mapping:
```powershell
Add-WEPSPrinter -PrinterName 'PRN-04' -IPAddress 192.0.2.20 -DriverName 'Generic Universal Print Driver'
```

Bulk deployment example:
```powershell
@(
    @{ PrinterName='PRN-05'; IPAddress='192.0.2.21'; DriverName='Generic Universal Print Driver' },
    @{ PrinterName='PRN-06'; IPAddress='192.0.2.22'; DriverName='Generic Universal Print Driver' }
) | Add-WEPSPrinter 
```
---

## Related Functions

- Add-WEPSPrinterPort
- Confirm-WEPSPrinterPort