function Update-WEPSCache {
    <#
    .SYNOPSIS
        Synchronizes the local cache with the source location, implementing
        a pull-based caching strategy with integrity validation.
    .DESCRIPTION
        This function compares the source configuration against the local cache
        and updates the cache only if the source is newer or the cache is invalid.
        It tracks metadata including version, timestamps, and hashes to enable
        future push-back synchronization.
    .PARAMETER DriverConfigInfo
        The driver configuration array from the source JSON file.
    .PARAMETER CacheDataDir
        Path to the local cache data directory.
    .PARAMETER CacheHelpDir
        Path to the local cache help directory.
    .PARAMETER SourceDataDir
        Path to the source data directory (network share).
    .PARAMETER SourceHelpDir
        Path to the source help directory (network share).
    .PARAMETER ModuleDataDir
        Path to the module's embedded data directory (fallback).
    .PARAMETER ModuleHelpDir
        Path to the module's embedded help directory (fallback).
    .PARAMETER Force
        Force cache update even if local cache appears current.
    .PARAMETER SkipPushCheck
        Skip checking if local changes exist that haven't been pushed.
    .NOTES
        This function implements the following workflow:
        1. Load source JSON and extract metadata
        2. Compare source hash/timestamp against local cache
        3. If source is newer, invalidate local cache
        4. Download DAT files with SHA256 validation
        5. Download help files if newer
        6. Update local cache metadata
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$DriverConfigInfo,

        [Parameter(Mandatory)]
        [string]$CacheDataDir,

        [Parameter(Mandatory)]
        [string]$CacheHelpDir,

        [Parameter(Mandatory)]
        [string]$SourceDataDir,

        [Parameter(Mandatory)]
        [string]$SourceHelpDir,

        [Parameter(Mandatory)]
        [string]$ModuleDataDir,

        [Parameter(Mandatory)]
        [string]$ModuleHelpDir,

        [switch]$Force,

        [switch]$SkipPushCheck
    )

    # Ensure cache directories exist
    New-WEPSDirectory -Path $CacheDataDir
    New-WEPSDirectory -Path $CacheHelpDir

    # Define cache file paths
    $LocalCacheJsonPath         = [System.IO.Path]::Combine($CacheDataDir, 'DriverConfigInfo.json')
    $LocalCacheJsonBackupPath   = '{0}.backup' -f $LocalCacheJsonPath

    # ========================================================================
    # STEP 1: Determine if we need to pull from source
    # ========================================================================
    $NeedsPull                  = $true
    $SourceChanged              = $false
    $LocalHasUnpushedChanges    = $false

    if (-not $Force -and (Test-Path -LiteralPath $LocalCacheJsonPath)) {
        try {
            # Load local cache metadata
            $localContent   = Get-Content -LiteralPath $LocalCacheJsonPath -Raw -ErrorAction Stop
            $localData      = $localContent | ConvertFrom-Json -ErrorAction Stop

            # Load source metadata
            $sourceContent  = Get-Content -LiteralPath $script:DriverConfigInfoPath -Raw -ErrorAction Stop
            $sourceData     = $sourceContent | ConvertFrom-Json -ErrorAction Stop

            # Compare hashes
            $localHash = if ($localData.PSObject.Properties.Name -contains 'Metadata' -and $localData.Metadata.SourceHash) {
                $localData.Metadata.SourceHash
            } else {
                $null
            }

            $sourceHash = if ($sourceData.PSObject.Properties.Name -contains 'Metadata' -and $sourceData.Metadata.SourceHash) {
                $sourceData.Metadata.SourceHash
            } else {
                # Fallback: compute hash of source content
                (Get-FileHash -LiteralPath $script:DriverConfigInfoPath -Algorithm SHA256).Hash
            }

            # Check timestamps
            $localTimestamp = if ($localData.PSObject.Properties.Name -contains 'Metadata' -and $localData.Metadata.LastModified) {
                [DateTime]::Parse($localData.Metadata.LastModified, $null, 'RoundtripKind')
            } else {
                (Get-Item -LiteralPath $LocalCacheJsonPath).LastWriteTimeUtc
            }

            $sourceTimestamp = if ($sourceData.PSObject.Properties.Name -contains 'Metadata' -and $sourceData.Metadata.LastModified) {
                [DateTime]::Parse($sourceData.Metadata.LastModified, $null, 'RoundtripKind')
            } else {
                (Get-Item -LiteralPath $script:DriverConfigInfoPath).LastWriteTimeUtc
            }

            # Determine if source changed
            if ($sourceHash -ne $localHash -or $sourceTimestamp -gt $localTimestamp) {
                $SourceChanged = $true
                Write-Verbose "Source configuration is newer than local cache. Pulling updates."
                Write-Verbose "  Source: $($sourceTimestamp.ToString('o')) | Hash: $($sourceHash.Substring(0,16))..."
                Write-Verbose "  Local:  $($localTimestamp.ToString('o')) | Hash: $($localHash.Substring(0,16))..."
            } else {
                $NeedsPull = $false
                Write-Verbose "Local cache is current. Skipping pull."
            }

            # Check for unpushed local changes (if not skipping)
            if (-not $SkipPushCheck -and -not $SourceChanged) {
                # This would require tracking a separate "last pushed" state
                # For now, we'll flag this for the Publish-WEPSConfig function to handle
                $LocalHasUnpushedChanges = $false  # Placeholder
            }

        } catch {
            Write-Warning "Failed to compare cache versions: $_. Forcing pull."
            $NeedsPull = $true
        }
    }

    # ========================================================================
    # STEP 2: Create backup of local cache before overwriting (if pulling)
    # ========================================================================
    if ($NeedsPull -and (Test-Path -LiteralPath $LocalCacheJsonPath)) {
        try {
            Copy-Item -LiteralPath $LocalCacheJsonPath -Destination $LocalCacheJsonBackupPath -Force -ErrorAction Stop
            Write-Verbose "Created backup of local cache at $LocalCacheJsonBackupPath"
        } catch {
            Write-Warning "Failed to create cache backup. Continuing anyway, but rollback unavailable."
        }
    }

    # ========================================================================
    # STEP 3: Cache DAT files based on DriverConfigInfo.json SHA256
    # ========================================================================
    $driversArray = if ($DriverConfigInfo.PSObject.Properties.Name -contains 'Drivers') {
        $DriverConfigInfo.Drivers
    } else {
        $DriverConfigInfo  # Legacy flat array format
    }

    foreach ($entry in $driversArray) {
        # Your JSON stores an absolute path; we use the leaf as the canonical filename.
        $fileName = Split-Path -Path $entry.DATFilePath -Leaf
        $cachePath = [System.IO.Path]::Combine($CacheDataDir, $fileName)

        $expected = $null
        if ($entry.PSObject.Properties.Name -contains 'SHA256' -and $entry.SHA256) {
            $expected = $entry.SHA256.ToString().ToUpperInvariant()
        } else {
            # If the JSON entry lacks SHA256, treat as unknown and force refresh
            $expected = $null
        }

        $actual = Get-WEPSSha256 -Path $cachePath

        $needsCopy = $true
        if ($expected -and $actual -and ($expected -eq $actual)) {
            $needsCopy = $false
            Write-Verbose "DAT file '$fileName' is current (SHA256 match)."
        }

        if ($needsCopy -and $NeedsPull) {
            $sourcePath = [System.IO.Path]::Combine($SourceDataDir, $fileName)

            # Operational fallback: if source share is unavailable, fall back to module-local Data\
            if (-not (Test-Path -LiteralPath $sourcePath)) {
                $sourcePath = [System.IO.Path]::Combine($ModuleDataDir, $fileName)
            }

            if (-not (Test-Path -LiteralPath $sourcePath)) {
                Write-Warning ("WillowEPS: Missing source DAT file '{0}'. Expected in '{1}' or '{2}'." -f $fileName, $SourceDataDir, $ModuleDataDir)
            } else {
                try {
                    Copy-WEPSFileAtomic -Source $sourcePath -Destination $cachePath

                    # Verify post-copy hash; if still wrong, hard fail (prevents using bad config)
                    if ($expected) {
                        $after = Get-WEPSSha256 -Path $cachePath
                        if ($after -ne $expected) {
                            throw ("WillowEPS: SHA256 mismatch after caching '{0}'. Expected {1}, got {2}." -f $fileName, $expected, $after)
                        }
                    }
                    Write-Verbose "Cached DAT file: $fileName"
                } catch {
                    Write-Error "Failed to cache DAT file '$fileName': $_"
                    # Continue processing other files, but log the failure
                }
            }
        } elseif ($needsCopy -and -not $NeedsPull) {
            Write-Verbose "Skipping DAT file '$fileName' - cache is current."
        }

        # IMPORTANT: rewrite the in-memory path so the rest of the module uses the cached file
        $entry.DATFilePath = $cachePath
    }

    # ========================================================================
    # STEP 4: Cache MD help files (mirror from source if available; else module-local help\)
    # ========================================================================
    $helpSource = $SourceHelpDir
    if (-not (Test-Path -LiteralPath $helpSource)) {
        $helpSource = $ModuleHelpDir
    }

    if (Test-Path -LiteralPath $helpSource) {
        Get-ChildItem -LiteralPath $helpSource -Filter *.md -File -ErrorAction SilentlyContinue |
        ForEach-Object {
            $dest = [System.IO.Path]::Combine($CacheHelpDir, $_.Name)

            # Cheap sync rule: copy if missing OR source is newer
            $copyIt = $true
            if (Test-Path -LiteralPath $dest) {
                $srcTime = $_.LastWriteTimeUtc
                $dstTime = (Get-Item -LiteralPath $dest).LastWriteTimeUtc
                if ($dstTime -ge $srcTime) {
                    $copyIt = $false
                }
            }

            if ($copyIt -and $NeedsPull) {
                try {
                    Copy-WEPSFileAtomic -Source $_.FullName -Destination $dest
                    Write-Verbose "Cached help file: $($_.Name)"
                } catch {
                    Write-Warning "Failed to cache help file '$($_.Name)': $_"
                }
            }
        }
    } else {
        Write-Warning ("WillowEPS: Help source directory not found: '{0}' or '{1}'." -f $SourceHelpDir, $ModuleHelpDir)
    }

    # ========================================================================
    # STEP 5: Update local cache JSON with new metadata (if pulled)
    # ========================================================================
    if ($NeedsPull) {
        try {
            # Compute new source hash
            $newSourceHash = (Get-FileHash -LiteralPath $script:DriverConfigInfoPath -Algorithm SHA256).Hash.ToUpperInvariant()

            # Build updated JSON with metadata
            $updatedConfig = [PSCustomObject]@{
                Metadata = [PSCustomObject]@{
                    SchemaVersion = "2.0"
                    ModuleVersion = "0.0.1"
                    LastModified = (Get-Date -Format 'o')
                    ModifiedBy = "$($env:USERNAME)@$($env:USERDOMAIN)"
                    SourceHash = $newSourceHash
                    LastSyncedAt = (Get-Date -Format 'o')
                }
                Drivers = $driversArray
            }

            # Write atomically to local cache
            $tempPath = '{0}.{1}.tmp' -f $LocalCacheJsonPath, ([guid]::NewGuid().ToString('N'))
            $updatedConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempPath -Force -ErrorAction Stop
            Move-Item -LiteralPath $tempPath -Destination $LocalCacheJsonPath -Force -ErrorAction Stop

            Write-Verbose "Updated local cache metadata. SourceHash: $($newSourceHash.Substring(0,16))..."
        } catch {
            Write-Error "Failed to update local cache JSON: $_"
            # Attempt rollback if backup exists
            if (Test-Path -LiteralPath $LocalCacheJsonBackupPath) {
                Write-Warning "Attempting rollback from backup..."
                Copy-Item -LiteralPath $LocalCacheJsonBackupPath -Destination $LocalCacheJsonPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # ========================================================================
    # STEP 6: Return status information for caller
    # ========================================================================
    return [PSCustomObject]@{
        PullPerformed = $NeedsPull
        SourceChanged = $SourceChanged
        LocalHasUnpushedChanges = $LocalHasUnpushedChanges
        CachedDriverCount = $driversArray.Count
        CachePath = $LocalCacheJsonPath
    }
}