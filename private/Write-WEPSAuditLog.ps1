function Write-WEPSAuditLog {
    <#
    .SYNOPSIS
        Writes an entry to the audit log.
    .DESCRIPTION
        Records administrative actions with timestamp, user, action type, and details.
        The log is stored as a CSV file for easy parsing and reporting.
    .PARAMETER Action
        The type of action performed (e.g., 'AddDriver', 'RemovePrinter', 'PublishConfig').
    .PARAMETER Details
        Additional details about the action (e.g., "Added driver version 1.2.3").
    .PARAMETER Result
        The outcome of the action. Valid values: 'Success', 'Failure', 'Warning'.
    .PARAMETER Target
        The specific object affected (e.g., printer name, driver name).
    .PARAMETER Server
        The server where the action was performed (if applicable).
    .PARAMETER Error
        Error message if the action failed.
    .EXAMPLE
        Write-WEPSAuditLog -Action 'AddDriver' -Details 'Added Lexmark Universal v2' -Result 'Success' -Target 'Lexmark Universal v2'
    .EXAMPLE
        Write-WEPSAuditLog -Action 'PublishConfig' -Details 'Forced overwrite' -Result 'Failure' -Target 'Global' -Error 'Source hash mismatch'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Details,

        [Parameter(Mandatory)]
        [ValidateSet('Success', 'Failure', 'Warning')]
        [string]$Result,

        [string]$Target,

        [string]$Server,

        [string]$thisError
    )

    # Ensure log is initialized
    Initialize-WEPSAuditLog

    $LogPath = [System.IO.Path]::Combine($script:CacheRoot, 'Logs', 'WEPS_Audit.log')

    if (-not (Test-Path -LiteralPath $LogPath)) {
        Write-Warning "Audit log file not found at $LogPath. Cannot write entry."
        return
    }

    # Construct the log entry object
    $logEntry = [PSCustomObject]@{
        Timestamp   = (Get-Date -Format 'o')
        User        = "$($env:USERNAME)@$($env:USERDOMAIN)"
        Computer    = $env:COMPUTERNAME
        Action      = $Action
        Target      = $Target
        Server      = $Server
        Details     = $Details
        Result      = $Result
        Error       = $thisError
    }

    # Append to CSV
    try {
        # Use -Append to add to existing file, -NoTypeInformation to skip header type info
        # If file is empty, it will create headers automatically
        $logEntry | Export-Csv -LiteralPath $LogPath -Append -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write audit log entry: $_"
    }
}