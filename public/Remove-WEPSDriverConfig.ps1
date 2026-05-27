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
    [cmdletbinding(SupportsShouldProcess)]
    param(
        [parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$DriverName,

        [parameter(ValueFromPipelineByPropertyName)]
        [int64]$DriverVersion,

        [switch]$PushToSource
    )

    begin {
        $LocalCachePath = $script:DriverConfigInfo
        $SourcePath = $script:DriverConfigInfoPath
        
        # Backup local cache
        $BackupPath = '{0}.{1}.bak' -f $LocalCachePath, ([datetime]::Now.ToString('yyyyMMddHHmmss'))
        try {
            Copy-Item -Path $LocalCachePath -Destination $BackupPath -Force -ErrorAction Stop
            Write-Verbose "Backup of local cache created at $BackupPath"
        } catch {
            throw "Failed to create local cache backup: $_; aborting operation."
        }
    }

    process {
        # Filter logic
        if ($DriverVersion) {
            $return = $script:DriverConfigInfo.Drivers | Where-Object { -not ($_.DriverVersion -eq $DriverVersion -and $_.Name -match $DriverName ) }
            [array]$MatchingDrivers = $script:DriverConfigInfo.Drivers | Where-Object { $_.DriverVersion -eq $DriverVersion -and $_.Name -match $DriverName }
        } else {
            $return = $script:DriverConfigInfo.Drivers | Where-Object Name -notmatch $DriverName
            [array]$MatchingDrivers = $script:DriverConfigInfo.Drivers | Where-Object Name -match $DriverName
        }

        if ($MatchingDrivers.Count -eq 0) {
            throw "No matching driver found to remove."
        }

        # Prepare output object
        $driversArray = $return
        $newMetadata = [PSCustomObject]@{
            SchemaVersion = "2.0"
            ModuleVersion = "0.0.1"
            LastModified = (Get-Date -Format 'o')
            ModifiedBy = "$($env:USERNAME)@$($env:USERDOMAIN)"
            SourceHash = (Get-FileHash -LiteralPath $LocalCachePath -Algorithm SHA256).Hash
            LastSyncedAt = (Get-Date -Format 'o')
        }
        $outputObj = [PSCustomObject]@{
            Metadata = $newMetadata
            Drivers = $driversArray
        }

        # Write to Local Cache (Atomic)
        $tempPath = '{0}.{1}.tmp' -f $LocalCachePath, ([guid]::NewGuid().ToString('N'))
        try {
            $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempPath -Force -ErrorAction Stop
            Move-Item -LiteralPath $tempPath -Destination $LocalCachePath -Force -ErrorAction Stop
            Write-Verbose "Successfully updated local cache at $LocalCachePath"
        } catch {
            throw "Failed to save updated local cache: $_; aborting operation."
        }

        Update-WEPSModuleDriverConfigInfo

        # Handle Push to Source
        if ($PushToSource) {
            if (Test-WEPSSourceIntegrity -CacheJsonPath $LocalCachePath -SourceJsonPath $SourcePath) {
                Write-Verbose "Source integrity verified. Pushing to source..."
                
                $finalHash = (Get-FileHash -LiteralPath $LocalCachePath -Algorithm SHA256).Hash
                $outputObj.Metadata.SourceHash = $finalHash
                $outputObj.Metadata.LastSyncedAt = (Get-Date -Format 'o')
                
                $sourceTemp = '{0}.{1}.tmp' -f $SourcePath, ([guid]::NewGuid().ToString('N'))
                try {
                    $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sourceTemp -Force -ErrorAction Stop
                    Move-Item -LiteralPath $sourceTemp -Destination $SourcePath -Force -ErrorAction Stop
                    Write-Verbose "Successfully pushed updated configuration to source: $SourcePath"
                    
                    # Sync local cache again
                    $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $LocalCachePath -Force -ErrorAction Stop
                    Update-WEPSModuleDriverConfigInfo
                } catch {
                    throw "Failed to push configuration to source: $_"
                }
            } else {
                throw "Source integrity check failed. The source file has changed since the last load."
            }
        }
    }

    end {
        # Cleanup old backups
        $ParentPath = Split-Path -Path $LocalCachePath
        $BackupFiles = Get-ChildItem -Path "$ParentPath\$LocalCachePath*.bak"
        if ($BackupFiles.Count -gt 10) {
            $FilesToRemove = $BackupFiles | Sort-Object -Property CreationTime | Select-Object -First ($BackupFiles.Count - 10)
            $FilesToRemove | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}