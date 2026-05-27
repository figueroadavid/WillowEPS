function Initialize-WEPSAuditLog {
    <#
    .SYNOPSIS
        Initializes the audit log directory and file.
    .DESCRIPTION
        Creates the log directory if it doesn't exist and initializes the audit log file.
        Implements weekly log rotation to keep the active log file manageable.
    .NOTES
        Logs are retained for 90 days. Old logs are moved to a 'Archive' subfolder.
    #>
    [CmdletBinding()]
    param()

    # Define paths
    $LogPath = [System.IO.Path]::Combine($script:CacheRoot, 'Logs')
    $ActiveLogPath = [System.IO.Path]::Combine($LogPath, 'WEPS_Audit.log')
    $ArchivePath = [System.IO.Path]::Combine($LogPath, 'Archive')

    # Ensure main log directory exists
    if (-not (Test-Path -LiteralPath $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
        Write-Verbose "Created audit log directory: $LogPath"
    }

    # Ensure archive directory exists
    if (-not (Test-Path -LiteralPath $ArchivePath)) {
        New-Item -Path $ArchivePath -ItemType Directory -Force | Out-Null
    }

    # Weekly Rotation Logic
    $currentWeek = (Get-Date).WeekOfYear
    $currentYear = (Get-Date).Year

    if (Test-Path -LiteralPath $ActiveLogPath) {
        $lastWrite = (Get-Item -LiteralPath $ActiveLogPath).LastWriteTime
        $lastWeek = $lastWrite.WeekOfYear
        $lastYear = $lastWrite.Year

        # If the week or year has changed, rotate the log
        if ($lastWeek -ne $currentWeek -or $lastYear -ne $currentYear) {
            $archiveName = "WEPS_Audit_{0}_W{1}.log" -f $lastYear, $lastWeek
            $archiveDest = [System.IO.Path]::Combine($ArchivePath, $archiveName)

            try {
                Move-Item -LiteralPath $ActiveLogPath -Destination $archiveDest -Force -ErrorAction Stop
                
                # Clean up old archives (keep last 12 weeks / ~3 months)
                $oldArchives = Get-ChildItem -Path $ArchivePath -Filter "WEPS_Audit_*.log" | 
                               Sort-Object LastWriteTime -Descending | 
                               Select-Object -Skip 12
                
                foreach ($old in $oldArchives) {
                    Remove-Item -LiteralPath $old.FullName -Force -ErrorAction SilentlyContinue
                }

                Write-Verbose "Rotated audit log to: $archiveDest"
            } catch {
                Write-Warning "Failed to rotate audit log: $_"
            }
        }
    }

    # Ensure the active log file exists
    if (-not (Test-Path -LiteralPath $ActiveLogPath)) {
        try {
            New-Item -Path $ActiveLogPath -ItemType File -Force | Out-Null
            Write-Verbose "Initialized new audit log file: $ActiveLogPath"
        } catch {
            Write-Warning "Failed to create audit log file: $_"
        }
    }
}