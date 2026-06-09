# Export-WEPSPrinterConfigData

## Synopsis
Exports printer configuration data to a `.dat` file using `PrintUIEntry`.

## Description
`Export-WEPSPrinterConfigData` exports the configuration data of an existing printer to a specified file. It validates that the printer exists, resolves the output file path, and invokes `rundll32.exe` with `printui.dll` to perform the export.

The function captures process exit codes and standard error output. If the export fails, an error is written. On success, a confirmation string is returned.

## Parameters

### -PrinterName
Specifies the name of the printer to export.

- Type: String  
- Required: Yes  
- Accepts pipeline input: ByPropertyName  

### -FileName
Specifies the output file path for the exported configuration.

If not provided, a filename is generated using `Convert-ToValidFileName` with a `.dat` extension.

- Type: String  
- Required: No  
- Default: Generated from `PrinterName`  

## Inputs
System.String

## Outputs
System.String

Returns a success message when the export operation completes successfully. Writes an error if the operation fails.

## Examples

### Example
```powershell
Export-WEPSPrinterConfigData -PrinterName 'HP-LaserJet-01'
```

### Example
```powershell
Export-WEPSPrinterConfigData -PrinterName 'HP-LaserJet-01' -FileName 'C:\Temp\HP-LaserJet-01.dat'
```

## Notes
* Uses `rundll32.exe` with `printui.dll,PrintUIEntry /Ss` to export configuration data.
* The printer must exist; otherwise, a terminating error is thrown.
* The process is started with the RunAs verb. Elevation behavior depends on the hosting session.
* File paths are resolved before invocation and quoted only within the argument string.
* Exit codes other than 0 are treated as failures, and standard error output is captured when available.