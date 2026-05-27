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
    [cmdletbinding(SupportsShouldProcess)]
    param(
        [parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$DriverName,

        [parameter(ValueFromPipelineByPropertyName)]
        [int64]$DriverVersion,

        [parameter(ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path -path $_ })]
        [string]$DatFilePath,

        [switch]$PushToSource
    )

    begin {
        if ($null -eq $DriverVersion -and $null -eq $DatFilePath) {
            throw 'Did not supply a new version or new datfilepath, nothing to do'
        }
        $LocalCachePath = $script:DriverConfigInfo
        $SourcePath = $script:DriverConfigInfoPath
        $DriverNameRegEx = [regex]::Escape($DriverName)

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
        $found = $false
        foreach ($Config in $script:DriverConfigInfo) {
            if ($Config.Name -match "^$DriverNameRegEx$") {
                $found = $true
                if ($DriverVersion) {
                    if (-not $DatFilePath) {
                        throw 'No DatFilePath supplied, this is required for a new driver version'
                    }
                    $Config.DriverVersion = $DriverVersion
                    $Config.FilePath = $DatFilePath
                } elseif ($DatFilePath) {
                    $Config.FilePath = $DatFilePath
                }
            }
        }

        if (-not $found) {
            Write-Warning -Message ('DriverName {0} not found; nothing to do' -f $DriverName)
            return
        }

        # Prepare output object
        $driversArray = $script:DriverConfigInfo
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
