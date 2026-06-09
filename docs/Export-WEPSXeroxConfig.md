# Export-WEPSXeroxConfig

## Synopsis
Exports a subset of registry values for a given printer into a JSON file.

## Description
`Export-WEPSXeroxConfig` exports a defined allow-list of registry values for a printer driver configuration into a JSON file. This output is intended to support replication of configuration settings via a companion import process.

The function targets specific registry paths under:

- `HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers\<PrinterName>\`
- `HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers\<PrinterName>\DSDriver\`
- `HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers\<PrinterName>\PrinterDriverData\`

Only explicitly allow-listed values are included in the export.

Values of type `REG_BINARY` are converted to Base64 strings to ensure JSON serialization compatibility.

This function is primarily designed for Xerox Global Print Driver (PCL6), version `5591.900.0.0`, and focuses on capturing configuration elements such as stapling, tray mappings, and other registry-backed settings.

Behavior with non-Xerox drivers or different driver versions is not guaranteed.

## Parameters

### -PrinterName
Specifies the name of the printer to export configuration from. This must match a valid installed printer.

- Type: String  
- Required: Yes  

### -FilePath
Specifies the output file path for the JSON export.

If the provided path does not end with `.json`, the extension is appended automatically.

- Type: String  
- Required: Yes  

### -Force
Overwrites the destination file if it already exists.

If not specified and the file exists, the operation is skipped.

- Type: Switch  
- Required: No  

## Inputs
None

## Outputs
None

Writes JSON data to the specified file. Emits warnings when applicable.

## Examples

### Example
```powershell
Export-WEPSXeroxConfig -PrinterName 'PRN-01' -FilePath 'C:\Temp\PRN-01.json'
```

### Example
```powershell
Export-WEPSXeroxConfig -PrinterName 'PRN-02' -FilePath 'C:\Temp\PRN-02' -Verbose
```

### Example
```powershell
Export-WEPSXeroxConfig -PrinterName 'PRN-03' -FilePath 'C:\Temp\PRN-03.json' -Force
```

### Example
```powershell
Get-Printer -Name 'PRN-*' | ForEach-Object {
    Export-WEPSXeroxConfig -PrinterName $_.Name -FilePath ('C:\Temp\{0}.json' -f $_.Name)
}
```

## Notes
* Designed primarily for `Xerox Global Print Driver (PCL6)`.
* Targets specific registry-backed configuration relevant to Xerox printing features.
* Non-Xerox driver compatibility is not guaranteed.
* Binary registry values are Base64-encoded for JSON compatibility.
* Missing registry values are silently ignored.
* The function does not validate printer existence through Get-Printer; registry presence is used as the validation mechanism.

