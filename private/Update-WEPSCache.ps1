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
        The driver configuration object loaded from DriverConfigInfo.json.
        Supports both the current wrapper format with Metadata and Drivers
        and the legacy flat array format.
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
        3. If source is newer, invalidate local cache metadata
        4. Cache DAT files with SHA256 validation
        5. Cache help files if missing or older
        6. Update local cache metadata
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$DriverConfigInfo,

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
    $LocalCacheJsonPath       = [System.IO.Path]::Combine($CacheDataDir, 'DriverConfigInfo.json')
    $LocalCacheJsonBackupPath = '{0}.backup' -f $LocalCacheJsonPath

    # Normalize driver configuration input
    $sourceMetadata = $null
    $driversArray = if ($null -ne $DriverConfigInfo -and ($DriverConfigInfo.PSObject.Properties.Name -contains 'Drivers')) {
        $sourceMetadata = $DriverConfigInfo.Metadata
        @($DriverConfigInfo.Drivers)
    } else {
        @($DriverConfigInfo)
    }

    # ========================================================================
    # STEP 1: Determine if we need to refresh metadata from source
    # ========================================================================
    $NeedsPull               = $true
    $SourceChanged           = $false
    $LocalHasUnpushedChanges = $false

    if (-not $Force -and (Test-Path -LiteralPath $LocalCacheJsonPath)) {
        try {
            # Load local cache metadata
            $localContent = Get-Content -LiteralPath $LocalCacheJsonPath -Raw -ErrorAction Stop
            $localData    = $localContent | ConvertFrom-Json -ErrorAction Stop

            # Load source metadata from source JSON
            $sourceContent = Get-Content -LiteralPath $script:DriverConfigInfoPath -Raw -ErrorAction Stop
            $sourceData    = $sourceContent | ConvertFrom-Json -ErrorAction Stop

            $localHash = if (($localData.PSObject.Properties.Name -contains 'Metadata') -and $localData.Metadata.SourceHash) {
                $localData.Metadata.SourceHash.ToString().ToUpperInvariant()
            } else {
                $null
            }

            $sourceHash = if (($sourceData.PSObject.Properties.Name -contains 'Metadata') -and $sourceData.Metadata.SourceHash) {
                $sourceData.Metadata.SourceHash.ToString().ToUpperInvariant()
            } else {
                (Get-FileHash -LiteralPath $script:DriverConfigInfoPath -Algorithm SHA256).Hash.ToUpperInvariant()
            }

            $localTimestamp = if (($localData.PSObject.Properties.Name -contains 'Metadata') -and $localData.Metadata.LastModified) {
                [DateTime]::Parse($localData.Metadata.LastModified, $null, 'RoundtripKind')
            } else {
                (Get-Item -LiteralPath $LocalCacheJsonPath).LastWriteTimeUtc
            }

            $sourceTimestamp = if (($sourceData.PSObject.Properties.Name -contains 'Metadata') -and $sourceData.Metadata.LastModified) {
                [DateTime]::Parse($sourceData.Metadata.LastModified, $null, 'RoundtripKind')
            } else {
                (Get-Item -LiteralPath $script:DriverConfigInfoPath).LastWriteTimeUtc
            }

            if (($sourceHash -ne $localHash) -or ($sourceTimestamp -gt $localTimestamp)) {
                $SourceChanged = $true

                $sourceHashShort = if ($sourceHash) { $sourceHash.Substring(0, [Math]::Min(16, $sourceHash.Length)) } else { '<none>' }
                $localHashShort  = if ($localHash)  { $localHash.Substring(0,  [Math]::Min(16, $localHash.Length)) }  else { '<none>' }

                Write-Verbose "Source configuration is newer than local cache. Pulling updates."
                Write-Verbose "  Source: $($sourceTimestamp.ToString('o')) | Hash: $sourceHashShort..."
                Write-Verbose "  Local:  $($localTimestamp.ToString('o')) | Hash: $localHashShort..."
            } else {
                $NeedsPull = $false
                Write-Verbose "Local cache metadata is current. Per-file integrity checks will still run."
            }

            if (-not $SkipPushCheck -and -not $SourceChanged) {
                $LocalHasUnpushedChanges = $false
            }
        } catch {
            Write-Warning "Failed to compare cache versions: $_. Forcing metadata refresh."
            $NeedsPull = $true
        }
    }

    # ========================================================================
    # STEP 2: Create backup of local cache before overwriting metadata
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
    # STEP 3: Cache DAT files based on SHA256 / presence
    # ========================================================================
    foreach ($entry in $driversArray) {
        if ($null -eq $entry) {
            continue
        }

        if (-not ($entry.PSObject.Properties.Name -contains 'DATFilePath') -or [string]::IsNullOrWhiteSpace($entry.DATFilePath)) {
            Write-Warning "Skipping driver entry with no DATFilePath."
            continue
        }

        $fileName  = Split-Path -Path $entry.DATFilePath -Leaf
        $cachePath = [System.IO.Path]::Combine($CacheDataDir, $fileName)

        $expected = $null
        if (($entry.PSObject.Properties.Name -contains 'SHA256') -and $entry.SHA256) {
            $expected = $entry.SHA256.ToString().ToUpperInvariant()
        }

        $actual = Get-WEPSSha256 -Path $cachePath

        $needsCopy = $true
        if ($expected) {
            if ($actual -and ($expected -eq $actual)) {
                $needsCopy = $false
                Write-Verbose "DAT file '$fileName' is current (SHA256 match)."
            }
        } else {
            # If no expected hash exists, only skip when file exists
            if (Test-Path -LiteralPath $cachePath) {
                $needsCopy = $false
                Write-Verbose "DAT file '$fileName' exists and no SHA256 was provided; leaving as-is."
            }
        }

        if ($needsCopy) {
            $sourcePath = [System.IO.Path]::Combine($SourceDataDir, $fileName)

            if (-not (Test-Path -LiteralPath $sourcePath)) {
                $sourcePath = [System.IO.Path]::Combine($ModuleDataDir, $fileName)
            }

            if (-not (Test-Path -LiteralPath $sourcePath)) {
                Write-Warning ("WillowEPS: Missing source DAT file '{0}'. Expected in '{1}' or '{2}'." -f $fileName, $SourceDataDir, $ModuleDataDir)
            } else {
                try {
                    Copy-WEPSFileAtomic -Source $sourcePath -Destination $cachePath

                    if ($expected) {
                        $after = Get-WEPSSha256 -Path $cachePath
                        if ($after -ne $expected) {
                            throw ("WillowEPS: SHA256 mismatch after caching '{0}'. Expected {1}, got {2}." -f $fileName, $expected, $after)
                        }
                    }

                    Write-Verbose "Cached DAT file: $fileName"
                } catch {
                    Write-Error "Failed to cache DAT file '$fileName': $_"
                }
            }
        }

        # Always rewrite in-memory path to the cache path
        $entry.DATFilePath = $cachePath
    }

    # ========================================================================
    # STEP 4: Cache help files (copy if missing or older)
    # ========================================================================
    $helpSource = $SourceHelpDir
    if (-not (Test-Path -LiteralPath $helpSource)) {
        $helpSource = $ModuleHelpDir
    }

    if (Test-Path -LiteralPath $helpSource) {
        Get-ChildItem -LiteralPath $helpSource -Filter *.md -File -ErrorAction SilentlyContinue |
            ForEach-Object {
                $dest = [System.IO.Path]::Combine($CacheHelpDir, $_.Name)

                $copyIt = $true
                if (Test-Path -LiteralPath $dest) {
                    $srcTime = $_.LastWriteTimeUtc
                    $dstTime = (Get-Item -LiteralPath $dest).LastWriteTimeUtc
                    if ($dstTime -ge $srcTime) {
                        $copyIt = $false
                    }
                }

                if ($copyIt) {
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
    # STEP 5: Update local cache JSON metadata
    # ========================================================================
    if ($NeedsPull -or -not (Test-Path -LiteralPath $LocalCacheJsonPath)) {
        try {
            $newSourceHash = (Get-FileHash -LiteralPath $script:DriverConfigInfoPath -Algorithm SHA256).Hash.ToUpperInvariant()

            $preservedSchemaVersion = if ($sourceMetadata -and ($sourceMetadata.PSObject.Properties.Name -contains 'SchemaVersion') -and $sourceMetadata.SchemaVersion) {
                $sourceMetadata.SchemaVersion
            } else {
                '2.0'
            }

            $preservedModuleVersion = if ($sourceMetadata -and ($sourceMetadata.PSObject.Properties.Name -contains 'ModuleVersion') -and $sourceMetadata.ModuleVersion) {
                $sourceMetadata.ModuleVersion
            } else {
                '0.0.1'
            }

            $preservedLastModified = if ($sourceMetadata -and ($sourceMetadata.PSObject.Properties.Name -contains 'LastModified') -and $sourceMetadata.LastModified) {
                $sourceMetadata.LastModified
            } else {
                (Get-Date -Format 'o')
            }

            $preservedModifiedBy = if ($sourceMetadata -and ($sourceMetadata.PSObject.Properties.Name -contains 'ModifiedBy') -and $sourceMetadata.ModifiedBy) {
                $sourceMetadata.ModifiedBy
            } else {
                "$($env:USERNAME)@$($env:USERDOMAIN)"
            }

            $updatedConfig = [PSCustomObject]@{
                Metadata = [PSCustomObject]@{
                    SchemaVersion = $preservedSchemaVersion
                    ModuleVersion = $preservedModuleVersion
                    LastModified  = $preservedLastModified
                    ModifiedBy    = $preservedModifiedBy
                    SourceHash    = $newSourceHash
                    LastSyncedAt  = (Get-Date -Format 'o')
                }
                Drivers = @($driversArray)
            }

            $tempPath = '{0}.{1}.tmp' -f $LocalCacheJsonPath, ([guid]::NewGuid().ToString('N'))
            $updatedConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempPath -Force -ErrorAction Stop
            Move-Item -LiteralPath $tempPath -Destination $LocalCacheJsonPath -Force -ErrorAction Stop

            $hashShort = $newSourceHash.Substring(0, [Math]::Min(16, $newSourceHash.Length))
            Write-Verbose "Updated local cache metadata. SourceHash: $hashShort..."
        } catch {
            Write-Error "Failed to update local cache JSON: $_"
            if (Test-Path -LiteralPath $LocalCacheJsonBackupPath) {
                Write-Warning "Attempting rollback from backup..."
                Copy-Item -LiteralPath $LocalCacheJsonBackupPath -Destination $LocalCacheJsonPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # ========================================================================
    # STEP 6: Return status information for caller
    # ========================================================================
    [PSCustomObject]@{
        PullPerformed           = $NeedsPull
        SourceChanged           = $SourceChanged
        LocalHasUnpushedChanges = $LocalHasUnpushedChanges
        CachedDriverCount       = @($driversArray).Count
        CachePath               = $LocalCacheJsonPath
    }
}