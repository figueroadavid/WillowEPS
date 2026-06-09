# Remove-WEPSPrinter

## Synopsis
Removes one or more printers from resolved Willow EPS print servers.

## Description
`Remove-WEPSPrinter` removes one or more printers from one or more Willow EPS print servers.

The target print servers are resolved from module-loaded `ServerList.json` data. The function first attempts to map the current user, based on `$env:USERNAME`, to environments defined in `$script:ServerListData`. If the current user matches an `Account` entry for one or more environments, those mapped environments are used automatically.

If no environments are mapped to the current user, the function uses the environments provided through `-Environments`.

For each selected environment, the function collects the configured servers and attempts to remove each specified printer from each target server.

Before removal, the function checks whether the printer exists on the target server by using `Get-Printer`. If the printer does not exist, that server/printer combination is skipped.

The function supports `ShouldProcess`, so `-WhatIf` and `-Confirm` can be used.

## Parameters

### -PrinterName
Specifies one or more printer names to remove.

This parameter accepts pipeline input by property name.

The `Name` alias can also be used.

- Type: String[]
- Required: Yes
- Accepts pipeline input: ByPropertyName
- Alias: Name

### -Environments
Specifies one or more environment names from `ServerList.json`.

If the current user matches an `Account` entry in `ServerList.json`, the mapped environments are used automatically and this parameter is ignored.

If the current user is not mapped to any environments, this parameter is required for the function to resolve target servers.

Invalid environment names are skipped with a warning.

- Type: String[]
- Required: No
- Accepts pipeline input: ByPropertyName

## Inputs
System.String

You can pipe objects containing a `PrinterName` or `Name` property to this function.

## Outputs
None

This function does not return a success object. It writes verbose, warning, or error output depending on the result of each operation.

## Examples

### Example

```powershell
Remove-WEPSPrinter -PrinterName 'PRN-01'
```
Removes `PRN-01` from the print servers associated with the current user's mapped environments.

If the current user is not mapped to any environments, the function writes a warning requiring `-Environments`.

### Example
```powershell
Remove-WEPSPrinter -PrinterName 'PRN-01' -Environments 'Prod'
```

Removes `PRN-01` from the servers associated with the `Prod` environment.

This applies only when the current user is not already mapped to environments in `ServerList.json`.

### Example
```powershell
Remove-WEPSPrinter -PrinterName 'PRN-01','PRN-02'
```

Removes both `PRN-01` and `PRN-02` from all resolved target servers.

### Example
```powershell
Remove-WEPSPrinter -PrinterName 'PRN-01' -Environments 'Prod','Test'
```

Removes `PRN-01` from all servers associated with the `Prod` and `Test` environments.

This applies only when the current user is not already mapped to environments in `ServerList.json`.


## Notes
- The function depends on `$script:ServerListData` being loaded.
- The function uses `$script:AvailableEnvironments` when available.
- If `$script:AvailableEnvironments` is empty, available environments are derived from the property names in `$script:ServerListData`.
- User-to-environment mapping is based on `$env:USERNAME` matching an environment `Account` value.
- If the current user is mapped to one or more environments, the `-Environments` parameter is ignored.
- If the current user is not mapped and `-Environments` is not provided, the function writes a warning and returns.
- Invalid environment names are skipped with a warning.
- If no target servers are resolved, the function writes a warning and returns.
- The function checks for printer existence with `Get-Printer` before calling `Remove-Printer`.
- If a printer does not exist on a server, that printer/server combination is skipped.
- Query failures are written as errors.
- Removal failures are written as warnings.
- The function supports `-WhatIf` and `-Confirm` through `SupportsShouldProcess`.
