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

        $DatFilePath    = $PSCmdlet.GetResolvedProviderPathFromPSPath($DatFilePath, [ref]$null)
        $LocalCachePath = $script:DriverConfigInfo
        $SourcePath     = $script:DriverConfigInfoPath
        $BackupPath     = '{0}.{1}.bak' -f $LocalCachePath, ([DateTime]::Now.ToString('yyyyMMddHHmmss'))

        try {
            Copy-Item -Path $LocalCachePath -Destination $BackupPath -Force -ErrorAction Stop
            Write-Verbose "Backup of local cache created at $BackupPath"
        }
        catch {
            Write-WEPSAuditLog -Action 'AddDriver' -Details 'Failed to create backup' -Result 'Failure' -Target $DriverName -Error $_.Exception.Message
            throw "Failed to create local cache backup: $_; aborting operation."
        }
    }

    process {
        $success = $false
        $errorMessage = $null

        try {
            if ($script:DriverConfigInfo.Drivers.Name -contains $DriverName) {
                Write-Warning -Message ('Local cache already contains a driver named {0}; this could result in a duplicate entry' -f $DriverName)

                foreach ($Config in $script:DriverConfigInfo) {
                    if ($Config.Name -match $DriverName -and $Config.DriverVersion -eq $DriverVersion) {
                        Write-Warning -Message ('Local cache already contains the entry for {0} with version {1}; nothing to do' -f $Config.Name, $Config.DriverVersion)
                        throw 'Driver entry already exists'
                    }
                }
            }

            $thisDriver = Get-PrinterDriver -Name $DriverName | Select-Object -Property Name, DriverVersion

            if (-not $thisDriver) {
                throw "Driver '$DriverName' not found on this system. Please install the driver first."
            }

            $NewEntry = [PSCustomObject]@{
                Name          = $thisDriver.Name
                DriverVersion = $thisDriver.DriverVersion
                DATFilePath   = $DatFilePath
                SHA256        = (Get-FileHash -Path $DatFilePath -Algorithm SHA256).Hash
            }

            $script:DriverConfigInfo.Drivers += $NewEntry
            $script:DriverConfigInfo.Drivers = $script:DriverConfigInfo.Drivers | Sort-Object -Property Name

            $currentHash = (Get-FileHash -LiteralPath $LocalCachePath -Algorithm SHA256).Hash
            $newMetadata = [PSCustomObject]@{
                SchemaVersion = '2.0'
                ModuleVersion = '0.0.1'
                LastModified  = (Get-Date -Format 'o')
                ModifiedBy    = "$($env:USERNAME)@$($env:USERDOMAIN)"
                SourceHash    = $currentHash
                LastSyncedAt  = (Get-Date -Format 'o')
            }

            $driversArray = $script:DriverConfigInfo
            $outputObj = [PSCustomObject]@{
                Metadata = $newMetadata
                Drivers  = $driversArray
            }

            $tempPath = '{0}.{1}.tmp' -f $LocalCachePath, ([Guid]::NewGuid().ToString('N'))
            $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempPath -Force -ErrorAction Stop
            Move-Item -LiteralPath $tempPath -Destination $LocalCachePath -Force -ErrorAction Stop
            Write-Verbose "Successfully updated local cache at $LocalCachePath"

            Update-WEPSModuleDriverConfigInfo

            if ($PushToSource) {
                Write-Verbose 'PushToSource requested. Checking source integrity...'

                if (Test-WEPSSourceIntegrity -CacheJsonPath $LocalCachePath -SourceJsonPath $SourcePath) {
                    Write-Verbose 'Source integrity verified. Pushing to source...'

                    $finalHash = (Get-FileHash -LiteralPath $LocalCachePath -Algorithm SHA256).Hash
                    $outputObj.Metadata.SourceHash = $finalHash
                    $outputObj.Metadata.LastSyncedAt = (Get-Date -Format 'o')

                    $sourceTemp = '{0}.{1}.tmp' -f $SourcePath, ([Guid]::NewGuid().ToString('N'))
                    $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sourceTemp -Force -ErrorAction Stop
                    Move-Item -LiteralPath $sourceTemp -Destination $SourcePath -Force -ErrorAction Stop
                    Write-Verbose "Successfully pushed updated configuration to source: $SourcePath"

                    $outputObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $LocalCachePath -Force -ErrorAction Stop
                    Update-WEPSModuleDriverConfigInfo

                    try {
                        Copy-Item -Path $DatFilePath -Destination $script:SourceDataDir -Force -ErrorAction Stop
                        Write-Verbose "Successfully copied DAT file to source data directory: $($script:SourceDataDir)"
                    }
                    catch {
                        Write-Warning "Failed to copy DAT file to source data directory: $($script:SourceDataDir). The driver config was added and source JSON updated, but the DAT file is missing from the source data directory."
                    }
                }
                else {
                    throw 'Source integrity check failed. The source file has changed since the last load.'
                }
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
        $ParentPath = Split-Path -Path $LocalCachePath
        $BackupFiles = Get-ChildItem -Path "$ParentPath\$LocalCachePath*.bak"
        if ($BackupFiles.Count -gt 10) {
            $FilesToRemove = $BackupFiles | Sort-Object -Property CreationTime | Select-Object -First ($BackupFiles.Count - 10)
            $FilesToRemove | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}