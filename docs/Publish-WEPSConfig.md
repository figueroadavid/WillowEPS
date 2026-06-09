# Publish-WEPSConfig

## Synopsis
Publishes local driver configuration cache changes to the source network share.

## Description
`Publish-WEPSConfig` synchronizes the local `DriverConfigInfo.json` cache with the configured source file on the network share.

The function loads both the local cache and source configuration, compares their driver entries, and builds a change summary that includes added, removed, and modified drivers.

Before publishing, the function can perform an integrity check by comparing the source hash stored in local metadata with the current SHA256 hash of the source file. If the hashes do not match, the source is treated as changed externally and a conflict is detected.

Conflict handling is controlled by `-ConflictResolution`.

The function supports dry-run reporting through `-DryRun`, which displays the local and source paths, driver counts, conflict status, change summary, and selected conflict resolution strategy without writing changes.

When publishing proceeds, the function creates a backup of the source file, writes the updated configuration to a temporary file, moves it into place, calculates the new source hash, updates local metadata, refreshes module driver configuration data, and removes older source backups while keeping the 10 most recent backups.

The function supports `ShouldProcess` and has `ConfirmImpact` set to `High`.

## Parameters

### -ConflictResolution
Specifies how conflicts are handled when the source file has changed since the last local load.

Valid values:

- `Abort`
- `Merge`
- `Force`

`Abort` is the default behavior. If a conflict is detected, publishing is stopped.

`Merge` displays warnings that merge behavior is experimental and prompts before continuing. In the shown implementation, this does not perform a true merge; it proceeds only after confirmation and effectively continues toward overwrite behavior.

`Force` allows overwriting the source even when a conflict is detected. The function warns that this may overwrite changes made by other administrators and prompts for confirmation.

- Type: String
- Required: No
- Default: Abort
- Accepted values: Abort, Merge, Force

### -DryRun
Displays what would be published without writing changes to the source or local cache.

Dry-run output includes:

- Local cache driver count
- Source driver count
- Local cache path
- Source path
- Conflict status
- Added drivers
- Removed drivers
- Modified drivers
- Selected conflict resolution strategy

- Type: Switch
- Required: No

### -SkipIntegrityCheck
Skips the source integrity check.

When this switch is used, the function does not compare the local metadata source hash with the current source file hash.

- Type: Switch
- Required: No

## Inputs
None

This function does not accept pipeline input.

## Outputs
System.Management.Automation.PSCustomObject

When publishing succeeds, the function returns an object with the following properties:

- `Success`
- `SourcePath`
- `LocalCachePath`
- `ChangesPublished`
- `AddedDrivers`
- `RemovedDrivers`
- `ModifiedDrivers`
- `SourceBackupPath`
- `Timestamp`

When `-DryRun` is used, the function writes summary information to the host and does not return the publish result object.

## Examples

### Example

```powershell
Publish-WEPSConfig
```
Attempts to publish local cache changes to the source file.

If the source integrity check detects that the source has changed since the last local load, publishing is aborted because the default conflict resolution mode is `Abort`.

### Example
```powershell
Publish-WEPSConfig -DryRun
```

Displays a publish summary without modifying the source file or local cache.

The dry run reports detected changes, including added, removed, and modified drivers.

### Example
```powershell
Publish-WEPSConfig -ConflictResolution Force
```

Publishes local cache changes even if the source integrity check detects a conflict.

This mode prompts for confirmation before overwriting the source file.

### Example
```powershell
Publish-WEPSConfig -SkipIntegrityCheck
```

Publishes local cache changes without comparing the stored source hash to the current source file hash.

This bypasses conflict detection based on source hash comparison.

### Example
```powershell
Publish-WEPSConfig -ConflictResolution Force -DryRun
```

Displays what would happen if a force publish were performed, including whether conflicts are currently detected and what action the selected conflict strategy would take.

### Example
```powershell
Publish-WEPSConfig -WhatIf
```

Shows the publish operation controlled by `ShouldProcess` without performing the final publish action.


## Notes
- This function uses `$script:DriverConfigInfoCachePath` as the local cache path.
- This function uses `$script:DriverConfigInfoPath` as the source path.
- The local cache file must exist.
- The source file must exist.
- Both local and source files must contain valid JSON.
- The function supports both wrapped configuration data with a `Drivers` property and unwrapped driver arrays.
- Conflict detection depends on `Metadata.SourceHash` existing in the local cache.
- If `Metadata.SourceHash` is missing, hash-based conflict detection is not performed.
- `-SkipIntegrityCheck` disables hash-based conflict detection.
- Added and removed drivers are detected by comparing driver names.
- Modified drivers are detected by comparing `DriverVersion`, `DATFilePath`, and `SHA256` for matching driver names.
- Duplicate driver names in either local or source data are treated as modified.
- The source file is backed up before publishing.
- Source backups use the suffix `.backup`.
- Source backup cleanup keeps the 10 most recent backup files.
- The publish write uses a temporary file and then moves it into place.
- After publishing, the function calculates the SHA256 hash of the published source file and writes it back into local metadata as `SourceHash`.
- The function refreshes module driver configuration data by calling `Update-WEPSModuleDriverConfigInfo`.
- `Merge` conflict resolution is marked experimental in the function and does not implement a true object-level merge in the shown code.
- The function writes status output with `Write-Host` for dry-run and completion messages.
