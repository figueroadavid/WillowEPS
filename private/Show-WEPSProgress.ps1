function Show-WEPSProgress {
    <#
    .SYNOPSIS
        Displays a progress bar for long-running operations.
    .DESCRIPTION
        A wrapper around Write-Progress that provides consistent formatting
        across the module.
    .PARAMETER Activity
        The activity being performed.
    .PARAMETER Status
        The current status message.
    .PARAMETER PercentComplete
        Percentage complete (0-100).
    .PARAMETER CurrentOperation
        The specific operation being performed.
    .PARAMETER Id
        Progress ID for grouping related operations.
    .PARAMETER ParentId
        Parent progress ID for nested operations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,

        [Parameter(Mandatory)]
        [string]$Status,

        [int]$PercentComplete = -1,

        [string]$CurrentOperation,

        [int]$Id = 1,

        [int]$ParentId = 0
    )

    $progressParams = @{
        Activity = $Activity
        Status = $Status
        Id = $Id
        ParentId = $ParentId
    }

    if ($PercentComplete -ge 0) {
        $progressParams.PercentComplete = $PercentComplete
    }

    if ($CurrentOperation) {
        $progressParams.CurrentOperation = $CurrentOperation
    }

    Write-Progress @progressParams
}