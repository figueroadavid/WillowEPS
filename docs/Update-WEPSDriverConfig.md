# Update-WEPSDriverConfig

## Synopsis
Updates an existing driver configuration entry in the local driver configuration cache and optionally pushes the updated configuration to the source.

## Description
`Update-WEPSDriverConfig` updates driver configuration data stored in the local `DriverConfigInfo.json` cache.

The function can update the driver version, the DAT file path, or both. When a DAT file path is supplied, the path is resolved to a provider path and the SHA256 hash of the DAT file is stored with the driver entry.

Before making changes, the function validates that the local cache file exists and that `$script:DriverConfigInfo` is in the expected wrapper format with a `Drivers` property.

A backup of the local cache is created once before changes are written. The updated cache is written atomically by saving to a temporary file and then moving it into place.

If `-PushToSource` is specified, the function verifies source integrity before writing the updated configuration back to the source JSON file. After a successful push, source hash and last sync metadata are updated in the local cache.

The function supports `ShouldProcess`, so `-WhatIf` and `-Confirm` can be used.

## Parameters

### -DriverName
Specifies the name of the driver configuration entry to update.

The function matches this value against the `Name` property of entries in `$script:DriverConfigInfo.Drivers`.

- Type: String
- Required: Yes
- Accepts pipeline input: ByPropertyName

### -DriverVersion
Specifies the driver version value to write to the matching driver configuration entry.

When supplied, the function requires `-DatFilePath` to also be supplied.

The function also uses this value while resolving target entries. If matching entries exist with the same driver name and either the same driver version or a null driver version, those entries are targeted. If no such entries are found, the function falls back to matching by driver name.

- Type: Int64
- Required: No
- Accepts pipeline input: ByPropertyName

### -DatFilePath
Specifies the DAT file path to write to the matching driver configuration entry.

The path must exist. The function resolves the path with `$PSCmdlet.GetResolvedProviderPathFromPSPath()` before storing it.

When this parameter is supplied, the function also calculates and stores the SHA256 hash of the resolved DAT file.

- Type: String
- Required: No
- Accepts pipeline input: ByPropertyName
- Validation: Path must exist

### -PushToSource
If specified, attempts to push the updated local cache back to the source configuration file after the local update succeeds.

Before pushing, the function calls `Test-WEPSSourceIntegrity`. If the source integrity check fails, the function throws a terminating error and does not push.

- Type: Switch
- Required: No

## Inputs
System.String

System.Int64

You can pipe objects containing `DriverName`, `DriverVersion`, or `DatFilePath` properties to this function.

## Outputs
None

This function does not return a success object. It updates the local cache file and writes warning, verbose, or error output depending on execution results and supplied common parameters.

## Examples

### Example

Updates only the DAT file path for the specified driver in the local cache.

```powershell
Update-WEPSDriverConfig -DriverName 'Generic Universal Print Driver' -DatFilePath '.\Driver3.dat'
```

### Example

Updates both the driver version and DAT file path for the specified driver in the local cache.

```powershell
Update-WEPSDriverConfig -DriverName 'Generic Universal Print Driver' -DriverVersion 300000000000000 -DatFilePath '.\Driver3.dat'
```

### Example

Updates the DAT file path locally and then pushes the updated configuration to the source after source integrity is verified.

```powershell
Update-WEPSDriverConfig -DriverName 'Generic Universal Print Driver' -DatFilePath '.\Driver3.dat' -PushToSource
```


## Notes
- The function requires either `-DriverVersion` or `-DatFilePath`; otherwise, it throws a terminating error.
- When `-DriverVersion` is supplied, `-DatFilePath` is also required by the function logic.
- The function depends on `$script:DriverConfigInfoCachePath` for the local cache path.
- The function depends on `$script:DriverConfigInfoPath` for the source configuration path.
- The function depends on `$script:DriverConfigInfo` being loaded and containing a `Drivers` property.
- The function updates entries in `$script:DriverConfigInfo.Drivers`.
- Driver name matching uses exact string comparison against the `Name` property.
- If no matching driver name is found, the function writes a warning and returns.
- If multiple entries match the driver name and `-DriverVersion` is not supplied, the function writes a warning and returns without changing data.
- If multiple target entries remain after version-based resolution, the function selects the first target entry.
- When `-DatFilePath` is supplied, the function resolves the path and calculates the SHA256 hash of the resolved file.
- When `Convert-WEPSDriverVersion` is available, the function attempts to update `DriverVersionString`.
- If `Convert-WEPSDriverVersion` fails, the function writes verbose output and continues.
- A backup of the local cache is created before changes are written.
- Local cache writes are performed with a temporary file and move operation.
- Metadata is preserved where possible and updated with new modification information.
- If `-PushToSource` is used, source integrity is checked before pushing.
- If the source push succeeds, `SourceHash` and `LastSyncedAt` are updated in local metadata.
- Backup cleanup keeps only the 10 most recent `.bak` files associated with the local cache file.
- The function supports `-WhatIf` and `-Confirm` through `SupportsShouldProcess`.

