# Add-WEPSPrinterPort

## Description

`Add-WEPSPrinterPort` is a public function within the WillowEPS module used to ensure that a printer port exists on a target system. It checks whether a specified printer port is already present and creates it if it is missing. The function supports both standard TCP/IP ports and LPR-based ports, automatically selecting the appropriate configuration based on the parameters provided. It is designed to be idempotent, meaning that if the port already exists, no changes are made.


## Parameters

`ComputerName` (string, optional)
The target computer where the port will be validated or created. Defaults to the local computer.

`IPAddress` (string, required)
The IP address associated with the printer port. Must be a valid IP address. For standard ports, this represents the printer itself. For LPR ports, this represents the LPD server.

`LocalPrinterName` (string, required for LPR)
The local printer name used to construct the LPR port name. Required when creating LPR ports.

`RemotePrinterName` (string, required for LPR)
The remote queue name on the LPD server. Required when using LPR configuration.

## Notes

* Requires administrative permissions on the target system.
* Supports ShouldProcess, allowing use of -WhatIf and -Confirm.
* Uses Confirm-WEPSPrinterPort to determine whether a port already exists.
* Port naming conventions are enforced:
  - Standard TCP/IP ports use IP_<IPAddress>
  - LPR ports use LPR_<LocalPrinterName>
* LPR ports are created with byte counting enabled.
* If the port already exists, the function exits without modification.
* If port creation fails, an exception is thrown and execution stops for that operation.

## Examples

Create a standard TCP/IP printer port on the local system:
```powershell
Add-WEPSPrinterPort -IPAddress 192.0.2.10
```

Create a standard TCP/IP printer port on a remote server:
```powershell
Add-WEPSPrinterPort -ComputerName 'PrintServer01' -IPAddress 192.0.2.11
```

Create an LPR printer port on a remote server:
```powershell
Add-WEPSPrinterPort -ComputerName 'PrintServer02' -LocalPrinterName 'PRN-01' -RemotePrinterName 'PRN-01' -IPAddress 198.51.100.25
```

Validate behavior without making changes:
```powershell
Add-WEPSPrinterPort -ComputerName 'PrintServer01' -IPAddress 192.0.2.12 -WhatIf
```

Pipeline usage for standard TCP/IP ports:
```powershell
[pscustomobject]@{ ComputerName='PrintServer03'; IPAddress='192.0.2.13' } | Add-WEPSPrinterPort
```

Pipeline usage for LPR ports:
```powershell
[pscustomobject]@{ ComputerName='PrintServer04'; LocalPrinterName='PRN-02'; RemotePrinterName='QUEUE-02'; IPAddress='198.51.100.30' } | Add-WEPSPrinterPort
```