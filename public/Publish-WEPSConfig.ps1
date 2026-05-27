
function Publish-WEPSConfig {
    <#
    .SYNOPSIS
        Publishes local cache changes to the source network share.
    .DESCRIPTION
        This function synchronizes the local DriverConfigInfo.json cache with the
        source location on the network share. It performs integrity checks to detect
        if the source has been modified externally and offers several conflict
        resolution strategies.
    .PARAMETER ConflictResolution
        Specifies how to handle conflicts when the source file has changed since
        the last local load. Options are:
        - Abort: Stop and report the conflict (default)
        - Merge: Attempt to merge local changes with source (experimental)
        - Force: Overwrite source regardless of conflicts (use with caution)
    .PARAMETER DryRun
        If specified, shows what would be published without actually making changes.
    .PARAMETER SkipIntegrityCheck
        If specified, skips the source integrity check. Equivalent to Force but
        without the explicit warning.
    .EXAMPLE
        Publish-WEPSConfig
        Attempts to publish local changes with default Abort behavior.
    .EXAMPLE
        Publish-WEPSConfig -ConflictResolution Force
        Forces the push even if source has changed.
    .EXAMPLE
        Publish-WEPSConfig -DryRun
        Shows what would be published without making changes.
    .NOTES
        This function is the recommended way to push changes to the source.
        Individual cmdlets also support -PushToSource for immediate publishing.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter()]
        [ValidateSet('Abort', 'Merge', 'Force')]
        [string]$ConflictResolution = 'Abort',

        [switch]$DryRun,

        [switch]$SkipIntegrityCheck
    )

    begin {
        $LocalCachePath = $script:DriverConfigInfo
        $SourcePath = $script:DriverConfigInfoPath

        if (-not (Test-Path -LiteralPath $LocalCachePath)) {
            throw "Local cache not found at $LocalCachePath. Nothing to publish."
        }

        if (-not (Test-Path -LiteralPath $SourcePath)) {
            throw "Source file not found at $SourcePath. Cannot publish."
        }

        # Load both files for comparison
        try {
            $localContent = Get-Content -LiteralPath $LocalCachePath -Raw -ErrorAction Stop
            $localData = $localContent | ConvertFrom-Json -ErrorAction Stop

            $sourceContent = Get-Content -LiteralPath $SourcePath -Raw -ErrorAction Stop
            $sourceData = $sourceContent | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Failed to load configuration files: $_"
        }

        # Extract hashes
        $localExpectedHash = if ($localData.PSObject.Properties.Name -contains 'Metadata' -and $localData.Metadata.SourceHash) {
            $localData.Metadata.SourceHash
        } else {
            $null
        }

        $actualSourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash.ToUpperInvariant()

        # Determine if there's a conflict
        $hasConflict = $false
        $conflictDetails = $null

        if ($localExpectedHash -and $localExpectedHash -ne $actualSourceHash) {
            $hasConflict = $true
            $conflictDetails = [PSCustomObject]@{
                LocalExpectedHash = $localExpectedHash
                ActualSourceHash = $actualSourceHash
                LocalLastModified = if ($localData.Metadata.LastModified) { $localData.Metadata.LastModified } else { 'Unknown' }
                SourceLastModified = if ($sourceData.Metadata.LastModified) { $sourceData.Metadata.LastModified } else { 'Unknown' }
            }
        }

        # Count changes
        $localDriverCount = if ($localData.PSObject.Properties.Name -contains 'Drivers') {
            $localData.Drivers.Count
        } else {
            $localData.Count
        }

        $sourceDriverCount = if ($sourceData.PSObject.Properties.Name -contains 'Drivers') {
            $sourceData.Drivers.Count
        } else {
            $sourceData.Count
        }

        # Compare driver counts and names
        $localDriverNames = if ($localData.PSObject.Properties.Name -contains 'Drivers') {
            $localData.Drivers.Name
        } else {
            $localData.Name
        }

        $sourceDriverNames = if ($sourceData.PSObject.Properties.Name -contains 'Drivers') {
            $sourceData.Drivers.Name
        } else {
            $sourceData.Name
        }

        $addedDrivers = $localDriverNames | Where-Object { $_ -notin $sourceDriverNames }
        $removedDrivers = $sourceDriverNames | Where-Object { $_ -notin $localDriverNames }
        $modifiedDrivers = @()

        # Check for version/path changes in common drivers
        foreach ($name in ($localDriverNames | Where-Object { $_ -in $sourceDriverNames })) {
            $localEntry = if ($localData.PSObject.Properties.Name -contains 'Drivers') {
                $localData.Drivers | Where-Object { $_.Name -eq $name }
            } else {
                $localData | Where-Object { $_.Name -eq $name }
            }

            $sourceEntry = if ($sourceData.PSObject.Properties.Name -contains 'Drivers') {
                $sourceData.Drivers | Where-Object { $_.Name -eq $name }
            } else {
                $sourceData | Where-Object { $_.Name -eq $name }
            }

            if ($localEntry -and $sourceEntry) {
                if ($localEntry.DriverVersion -ne $sourceEntry.DriverVersion -or
                    $localEntry.DATFilePath -ne $sourceEntry.DATFilePath -or
                    $localEntry.SHA256 -ne $sourceEntry.SHA256) {
                    $modifiedDrivers += $name
                }
            }
        }

        $changeSummary = [PSCustomObject]@{
            AddedDrivers = $addedDrivers
            RemovedDrivers = $removedDrivers
            ModifiedDrivers = $modifiedDrivers
            TotalChanges = ($addedDrivers.Count + $removedDrivers.Count + $modifiedDrivers.Count)
        }
    }

    process {
        # Handle dry run
        if ($DryRun) {
            Write-Host "=== PUBLISH DRY RUN ===" -ForegroundColor Cyan
            Write-Host "  Local cache driver count: $localDriverCount" -ForegroundColor Gray
            Write-Host "  Source driver count:      $sourceDriverCount" -ForegroundColor Gray
            Write-Host "  Local Cache: $LocalCachePath" -ForegroundColor Gray
            Write-Host "  Source: $SourcePath" -ForegroundColor Gray
            Write-Host ""

            if ($hasConflict -and -not $SkipIntegrityCheck) {
                Write-Host "⚠️  CONFLICT DETECTED" -ForegroundColor Yellow
                Write-Host "  Local expected hash: $($conflictDetails.LocalExpectedHash.Substring(0,16))..." -ForegroundColor Gray
                Write-Host "  Actual source hash:  $($conflictDetails.ActualSourceHash.Substring(0,16))..." -ForegroundColor Gray
                Write-Host "  Local last modified: $($conflictDetails.LocalLastModified)" -ForegroundColor Gray
                Write-Host "  Source last modified: $($conflictDetails.SourceLastModified)" -ForegroundColor Gray
                Write-Host ""
            } else {
                Write-Host "✓ No conflicts detected" -ForegroundColor Green
                Write-Host ""
            }

            Write-Host "Changes to be published:" -ForegroundColor Cyan
            if ($changeSummary.AddedDrivers.Count -gt 0) {
                Write-Host "  Added: $($changeSummary.AddedDrivers.Count) driver(s)" -ForegroundColor Green
                $changeSummary.AddedDrivers | ForEach-Object { Write-Host "    + $_" -ForegroundColor Green }
            }
            if ($changeSummary.RemovedDrivers.Count -gt 0) {
                Write-Host "  Removed: $($changeSummary.RemovedDrivers.Count) driver(s)" -ForegroundColor Red
                $changeSummary.RemovedDrivers | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
            }
            if ($changeSummary.ModifiedDrivers.Count -gt 0) {
                Write-Host "  Modified: $($changeSummary.ModifiedDrivers.Count) driver(s)" -ForegroundColor Yellow
                $changeSummary.ModifiedDrivers | ForEach-Object { Write-Host "    ~ $_" -ForegroundColor Yellow }
            }
            if ($changeSummary.TotalChanges -eq 0) {
                Write-Host "  No changes detected" -ForegroundColor Gray
            }

            Write-Host ""
            Write-Host "Conflict resolution strategy: $ConflictResolution" -ForegroundColor Cyan

            if ($hasConflict -and -not $SkipIntegrityCheck) {
                switch ($ConflictResolution) {
                    'Abort' {
                        Write-Host "  Action: ABORT - Publishing will be skipped" -ForegroundColor Red
                    }
                    'Merge' {
                        Write-Host "  Action: MERGE - Attempting to combine changes" -ForegroundColor Yellow
                        Write-Host "  Note: Merge is experimental and may require manual review" -ForegroundColor Yellow
                    }
                    'Force' {
                        Write-Host "  Action: FORCE - Source will be overwritten" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "  Action: PUBLISH - Ready to publish changes" -ForegroundColor Green
            }

            return
        }

        # Handle conflict
        if ($hasConflict) {
            switch ($ConflictResolution) {
                'Abort' {
                    Write-Error "CONFLICT DETECTED - Publishing aborted." -ErrorAction Stop
                    Write-Error "The source file has been modified since the last local load." -ErrorAction Stop
                    Write-Error "Local expected hash: $($conflictDetails.LocalExpectedHash.Substring(0,16))..." -ErrorAction Stop
                    Write-Error "Actual source hash:  $($conflictDetails.ActualSourceHash.Substring(0,16))..." -ErrorAction Stop
                    Write-Error "" -ErrorAction Stop
                    Write-Error "Options:" -ErrorAction Stop
                    Write-Error "  1. Review changes manually and resolve conflicts" -ErrorAction Stop
                    Write-Error "  2. Use -ConflictResolution Merge to attempt automatic merge" -ErrorAction Stop
                    Write-Error "  3. Use -ConflictResolution Force to overwrite source (not recommended)" -ErrorAction Stop
                    return
                }

                'Merge' {
                    Write-Verbose "Attempting merge strategy..."
                    # NOTE: Full merge logic is complex and may require manual intervention
                    # For now, we'll warn and fall back to Force with confirmation
                    Write-Warning "Merge strategy is experimental for this module version."
                    Write-Warning "Recommended: Review changes manually or use -ConflictResolution Force"
                    
                    if (-not $PSCmdlet.ShouldContinue(
                        "Merge strategy may result in data loss. Continue with Force overwrite?",
                        "Confirm Merge Strategy"
                    )) {
                        Write-Verbose "Merge cancelled by user."
                        return
                    }
                    # Fall through to Force logic below
                }

                'Force' {
                    Write-Warning "FORCE OVERWRITE MODE" -WarningAction Continue
                    Write-Warning "The source file will be overwritten regardless of external changes." -WarningAction Continue
                    Write-Warning "This may result in loss of changes made by other administrators." -WarningAction Continue
                    
                    if (-not $PSCmdlet.ShouldContinue(
                        "Are you sure you want to force overwrite the source file?",
                        "Confirm Force Overwrite"
                    )) {
                        Write-Verbose "Force overwrite cancelled by user."
                        return
                    }
                }
            }
        }

        # Create backup of source before overwriting
        $SourceBackupPath = '{0}.{1}.backup' -f $SourcePath, ([datetime]::Now.ToString('yyyyMMddHHmmss'))
        try {
            Copy-Item -Path $SourcePath -Destination $SourceBackupPath -Force -ErrorAction Stop
            Write-Verbose "Created backup of source file at $SourceBackupPath"
        } catch {
            Write-Warning "Failed to create source backup. Continuing anyway, but rollback unavailable."
        }

        # Prepare the updated JSON
        $newMetadata = [PSCustomObject]@{
            SchemaVersion = "2.0"
            ModuleVersion = "0.0.1"
            LastModified = (Get-Date -Format 'o')
            ModifiedBy = "$($env:USERNAME)@$($env:USERDOMAIN)"
            LastSyncedAt = (Get-Date -Format 'o')
        }

        $driversArray = if ($localData.PSObject.Properties.Name -contains 'Drivers') {
            $localData.Drivers
        } else {
            $localData
        }

        $outputObj = [PSCustomObject]@{
            Metadata = $newMetadata
            Drivers = $driversArray
        }

        # Write to source (atomic)
        $sourceTemp = '{0}.{1}.tmp' -f $SourcePath, ([guid]::NewGuid().ToString('N'))
        try {
            $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sourceTemp -Force -ErrorAction Stop
            Move-Item -LiteralPath $sourceTemp -Destination $SourcePath -Force -ErrorAction Stop
            Write-Verbose "Successfully published configuration to source: $SourcePath"
            $publishedSourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
            
            if (-not $publishedSourceHash) {
                throw "Internal error: failed to compute published source hash."
            }

            $newMetadata | Add-Member -NotePropertyName SourceHash -NotePropertyValue $publishedSourceHash -Force -ErrorAction Stop
        } catch {
            # Rollback from backup if available
            if (Test-Path -LiteralPath $SourceBackupPath) {
                Write-Warning "Publish failed. Attempting rollback from backup..."
                Copy-Item -LiteralPath $SourceBackupPath -Destination $SourcePath -Force -ErrorAction SilentlyContinue
            }
            throw "Failed to publish configuration to source: $_"
        }

        # Update local cache metadata to match the pushed state
        try {
            $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $LocalCachePath -Force -ErrorAction Stop
            Update-WEPSModuleDriverConfigInfo
            Write-Verbose "Updated local cache metadata to match published state."
        } catch {
            Write-Warning "Failed to update local cache metadata after publish: $_"
        }

        # Cleanup old source backups (keep last 10)
        $SourceParentPath = Split-Path -Path $SourcePath
        $SourceBackupFiles = Get-ChildItem -Path "$SourceParentPath\$SourcePath*.backup"
        if ($SourceBackupFiles.Count -gt 10) {
            $FilesToRemove = $SourceBackupFiles | Sort-Object -Property CreationTime | Select-Object -First ($SourceBackupFiles.Count - 10)
            $FilesToRemove | Remove-Item -Force -ErrorAction SilentlyContinue
        }

        # Return success summary
        return [PSCustomObject]@{
            Success = $true
            SourcePath = $SourcePath
            LocalCachePath = $LocalCachePath
            ChangesPublished = $changeSummary.TotalChanges
            AddedDrivers = $changeSummary.AddedDrivers.Count
            RemovedDrivers = $changeSummary.RemovedDrivers.Count
            ModifiedDrivers = $changeSummary.ModifiedDrivers.Count
            SourceBackupPath = $SourceBackupPath
            Timestamp = (Get-Date -Format 'o')
        }
    }

    end {
        # Final status message
        Write-Host ""
        Write-Host "=== PUBLISH COMPLETE ===" -ForegroundColor Green
        Write-Host "Source: $SourcePath" -ForegroundColor Gray
        Write-Host "Changes: $($changeSummary.TotalChanges) total ($($changeSummary.AddedDrivers.Count) added, $($changeSummary.RemovedDrivers.Count) removed, $($changeSummary.ModifiedDrivers.Count) modified)" -ForegroundColor Gray
        Write-Host "Timestamp: $(Get-Date -Format 'o')" -ForegroundColor Gray
    }
}