# Remove-WEPSDriverConfig

## Synopsis
Removes a driver entry from the local driver configuration cache and optionally pushes the updated configuration back to the source.

## Description
`Remove-WEPSDriverConfig` removes one or more driver entries from the local `DriverConfigInfo.json` cache.

The function supports two removal modes:

- By driver name only, which removes all entries matching that name
- By driver name and specific driver version, which removes only the exact matching entry

Before modifying the local cache, the function validates that the cache file exists and that the in-memory driver configuration is in the expected wrapper format with a `Drivers` property.

A backup of the local cache is created once per invocation before any changes are written. The updated configuration is written atomically by saving to a temporary file and then moving it into place.

If `-PushToSource` is specified, the function verifies source integrity before writing the updated configuration back to the source JSON file. After a successful push, source hash and last sync metadata are updated in the local cache as well.

The function supports `ShouldProcess`, so `-WhatIf` and `-Confirm` can be used.

Old backup files are cleaned up automatically at the end of execution, keeping only the 10 most recent backups.

## Parameters

### -DriverName
Specifies the name of the driver to remove.

If `-DriverVersion` is not provided, all entries matching this exact driver name are removed.

- Type: String  
- Required: Yes  
- Accepts pipeline input: ByPropertyName  

### -DriverVersion
Specifies the exact driver version to remove.

If provided, only the entry matching both `DriverName` and `DriverVersion` is removed.

- Type: Int64  
- Required: No  
- Accepts pipeline input: ByPropertyName  

### -PushToSource
If specified, attempts to copy the updated local cache back to the source network share after a successful local update.

Before pushing, the function performs a source integrity check.

- Type: Switch  
- Required: No  

## Inputs
System.String

System.Int64

## Outputs
None

This function does not emit a success object. It updates the driver configuration cache and writes verbose output when requested.

## Examples

### Example
```powershell
Remove-WEPSDriverConfig -DriverName 'Xerox Global Print Driver PS'
```

### Example
```powershell
Remove-WEPSDriverConfig -DriverName 'Xerox Global Print Driver PS' -DriverVersion 559190000
```

### Example
```powershell
Remove-WEPSDriverConfig -DriverName 'Xerox Global Print Driver PS' -PushToSource
```

### Example
```powershell
Remove-WEPSDriverConfig -DriverName 'Xerox Global Print Driver PS' -WhatIf
```

## Notes
* Matching is exact only. Partial name matching is not used.
* If no matching driver is found, the function throws a terminating error.
* A backup of the local cache is created once per invocation before changes are written.
* Local writes are performed atomically using a temporary file and move operation.
* If `-PushToSource` is used, the function verifies source integrity before updating the source file.
* Metadata is preserved where possible and updated with new modification information.
* Backup cleanup keeps only the 10 most recent .bak files associated with the local cache file.
* The function depends on module-scoped state and helper functions, including:

    * Update-WEPSModuleDriverConfigInfo
    * Test-WEPSSourceIntegrity
    * $script:DriverConfigInfo
    * $script:DriverConfigInfoCachePath
    * $script:DriverConfigInfoPath
