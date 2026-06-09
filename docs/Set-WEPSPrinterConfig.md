# Set-WEPSPrinterConfig

## Synopsis
Applies a DAT configuration file to one or more printers based on each printer's installed driver name and driver version.

## Description
`Set-WEPSPrinterConfig` applies printer configuration data from a DAT file to one or more printers.

The function determines the correct DAT file by matching each target printer's installed driver name and driver version against entries in `$script:DriverConfigInfo.Drivers`.

This driver and version match is used as a safety check because DAT files are driver-version-specific. Applying a DAT file created for a different driver or driver version can corrupt printer configuration.

For each printer, the function:

- Validates that `rundll32.exe` exists under `%SystemRoot%\System32`
- Validates that driver configuration data is loaded in `$script:DriverConfigInfo.Drivers`
- Resolves the printer by name using `Get-Printer`
- Resolves the printer driver using `Get-PrinterDriver`
- Searches for exactly one matching driver configuration entry
- Validates that the matching DAT file path is populated and exists
- Applies the DAT file using `rundll32.exe` and `PrintUI.dll,PrintUIEntry /Sr`
- Reports failures with warnings and continues processing remaining printers

The function supports `ShouldProcess`, so `-WhatIf` and `-Confirm` can be used.

## Parameters

### -PrinterName
Specifies one or more printer names to which the DAT configuration file will be applied.

This parameter accepts pipeline input by property name.

The `Name` alias can also be used.

- Type: String[]
- Required: Yes
- Accepts pipeline input: ByPropertyName
- Alias: Name

### -ShowProgress
Displays progress information while printers are being processed.

Progress includes the current printer, current item count, total item count, and percent complete.

- Type: Switch
- Required: No
- Accepts pipeline input: ByPropertyName

## Inputs
System.String

You can pipe objects containing a `PrinterName` or `Name` property to this function.

## Outputs
None

This function does not return a success object. It writes warning, verbose, and progress output depending on execution results and supplied common parameters.

## Examples

### Example

Applies the correct DAT configuration file to a single printer based on its installed driver name and version.

```powershell
Set-WEPSPrinterConfig -PrinterName 'PRN-01'
```

### Example

Applies the correct DAT configuration file to multiple printers.

```powershell
Set-WEPSPrinterConfig -PrinterName 'PRN-01','PRN-02'
```

### Example

Applies the DAT configuration file and displays verbose output.

```powershell
Set-WEPSPrinterConfig -PrinterName 'PRN-01' -Verbose
```

### Example

Shows what would happen without applying the DAT configuration file.

```powershell
Set-WEPSPrinterConfig -PrinterName 'PRN-01' -WhatIf
```

### Example

Pipes printers into the function by property name and applies the matching DAT configuration file to each printer.

```powershell
Get-Printer -Name 'PRN-*' | Set-WEPSPrinterConfig
```

## Notes
- The function depends on `$script:DriverConfigInfo.Drivers` being loaded and valid.
- The function expects matching driver configuration entries to contain `Name`, `DriverVersion`, and `DATFilePath` properties.
- Driver matching requires both the driver name and driver version to match exactly.
- If no matching driver entry is found, the printer is skipped.
- If more than one matching driver entry is found, the printer is skipped to avoid ambiguity.
- If the DAT file path is empty or does not exist, the printer is skipped.
- The function uses `rundll32.exe` with `PrintUI.dll,PrintUIEntry /Sr` to apply the DAT file.
- The function applies configuration to local printers resolved by `Get-Printer`.
- The function uses `Get-PrinterDriver` to retrieve driver version information.
- The function waits 1.5 seconds after processing each printer.
- The function supports `-WhatIf` and `-Confirm` through `SupportsShouldProcess`.
- Failures for individual printers are written as warnings and do not stop processing of remaining printers.
- The function creates and disposes a `System.Diagnostics.Process` object for each DAT application attempt.

