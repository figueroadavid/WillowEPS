function Add-WEPSDriverConfig {
    <#
    .SYNOPSIS
        Adds a new driver to the local cache and optionally pushes it to the shared source.
    .DESCRIPTION
        Adds a new driver entry to the DriverConfigInfo.json file. The function first
        updates the local cache. If the -PushToSource switch is used, it validates
        that the source file has not changed and then copies the updated file back
        to the shared source location.
    .PARAMETER DriverName
        The exact name of the installed driver to add.
    .PARAMETER DatFilePath
        The path to the .dat file.
    .PARAMETER PushToSource
        If specified, attempts to copy the updated local cache back to the shared
        source location after a successful local update.
    .PARAMETER WhatIf
        Shows what would happen if the command ran.
    .PARAMETER Confirm
        Prompts for confirmation before proceeding.
    .EXAMPLE
        Add-WEPSDriverConfig -DriverName 'Generic Universal Print Driver' -DatFilePath '.\DriverConfig.dat'
    .EXAMPLE
        Add-WEPSDriverConfig -DriverName 'Generic Universal Print Driver' -DatFilePath '.\DriverConfig.dat' -PushToSource
    .NOTES
        All actions are logged to the audit log for compliance tracking.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$DriverName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path -Path $_ })]
        [string]$DatFilePath,

        [switch]$PushToSource
    )

    begin {
        Initialize-WEPSAuditLog

        $LocalCachePath = $script:DriverConfigInfoCachePath
        $SourcePath     = $script:DriverConfigInfoPath

        if (-not (Test-Path -LiteralPath $LocalCachePath)) {
            throw "Local cache not found at '$LocalCachePath'."
        }

        if (-not ($script:DriverConfigInfo.PSObject.Properties.Name -contains 'Drivers')) {
            throw 'Driver configuration data is not in the expected wrapper format.'
        }

        $ResolvedDatFilePath = $PSCmdlet.GetResolvedProviderPathFromPSPath($DatFilePath, [ref]$null)

        $BackupCreated = $false
        $BackupPath    = $null
    }

    process {
        $success      = $false
        $errorMessage = $null
        $thisDriver   = $null

        try {
            $thisDriver = Get-PrinterDriver -Name $DriverName -ErrorAction Stop | Select-Object -Property Name, DriverVersion

            if (-not $thisDriver) {
                throw "Driver '$DriverName' not found on this system. Please install the driver first."
            }

            $existingExactMatches = @(
                $script:DriverConfigInfo.Drivers |
                    Where-Object {
                        $_.Name -eq $thisDriver.Name -and
                        $_.DriverVersion -eq $thisDriver.DriverVersion
                    }
            )

            if ($existingExactMatches.Count -gt 0) {
                throw ('Driver entry already exists for {0} with version {1}.' -f $thisDriver.Name, $thisDriver.DriverVersion)
            }

            if (-not $BackupCreated) {
                $BackupPath = '{0}.{1}.bak' -f $LocalCachePath, ([DateTime]::Now.ToString('yyyyMMddHHmmss'))
                try {
                    Copy-Item -LiteralPath $LocalCachePath -Destination $BackupPath -Force -ErrorAction Stop
                    Write-Verbose "Backup of local cache created at $BackupPath"
                    $BackupCreated = $true
                }
                catch {
                    Write-WEPSAuditLog -Action 'AddDriver' -Details 'Failed to create backup' -Result 'Failure' -Target $DriverName -Error $_.Exception.Message
                    throw "Failed to create local cache backup: $_; aborting operation."
                }
            }

            if (-not $PSCmdlet.ShouldProcess($DriverName, 'Add driver configuration entry')) {
                return
            }

            $DriverVersionString = $null
            if (Get-Command -Name Convert-WEPSDriverVersion -ErrorAction SilentlyContinue) {
                try {
                    $DriverVersionString = (Convert-WEPSDriverVersion -DriverVersion $thisDriver.DriverVersion).VersionString
                }
                catch {
                    Write-Verbose "Unable to compute DriverVersionString for '$($thisDriver.Name)'."
                }
            }

            $NewEntry = [PSCustomObject]@{
                Name                = $thisDriver.Name
                DriverVersion       = $thisDriver.DriverVersion
                DriverVersionString = $DriverVersionString
                DATFilePath         = $ResolvedDatFilePath
                SHA256              = (Get-FileHash -LiteralPath $ResolvedDatFilePath -Algorithm SHA256).Hash.ToUpperInvariant()
            }

            $updatedDrivers = @($script:DriverConfigInfo.Drivers) + $NewEntry
            $updatedDrivers = @($updatedDrivers | Sort-Object -Property Name, DriverVersion)

            $existingMetadata = if (
                ($script:DriverConfigInfo.PSObject.Properties.Name -contains 'Metadata') -and
                $script:DriverConfigInfo.Metadata
            ) {
                $script:DriverConfigInfo.Metadata
            }
            else {
                $null
            }

            $preservedSourceHash = if ($existingMetadata -and $existingMetadata.SourceHash) {
                $existingMetadata.SourceHash
            }
            else {
                $null
            }

            $preservedLastSyncedAt = if ($existingMetadata -and $existingMetadata.LastSyncedAt) {
                $existingMetadata.LastSyncedAt
            }
            else {
                $null
            }

            $localMetadata = [PSCustomObject]@{
                SchemaVersion = if ($existingMetadata -and $existingMetadata.SchemaVersion) { $existingMetadata.SchemaVersion } else { '2.0' }
                ModuleVersion = if ($existingMetadata -and $existingMetadata.ModuleVersion) { $existingMetadata.ModuleVersion } else { '0.0.1' }
                LastModified  = (Get-Date -Format 'o')
                ModifiedBy    = "$($env:USERNAME)@$($env:USERDOMAIN)"
                SourceHash    = $preservedSourceHash
                LastSyncedAt  = $preservedLastSyncedAt
            }

            $localOutputObj = [PSCustomObject]@{
                Metadata = $localMetadata
                Drivers  = $updatedDrivers
            }

            $tempPath = '{0}.{1}.tmp' -f $LocalCachePath, ([Guid]::NewGuid().ToString('N'))
            $localOutputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempPath -Force -ErrorAction Stop
            Move-Item -LiteralPath $tempPath -Destination $LocalCachePath -Force -ErrorAction Stop
            Write-Verbose "Successfully updated local cache at $LocalCachePath"

            $script:DriverConfigInfo = $localOutputObj
            Update-WEPSModuleDriverConfigInfo

            if ($PushToSource) {
                Write-Verbose 'PushToSource requested. Checking source integrity...'

                if (-not (Test-WEPSSourceIntegrity -CacheJsonPath $LocalCachePath -SourceJsonPath $SourcePath)) {
                    throw 'Source integrity check failed. The source file has changed since the last load.'
                }

                Write-Verbose 'Source integrity verified. Pushing to source...'

                $SourceDatFileName = [System.IO.Path]::GetFileName($ResolvedDatFilePath)
                $SourceDatFilePath = [System.IO.Path]::Combine($script:SourceDataDir, $SourceDatFileName)

                $sourceDrivers = foreach ($driver in $updatedDrivers) {
                    [PSCustomObject]@{
                        Name                = $driver.Name
                        DriverVersion       = $driver.DriverVersion
                        DriverVersionString = $driver.DriverVersionString
                        DATFilePath         = [System.IO.Path]::Combine($script:SourceDataDir, [System.IO.Path]::GetFileName($driver.DATFilePath))
                        SHA256              = $driver.SHA256
                    }
                }

                $sourceMetadata = [PSCustomObject]@{
                    SchemaVersion = $localMetadata.SchemaVersion
                    ModuleVersion = $localMetadata.ModuleVersion
                    LastModified  = (Get-Date -Format 'o')
                    ModifiedBy    = "$($env:USERNAME)@$($env:USERDOMAIN)"
                    LastSyncedAt  = (Get-Date -Format 'o')
                }

                $sourceOutputObj = [PSCustomObject]@{
                    Metadata = $sourceMetadata
                    Drivers  = @($sourceDrivers)
                }

                $sourceTemp = '{0}.{1}.tmp' -f $SourcePath, ([Guid]::NewGuid().ToString('N'))
                $sourceOutputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sourceTemp -Force -ErrorAction Stop
                Move-Item -LiteralPath $sourceTemp -Destination $SourcePath -Force -ErrorAction Stop
                Write-Verbose "Successfully pushed updated configuration to source: $SourcePath"

                try {
                    Copy-Item -LiteralPath $ResolvedDatFilePath -Destination $SourceDatFilePath -Force -ErrorAction Stop
                    Write-Verbose "Successfully copied DAT file to source data directory: $($script:SourceDataDir)"
                }
                catch {
                    throw "Driver configuration was pushed, but the DAT file could not be copied to the source data directory: $($_.Exception.Message)"
                }

                $finalHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash.ToUpperInvariant()

                $localOutputObj.Metadata.SourceHash   = $finalHash
                $localOutputObj.Metadata.LastSyncedAt = (Get-Date -Format 'o')

                $localTemp = '{0}.{1}.tmp' -f $LocalCachePath, ([Guid]::NewGuid().ToString('N'))
                $localOutputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $localTemp -Force -ErrorAction Stop
                Move-Item -LiteralPath $localTemp -Destination $LocalCachePath -Force -ErrorAction Stop

                $script:DriverConfigInfo = $localOutputObj
                Update-WEPSModuleDriverConfigInfo
                Write-Verbose "Updated local cache metadata to match pushed state."
            }

            $success = $true
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Error "Failed to add driver: $_"
        }
        finally {
            if ($success) {
                Write-WEPSAuditLog -Action 'AddDriver' -Details "Added driver with version $($thisDriver.DriverVersion)" -Result 'Success' -Target $DriverName
            }
            else {
                Write-WEPSAuditLog -Action 'AddDriver' -Details 'Failed to add driver' -Result 'Failure' -Target $DriverName -Error $errorMessage
            }
        }
    }

    end {
        if (-not [string]::IsNullOrEmpty($LocalCachePath)) {
            $ParentPath = [System.IO.Path]::GetDirectoryName($LocalCachePath)
            $FileName   = [System.IO.Path]::GetFileName($LocalCachePath)

            if (-not [string]::IsNullOrEmpty($ParentPath) -and (Test-Path -LiteralPath $ParentPath)) {
                $BackupFiles = Get-ChildItem -LiteralPath $ParentPath -Filter "$FileName*.bak" -File -ErrorAction SilentlyContinue
                if (@($BackupFiles).Count -gt 10) {
                    $FilesToRemove = $BackupFiles | Sort-Object -Property CreationTime | Select-Object -First (@($BackupFiles).Count - 10)
                    $FilesToRemove | Remove-Item -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}