function Remove-WEPSDriverConfig {
    <#
    .SYNOPSIS
        Removes a driver from the local cache and optionally pushes to source.
    .DESCRIPTION
        Removes a driver entry from the DriverConfigInfo.json file. Supports
        removing by name only or by name and version. Optionally pushes changes
        to the source network share.
    .PARAMETER DriverName
        The name of the driver to remove.
    .PARAMETER DriverVersion
        Optional. If specified, only removes the entry matching this specific version.
    .PARAMETER PushToSource
        If specified, attempts to copy the updated local cache back to the source
        network share after a successful local update.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$DriverName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [int64]$DriverVersion,

        [switch]$PushToSource
    )

    begin {
        $LocalCachePath = $script:DriverConfigInfoCachePath
        $SourcePath     = $script:DriverConfigInfoPath

        if (-not (Test-Path -LiteralPath $LocalCachePath)) {
            throw "Local cache not found at '$LocalCachePath'."
        }

        if (-not ($script:DriverConfigInfo.PSObject.Properties.Name -contains 'Drivers')) {
            throw 'Driver configuration data is not in the expected wrapper format.'
        }

        $BackupCreated = $false
        $BackupPath    = $null
    }

    process {
        $existingDrivers = @($script:DriverConfigInfo.Drivers)

        # --- Resolve matches (EXACT MATCH ONLY — SAFETY) ---
        $MatchingDrivers = if ($PSBoundParameters.ContainsKey('DriverVersion')) {
            @(
                $existingDrivers |
                    Where-Object {
                        $_.Name -eq $DriverName -and
                        $_.DriverVersion -eq $DriverVersion
                    }
            )
        } else {
            @(
                $existingDrivers |
                    Where-Object {
                        $_.Name -eq $DriverName
                    }
            )
        }

        if ($MatchingDrivers.Count -eq 0) {
            throw "No matching driver found to remove."
        }

        # --- Backup (once per execution) ---
        if (-not $BackupCreated) {
            $BackupPath = '{0}.{1}.bak' -f $LocalCachePath, ([datetime]::Now.ToString('yyyyMMddHHmmss'))
            try {
                Copy-Item -LiteralPath $LocalCachePath -Destination $BackupPath -Force -ErrorAction Stop
                Write-Verbose "Backup of local cache created at $BackupPath"
                $BackupCreated = $true
            }
            catch {
                throw "Failed to create local cache backup: $_; aborting operation."
            }
        }

        $ActionDescription = if ($PSBoundParameters.ContainsKey('DriverVersion')) {
            "Remove driver '$DriverName' version '$DriverVersion'"
        } else {
            "Remove all entries for driver '$DriverName'"
        }

        if (-not $PSCmdlet.ShouldProcess($DriverName, $ActionDescription)) {
            return
        }

        # --- Remove matching entries ---
        $remainingDrivers = if ($PSBoundParameters.ContainsKey('DriverVersion')) {
            @(
                $existingDrivers |
                    Where-Object {
                        -not ($_.Name -eq $DriverName -and $_.DriverVersion -eq $DriverVersion)
                    }
            )
        } else {
            @(
                $existingDrivers |
                    Where-Object {
                        $_.Name -ne $DriverName
                    }
            )
        }

        # --- Preserve metadata contract ---
        $existingMetadata = if (
            ($script:DriverConfigInfo.PSObject.Properties.Name -contains 'Metadata') -and
            $script:DriverConfigInfo.Metadata
        ) {
            $script:DriverConfigInfo.Metadata
        } else {
            $null
        }

        $newMetadata = [PSCustomObject]@{
            SchemaVersion = if ($existingMetadata -and $existingMetadata.SchemaVersion) { $existingMetadata.SchemaVersion } else { '2.0' }
            ModuleVersion = if ($existingMetadata -and $existingMetadata.ModuleVersion) { $existingMetadata.ModuleVersion } else { '0.0.1' }
            LastModified  = (Get-Date -Format 'o')
            ModifiedBy    = "$($env:USERNAME)@$($env:USERDOMAIN)"
            SourceHash    = if ($existingMetadata) { $existingMetadata.SourceHash } else { $null }
            LastSyncedAt  = if ($existingMetadata) { $existingMetadata.LastSyncedAt } else { $null }
        }

        $outputObj = [PSCustomObject]@{
            Metadata = $newMetadata
            Drivers  = @($remainingDrivers)
        }

        # --- Atomic write (local) ---
        $tempPath = '{0}.{1}.tmp' -f $LocalCachePath, ([guid]::NewGuid().ToString('N'))
        try {
            $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempPath -Force -ErrorAction Stop
            Move-Item -LiteralPath $tempPath -Destination $LocalCachePath -Force -ErrorAction Stop

            $script:DriverConfigInfo = $outputObj
            Write-Verbose "Successfully updated local cache at $LocalCachePath"
        }
        catch {
            throw "Failed to save updated local cache: $_; aborting operation."
        }

        Update-WEPSModuleDriverConfigInfo

        # --- Push to source ---
        if ($PushToSource) {
            if (-not (Test-WEPSSourceIntegrity -CacheJsonPath $LocalCachePath -SourceJsonPath $SourcePath)) {
                throw "Source integrity check failed. The source file has changed since the last load."
            }

            Write-Verbose "Source integrity verified. Pushing to source..."

            $sourceTemp = '{0}.{1}.tmp' -f $SourcePath, ([guid]::NewGuid().ToString('N'))
            try {
                $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sourceTemp -Force -ErrorAction Stop
                Move-Item -LiteralPath $sourceTemp -Destination $SourcePath -Force -ErrorAction Stop

                $finalHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash.ToUpperInvariant()
                $outputObj.Metadata.SourceHash   = $finalHash
                $outputObj.Metadata.LastSyncedAt = (Get-Date -Format 'o')

                $localTemp = '{0}.{1}.tmp' -f $LocalCachePath, ([guid]::NewGuid().ToString('N'))
                $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $localTemp -Force -ErrorAction Stop
                Move-Item -LiteralPath $localTemp -Destination $LocalCachePath -Force -ErrorAction Stop

                $script:DriverConfigInfo = $outputObj
                Update-WEPSModuleDriverConfigInfo

                Write-Verbose "Successfully pushed updated configuration to source: $SourcePath"
            }
            catch {
                throw "Failed to push configuration to source: $_"
            }
        }
    }

    end {
        # --- Cleanup old backups (keep last 10) ---
        if (-not [string]::IsNullOrEmpty($LocalCachePath)) {
            $ParentPath = [System.IO.Path]::GetDirectoryName($LocalCachePath)
            $FileName   = [System.IO.Path]::GetFileName($LocalCachePath)

            if (-not [string]::IsNullOrEmpty($ParentPath) -and (Test-Path -LiteralPath $ParentPath)) {
                $BackupFiles = Get-ChildItem -LiteralPath $ParentPath -Filter "$FileName*.bak" -File -ErrorAction SilentlyContinue

                if (@($BackupFiles).Count -gt 10) {
                    $FilesToRemove = $BackupFiles |
                        Sort-Object -Property CreationTime |
                        Select-Object -First (@($BackupFiles).Count - 10)

                    $FilesToRemove | Remove-Item -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}