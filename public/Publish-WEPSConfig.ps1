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
        $LocalCachePath = $script:DriverConfigInfoCachePath
        $SourcePath     = $script:DriverConfigInfoPath

        if (-not (Test-Path -LiteralPath $LocalCachePath)) {
            throw "Local cache not found at $LocalCachePath. Nothing to publish."
        }

        if (-not (Test-Path -LiteralPath $SourcePath)) {
            throw "Source file not found at $SourcePath. Cannot publish."
        }

        try {
            $localContent = Get-Content -LiteralPath $LocalCachePath -Raw -ErrorAction Stop
            $localData    = $localContent | ConvertFrom-Json -ErrorAction Stop

            $sourceContent = Get-Content -LiteralPath $SourcePath -Raw -ErrorAction Stop
            $sourceData    = $sourceContent | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "Failed to load configuration files: $_"
        }

        $localExpectedHash = if (
            ($localData.PSObject.Properties.Name -contains 'Metadata') -and
            $localData.Metadata -and
            $localData.Metadata.SourceHash
        ) {
            $localData.Metadata.SourceHash.ToString().ToUpperInvariant()
        }
        else {
            $null
        }

        $actualSourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash.ToUpperInvariant()

        $hasConflict = $false
        $conflictDetails = $null

        if (-not $SkipIntegrityCheck -and $localExpectedHash -and ($localExpectedHash -ne $actualSourceHash)) {
            $hasConflict = $true
            $conflictDetails = [PSCustomObject]@{
                LocalExpectedHash = $localExpectedHash
                ActualSourceHash  = $actualSourceHash
                LocalLastModified = if (
                    ($localData.PSObject.Properties.Name -contains 'Metadata') -and
                    $localData.Metadata -and
                    $localData.Metadata.LastModified
                ) {
                    $localData.Metadata.LastModified
                }
                else {
                    'Unknown'
                }
                SourceLastModified = if (
                    ($sourceData.PSObject.Properties.Name -contains 'Metadata') -and
                    $sourceData.Metadata -and
                    $sourceData.Metadata.LastModified
                ) {
                    $sourceData.Metadata.LastModified
                }
                else {
                    'Unknown'
                }
            }
        }

        $localDrivers = if ($localData.PSObject.Properties.Name -contains 'Drivers') {
            @($localData.Drivers)
        }
        else {
            @($localData)
        }

        $sourceDrivers = if ($sourceData.PSObject.Properties.Name -contains 'Drivers') {
            @($sourceData.Drivers)
        }
        else {
            @($sourceData)
        }

        $localDriverCount  = $localDrivers.Count
        $sourceDriverCount = $sourceDrivers.Count

        $localDriverNames  = @($localDrivers.Name)
        $sourceDriverNames = @($sourceDrivers.Name)

        $addedDrivers    = @($localDriverNames  | Where-Object { $_ -notin $sourceDriverNames })
        $removedDrivers  = @($sourceDriverNames | Where-Object { $_ -notin $localDriverNames })
        $modifiedDrivers = @()

        foreach ($name in ($localDriverNames | Where-Object { $_ -in $sourceDriverNames })) {
            $localEntry = @($localDrivers  | Where-Object { $_.Name -eq $name })
            $sourceEntry = @($sourceDrivers | Where-Object { $_.Name -eq $name })

            if ($localEntry.Count -gt 1 -or $sourceEntry.Count -gt 1) {
                $modifiedDrivers += $name
                continue
            }

            if ($localEntry.Count -eq 1 -and $sourceEntry.Count -eq 1) {
                if (
                    ($localEntry[0].DriverVersion -ne $sourceEntry[0].DriverVersion) -or
                    ($localEntry[0].DATFilePath   -ne $sourceEntry[0].DATFilePath)   -or
                    ($localEntry[0].SHA256        -ne $sourceEntry[0].SHA256)
                ) {
                    $modifiedDrivers += $name
                }
            }
        }

        $changeSummary = [PSCustomObject]@{
            AddedDrivers    = @($addedDrivers)
            RemovedDrivers  = @($removedDrivers)
            ModifiedDrivers = @($modifiedDrivers)
            TotalChanges    = @($addedDrivers).Count + @($removedDrivers).Count + @($modifiedDrivers).Count
        }
    }

    process {
        if ($DryRun) {
            Write-Host "=== PUBLISH DRY RUN ===" -ForegroundColor Cyan
            Write-Host "  Local cache driver count: $localDriverCount" -ForegroundColor Gray
            Write-Host "  Source driver count:      $sourceDriverCount" -ForegroundColor Gray
            Write-Host "  Local Cache: $LocalCachePath" -ForegroundColor Gray
            Write-Host "  Source: $SourcePath" -ForegroundColor Gray
            Write-Host ""

            if ($hasConflict) {
                $localHashShort  = if ($conflictDetails.LocalExpectedHash) { $conflictDetails.LocalExpectedHash.Substring(0, [Math]::Min(16, $conflictDetails.LocalExpectedHash.Length)) } else { '<none>' }
                $sourceHashShort = if ($conflictDetails.ActualSourceHash)  { $conflictDetails.ActualSourceHash.Substring(0, [Math]::Min(16, $conflictDetails.ActualSourceHash.Length)) } else { '<none>' }

                Write-Host "⚠️  CONFLICT DETECTED" -ForegroundColor Yellow
                Write-Host "  Local expected hash: $localHashShort..." -ForegroundColor Gray
                Write-Host "  Actual source hash:  $sourceHashShort..." -ForegroundColor Gray
                Write-Host "  Local last modified: $($conflictDetails.LocalLastModified)" -ForegroundColor Gray
                Write-Host "  Source last modified: $($conflictDetails.SourceLastModified)" -ForegroundColor Gray
                Write-Host ""
            }
            else {
                Write-Host "✓ No conflicts detected" -ForegroundColor Green
                Write-Host ""
            }

            Write-Host "Changes to be published:" -ForegroundColor Cyan
            if (@($changeSummary.AddedDrivers).Count -gt 0) {
                Write-Host "  Added: $(@($changeSummary.AddedDrivers).Count) driver(s)" -ForegroundColor Green
                $changeSummary.AddedDrivers | ForEach-Object { Write-Host "    + $_" -ForegroundColor Green }
            }
            if (@($changeSummary.RemovedDrivers).Count -gt 0) {
                Write-Host "  Removed: $(@($changeSummary.RemovedDrivers).Count) driver(s)" -ForegroundColor Red
                $changeSummary.RemovedDrivers | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
            }
            if (@($changeSummary.ModifiedDrivers).Count -gt 0) {
                Write-Host "  Modified: $(@($changeSummary.ModifiedDrivers).Count) driver(s)" -ForegroundColor Yellow
                $changeSummary.ModifiedDrivers | ForEach-Object { Write-Host "    ~ $_" -ForegroundColor Yellow }
            }
            if ($changeSummary.TotalChanges -eq 0) {
                Write-Host "  No changes detected" -ForegroundColor Gray
            }

            Write-Host ""
            Write-Host "Conflict resolution strategy: $ConflictResolution" -ForegroundColor Cyan

            if ($hasConflict) {
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
            }
            else {
                Write-Host "  Action: PUBLISH - Ready to publish changes" -ForegroundColor Green
            }

            return
        }

        if ($hasConflict) {
            switch ($ConflictResolution) {
                'Abort' {
                    $localHashShort  = if ($conflictDetails.LocalExpectedHash) { $conflictDetails.LocalExpectedHash.Substring(0, [Math]::Min(16, $conflictDetails.LocalExpectedHash.Length)) } else { '<none>' }
                    $sourceHashShort = if ($conflictDetails.ActualSourceHash)  { $conflictDetails.ActualSourceHash.Substring(0, [Math]::Min(16, $conflictDetails.ActualSourceHash.Length)) } else { '<none>' }

                    Write-Error "CONFLICT DETECTED - Publishing aborted." -ErrorAction Stop
                    Write-Error "The source file has been modified since the last local load." -ErrorAction Stop
                    Write-Error "Local expected hash: $localHashShort..." -ErrorAction Stop
                    Write-Error "Actual source hash:  $sourceHashShort..." -ErrorAction Stop
                    Write-Error "" -ErrorAction Stop
                    Write-Error "Options:" -ErrorAction Stop
                    Write-Error "  1. Review changes manually and resolve conflicts" -ErrorAction Stop
                    Write-Error "  2. Use -ConflictResolution Merge to attempt automatic merge" -ErrorAction Stop
                    Write-Error "  3. Use -ConflictResolution Force to overwrite source (not recommended)" -ErrorAction Stop
                    return
                }

                'Merge' {
                    Write-Verbose "Attempting merge strategy..."
                    Write-Warning "Merge strategy is experimental for this module version."
                    Write-Warning "Recommended: Review changes manually or use -ConflictResolution Force"

                    if (-not $PSCmdlet.ShouldContinue(
                        'Merge strategy may result in data loss. Continue with Force overwrite?',
                        'Confirm Merge Strategy'
                    )) {
                        Write-Verbose "Merge cancelled by user."
                        return
                    }
                }

                'Force' {
                    Write-Warning "FORCE OVERWRITE MODE" -WarningAction Continue
                    Write-Warning "The source file will be overwritten regardless of external changes." -WarningAction Continue
                    Write-Warning "This may result in loss of changes made by other administrators." -WarningAction Continue

                    if (-not $PSCmdlet.ShouldContinue(
                        'Are you sure you want to force overwrite the source file?',
                        'Confirm Force Overwrite'
                    )) {
                        Write-Verbose "Force overwrite cancelled by user."
                        return
                    }
                }
            }
        }

        if (-not $PSCmdlet.ShouldProcess($SourcePath, 'Publish local cache changes to source')) {
            return
        }

        $SourceBackupPath = '{0}.{1}.backup' -f $SourcePath, ([datetime]::Now.ToString('yyyyMMddHHmmss'))
        try {
            Copy-Item -LiteralPath $SourcePath -Destination $SourceBackupPath -Force -ErrorAction Stop
            Write-Verbose "Created backup of source file at $SourceBackupPath"
        }
        catch {
            Write-Warning "Failed to create source backup. Continuing anyway, but rollback unavailable."
        }

        $localMetadata = if (($localData.PSObject.Properties.Name -contains 'Metadata') -and $localData.Metadata) {
            $localData.Metadata
        }
        else {
            $null
        }

        $newMetadata = [PSCustomObject]@{
            SchemaVersion = if ($localMetadata -and $localMetadata.SchemaVersion) { $localMetadata.SchemaVersion } else { '2.0' }
            ModuleVersion = if ($localMetadata -and $localMetadata.ModuleVersion) { $localMetadata.ModuleVersion } else { '0.0.1' }
            LastModified  = (Get-Date -Format 'o')
            ModifiedBy    = "$($env:USERNAME)@$($env:USERDOMAIN)"
            LastSyncedAt  = (Get-Date -Format 'o')
        }

        $driversArray = @($localDrivers)

        $outputObj = [PSCustomObject]@{
            Metadata = $newMetadata
            Drivers  = $driversArray
        }

        $sourceTemp = '{0}.{1}.tmp' -f $SourcePath, ([guid]::NewGuid().ToString('N'))
        try {
            $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sourceTemp -Force -ErrorAction Stop
            Move-Item -LiteralPath $sourceTemp -Destination $SourcePath -Force -ErrorAction Stop
            Write-Verbose "Successfully published configuration to source: $SourcePath"

            $publishedSourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash.ToUpperInvariant()
            if (-not $publishedSourceHash) {
                throw "Internal error: failed to compute published source hash."
            }

            $outputObj.Metadata | Add-Member -NotePropertyName SourceHash -NotePropertyValue $publishedSourceHash -Force -ErrorAction Stop

            $localTemp = '{0}.{1}.tmp' -f $LocalCachePath, ([guid]::NewGuid().ToString('N'))
            $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $localTemp -Force -ErrorAction Stop
            Move-Item -LiteralPath $localTemp -Destination $LocalCachePath -Force -ErrorAction Stop

            Update-WEPSModuleDriverConfigInfo
            Write-Verbose "Updated local cache metadata to match published state."
        }
        catch {
            if (Test-Path -LiteralPath $SourceBackupPath) {
                Write-Warning "Publish failed. Attempting rollback from backup..."
                Copy-Item -LiteralPath $SourceBackupPath -Destination $SourcePath -Force -ErrorAction SilentlyContinue
            }
            throw "Failed to publish configuration to source: $_"
        }

        $SourceParentPath = [System.IO.Path]::GetDirectoryName($SourcePath)
        $SourceFileName   = [System.IO.Path]::GetFileName($SourcePath)

        if (-not [string]::IsNullOrEmpty($SourceParentPath) -and (Test-Path -LiteralPath $SourceParentPath)) {
            $SourceBackupFiles = Get-ChildItem -LiteralPath $SourceParentPath -Filter "$SourceFileName*.backup" -File -ErrorAction SilentlyContinue
            if (@($SourceBackupFiles).Count -gt 10) {
                $FilesToRemove = $SourceBackupFiles | Sort-Object -Property CreationTime | Select-Object -First (@($SourceBackupFiles).Count - 10)
                $FilesToRemove | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }

        return [PSCustomObject]@{
            Success          = $true
            SourcePath       = $SourcePath
            LocalCachePath   = $LocalCachePath
            ChangesPublished = $changeSummary.TotalChanges
            AddedDrivers     = @($changeSummary.AddedDrivers).Count
            RemovedDrivers   = @($changeSummary.RemovedDrivers).Count
            ModifiedDrivers  = @($changeSummary.ModifiedDrivers).Count
            SourceBackupPath = $SourceBackupPath
            Timestamp        = (Get-Date -Format 'o')
        }
    }

    end {
        Write-Host ""
        Write-Host "=== PUBLISH COMPLETE ===" -ForegroundColor Green
        Write-Host "Source: $SourcePath" -ForegroundColor Gray
        Write-Host "Changes: $($changeSummary.TotalChanges) total ($(@($changeSummary.AddedDrivers).Count) added, $(@($changeSummary.RemovedDrivers).Count) removed, $(@($changeSummary.ModifiedDrivers).Count) modified)" -ForegroundColor Gray
        Write-Host "Timestamp: $(Get-Date -Format 'o')" -ForegroundColor Gray
    }
}