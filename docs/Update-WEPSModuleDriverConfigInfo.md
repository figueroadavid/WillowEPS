# Update-WEPSModuleDriverConfigInfo

## Synopsis
Reloads driver configuration data from the configured driver configuration JSON file into module scope.

## Description
`Update-WEPSModuleDriverConfigInfo` reads the JSON file located at `$script:DriverConfigInfoPath`, converts the JSON content into PowerShell objects, and stores the result in `$Script:DriverConfigData`.

This function does not scan installed printer drivers. It reloads the driver configuration data from the configured JSON file path.

## Parameters
None.

## Inputs
None.

## Outputs
None.

This function does not emit output. It updates `$Script:DriverConfigData` in module scope.

## Examples

### Example

Reloads the driver configuration data from `$script:DriverConfigInfoPath`.

```powershell
Update-WEPSModuleDriverConfigInfo
```

### Example

Reloads the driver configuration data, then displays the module-scoped data variable.

```powershell
Update-WEPSModuleDriverConfigInfo

$Script:DriverConfigData
```

### Example

Reloads the driver configuration data before retrieving driver configuration entries.

```powershell
Update-WEPSModuleDriverConfigInfo

Get-WEPSDriverConfig
```

## Notes
- The function reads from `$script:DriverConfigInfoPath`.
- The function stores the converted JSON data in `$Script:DriverConfigData`.
- The function uses `Get-Content -Raw` and `ConvertFrom-Json`.
- The function does not validate that `$script:DriverConfigInfoPath` exists before reading it.
- The function does not specify `-ErrorAction Stop`.
- The function does not return the loaded data.
- The comment-based help synopsis and description indicate that the function updates `DriverConfig.json` by scanning installed printer drivers, but the implementation only reloads JSON content from `$script:DriverConfigInfoPath`.
