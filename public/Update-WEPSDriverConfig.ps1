function Update-WEPSDriverConfig {
    <#
    .SYNOPSIS
        Updates an existing driver configuration in the local cache and optionally pushes to source.
    .DESCRIPTION
        Updates driver version or DAT file path in the DriverConfigInfo.json file.
        Supports pushing changes to the source network share.
    .PARAMETER DriverName
        The name of the driver to update.
    .PARAMETER DriverVersion
        The new driver version.
    .PARAMETER DatFilePath
        The new DAT file path.
    .PARAMETER PushToSource
        If specified, attempts to copy the updated local cache back to the source
        network share after a successful local update.
    .EXAMPLE
        PS C:\> Update-WEPSDriverConfig -DriverName 'Generic Universal Print Driver' -DatFilePath '.\Driver3.dat'

        Updates the DAT file path for the specified driver in the local cache without changing the version.

    .EXAMPLE
        PS C:\> Update-WEPSDriverConfig -DriverName 'Generic Universal Print Driver' -DriverVersion 300000000000000 -DatFilePath '.\Driver3.dat'

        Updates both the driver version and DAT file path for the specified driver in the local cache.

    .EXAMPLE
        PS C:\> Update-WEPSDriverConfig -DriverName 'Generic Universal Print Driver' -DatFilePath '.\Driver3.dat' -PushToSource

        Updates the DAT file path locally and then pushes the updated configuration to the source
        after verifying source integrity.

    .EXAMPLE
        PS C:\> Update-WEPSDriverConfig -DriverName 'Generic Universal Print Driver' -DriverVersion 300000000000000 -DatFilePath '.\Driver3.dat' -WhatIf

        Shows what would happen if the update were performed, without modifying the local cache or source.

    .EXAMPLE
        PS C:\> Get-WEPSDriverConfig -Name 'Generic' | Update-WEPSDriverConfig -DatFilePath '.\Driver3.dat'

        Uses pipeline input to update the DAT file path for matching drivers.

    .EXAMPLE
        PS C:\> Update-WEPSDriverConfig -DriverName 'Generic Universal Print Driver' -Verbose

        Provides detailed output about the operation, including backup creation and file updates.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$DriverName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [int64]$DriverVersion,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path -Path $_ })]
        [string]$DatFilePath,

        [switch]$PushToSource
    )

    begin {
        if (($null -eq $DriverVersion) -and [string]::IsNullOrWhiteSpace($DatFilePath)) {
            throw 'Did not supply a new version or new DatFilePath; nothing to do.'
        }

        $LocalCachePath = $script:DriverConfigInfoCachePath
        $SourcePath     = $script:DriverConfigInfoPath

        if (-not (Test-Path -LiteralPath $LocalCachePath)) {
            throw "Local cache not found at '$LocalCachePath'."
        }

        if (-not ($script:DriverConfigInfo.PSObject.Properties.Name -contains 'Drivers')) {
            throw 'Driver configuration data is not in the expected wrapper format.'
        }

        $ResolvedDatFilePath = $null
        if (-not [string]::IsNullOrWhiteSpace($DatFilePath)) {
            $ResolvedDatFilePath = $PSCmdlet.GetResolvedProviderPathFromPSPath($DatFilePath, [ref]$null)
        }

        $BackupCreated = $false
        $BackupPath    = $null
    }

    process {
        $matchingDrivers = @(
            $script:DriverConfigInfo.Drivers |
                Where-Object { $_.Name -eq $DriverName }
        )

        if ($matchingDrivers.Count -eq 0) {
            Write-Warning -Message ('DriverName {0} not found; nothing to do.' -f $DriverName)
            return
        }

        if ($matchingDrivers.Count -gt 1 -and $null -eq $DriverVersion) {
            Write-Warning -Message ('DriverName {0} matched multiple entries and no DriverVersion selector was supplied; nothing was changed.' -f $DriverName)
            return
        }

        $TargetDrivers = if ($null -ne $DriverVersion) {
            @($matchingDrivers | Where-Object { $_.DriverVersion -eq $DriverVersion -or $null -eq $_.DriverVersion })
        } else {
            $matchingDrivers
        }

        if ($null -ne $DriverVersion -and $TargetDrivers.Count -eq 0) {
            # If no exact preexisting version match exists, fall back to exact name match and update that one entry.
            $TargetDrivers = @($matchingDrivers)
        }

        if ($TargetDrivers.Count -gt 1 -and $null -ne $DriverVersion) {
            $TargetDrivers = @($TargetDrivers | Select-Object -First 1)
        }

        if ($TargetDrivers.Count -eq 0) {
            Write-Warning -Message ('No matching driver entry was resolved for DriverName {0}; nothing to do.' -f $DriverName)
            return
        }

        if (($null -ne $DriverVersion) -and [string]::IsNullOrWhiteSpace($ResolvedDatFilePath)) {
            throw 'No DatFilePath supplied; this is required when updating DriverVersion.'
        }

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

        foreach ($Config in $TargetDrivers) {
            $actionDescription = if ($null -ne $DriverVersion -and $ResolvedDatFilePath) {
                "Update driver version and DAT file path"
            } elseif ($ResolvedDatFilePath) {
                "Update DAT file path"
            } else {
                "Update driver entry"
            }

            if (-not $PSCmdlet.ShouldProcess($Config.Name, $actionDescription)) {
                continue
            }

            if ($null -ne $DriverVersion) {
                $Config.DriverVersion = $DriverVersion

                if (Get-Command -Name Convert-WEPSDriverVersion -ErrorAction SilentlyContinue) {
                    try {
                        $Config.DriverVersionString = (Convert-WEPSDriverVersion -DriverVersion $DriverVersion).VersionString
                    }
                    catch {
                        Write-Verbose "Unable to compute DriverVersionString for '$($Config.Name)' from DriverVersion '$DriverVersion'."
                    }
                }
            }

            if ($ResolvedDatFilePath) {
                $Config.DATFilePath = $ResolvedDatFilePath
                $Config.SHA256      = (Get-FileHash -LiteralPath $ResolvedDatFilePath -Algorithm SHA256).Hash.ToUpperInvariant()
            }
        }

        $existingMetadata = if (
            ($script:DriverConfigInfo.PSObject.Properties.Name -contains 'Metadata') -and
            $script:DriverConfigInfo.Metadata
        ) {
            $script:DriverConfigInfo.Metadata
        } else {
            $null
        }

        $preservedSourceHash = if ($existingMetadata -and $existingMetadata.SourceHash) {
            $existingMetadata.SourceHash
        } else {
            $null
        }

        $preservedLastSyncedAt = if ($existingMetadata -and $existingMetadata.LastSyncedAt) {
            $existingMetadata.LastSyncedAt
        } else {
            $null
        }

        $newMetadata = [PSCustomObject]@{
            SchemaVersion = if ($existingMetadata -and $existingMetadata.SchemaVersion) { $existingMetadata.SchemaVersion } else { '2.0' }
            ModuleVersion = if ($existingMetadata -and $existingMetadata.ModuleVersion) { $existingMetadata.ModuleVersion } else { '0.0.1' }
            LastModified  = (Get-Date -Format 'o')
            ModifiedBy    = "$($env:USERNAME)@$($env:USERDOMAIN)"
            SourceHash    = $preservedSourceHash
            LastSyncedAt  = $preservedLastSyncedAt
        }

        $outputObj = [PSCustomObject]@{
            Metadata = $newMetadata
            Drivers  = @($script:DriverConfigInfo.Drivers)
        }

        $tempPath = '{0}.{1}.tmp' -f $LocalCachePath, ([guid]::NewGuid().ToString('N'))
        try {
            $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempPath -Force -ErrorAction Stop
            Move-Item -LiteralPath $tempPath -Destination $LocalCachePath -Force -ErrorAction Stop
            Write-Verbose "Successfully updated local cache at $LocalCachePath"

            $script:DriverConfigInfo = $outputObj
        }
        catch {
            throw "Failed to save updated local cache: $_; aborting operation."
        }

        Update-WEPSModuleDriverConfigInfo

        if ($PushToSource) {
            if (-not (Test-WEPSSourceIntegrity -CacheJsonPath $LocalCachePath -SourceJsonPath $SourcePath)) {
                throw 'Source integrity check failed. The source file has changed since the last load.'
            }

            Write-Verbose "Source integrity verified. Pushing to source..."

            $sourceTemp = '{0}.{1}.tmp' -f $SourcePath, ([guid]::NewGuid().ToString('N'))
            try {
                $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sourceTemp -Force -ErrorAction Stop
                Move-Item -LiteralPath $sourceTemp -Destination $SourcePath -Force -ErrorAction Stop
                Write-Verbose "Successfully pushed updated configuration to source: $SourcePath"

                $finalHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash.ToUpperInvariant()
                $outputObj.Metadata.SourceHash   = $finalHash
                $outputObj.Metadata.LastSyncedAt = (Get-Date -Format 'o')

                $localTemp = '{0}.{1}.tmp' -f $LocalCachePath, ([guid]::NewGuid().ToString('N'))
                $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $localTemp -Force -ErrorAction Stop
                Move-Item -LiteralPath $localTemp -Destination $LocalCachePath -Force -ErrorAction Stop

                $script:DriverConfigInfo = $outputObj
                Update-WEPSModuleDriverConfigInfo
                Write-Verbose "Updated local cache metadata to match pushed state."
            }
            catch {
                throw "Failed to push configuration to source: $_"
            }
        }
    }

    end {
        if (-not [string]::IsNullOrWhiteSpace($BackupPath)) {
            $ParentPath = [System.IO.Path]::GetDirectoryName($LocalCachePath)
            $FileName   = [System.IO.Path]::GetFileName($LocalCachePath)

            if (-not [string]::IsNullOrWhiteSpace($ParentPath) -and (Test-Path -LiteralPath $ParentPath)) {
                $BackupFiles = Get-ChildItem -LiteralPath $ParentPath -Filter "$FileName*.bak" -File -ErrorAction SilentlyContinue
                if (@($BackupFiles).Count -gt 10) {
                    $FilesToRemove = $BackupFiles | Sort-Object -Property CreationTime | Select-Object -First (@($BackupFiles).Count - 10)
                    $FilesToRemove | Remove-Item -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}
