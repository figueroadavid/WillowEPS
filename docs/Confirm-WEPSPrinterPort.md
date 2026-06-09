# Confirm-WEPSPrinterPort

## Description

`Confirm-WEPSPrinterPort` is a public function within the `WillowEPS` module used to determine whether a specified printer port exists on a target computer. It leverages `Get-PrinterPort` to perform the lookup and returns a Boolean result indicating whether the port is present. The function is designed to support validation logic in higher-level workflows and avoids modifying system state.

## Parameters

`ComputerName` (string, optional)
The target computer where the printer port will be checked. Defaults to the local computer.

`PortName` (string, required)
The name of the printer port to validate. This must match the exact port name as configured on the target system.

## Notes

* Returns $true if the specified port exists.
* Returns $false if the port does not exist.
* Handles expected "not found" conditions without throwing errors.
* Throws a terminating error for unexpected failures (e.g., connectivity or permission issues).
* Uses `Get-PrinterPort` with -ErrorAction Stop to enforce controlled error handling.
* Supports pipeline input by property name for ComputerName and PortName.
* Requires appropriate permissions to query printer configuration on the target system.

## Examples

Check if a port exists on the local system:
```powershell
Confirm-WEPSPrinterPort -PortName 'IP_192.0.2.10'
```

Check if a port exists on a remote server:
```powershell
Confirm-WEPSPrinterPort -ComputerName 'PrintServer01' -PortName 'IP_192.0.2.11'
```

Use in conditional logic:
```powershell
if (Confirm-WEPSPrinterPort -ComputerName 'PrintServer01' -PortName 'IP_192.0.2.12') {
    Write-Host 'Port exists'
}
else {
    Write-Host 'Port does not exist'
}
```

Pipeline usage with property binding:
```powershell
[pscustomobject]@{ ComputerName='PrintServer02'; PortName='IP_192.0.2.13' } | Confirm-WEPSPrinterPort
```

Use in conjunction with port creation logic:
```powershell
if (-not (Confirm-WEPSPrinterPort -ComputerName 'PrintServer03' -PortName 'IP_192.0.2.14')) {
    Add-WEPSPrinterPort -ComputerName 'PrintServer03' -IPAddress 192.0.2.14
}
```