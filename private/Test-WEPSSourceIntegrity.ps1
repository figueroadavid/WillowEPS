function Test-WEPSSourceIntegrity {
    <#
    .SYNOPSIS
        Validates that the source configuration file matches the expected hash.
    .DESCRIPTION
        Compares the current SHA256 hash of the source JSON file against the 
        SourceHash stored in the local cache metadata. Returns $true if they match,
        indicating it is safe to push changes. Returns $false if the source has
        changed, indicating a potential conflict.
    .PARAMETER CacheJsonPath
        Path to the local cache JSON file (contains the expected SourceHash).
    .PARAMETER SourceJsonPath
        Path to the source JSON file on the network share.
    .OUTPUTS
        [bool]
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$CacheJsonPath,

        [Parameter(Mandatory)]
        [string]$SourceJsonPath
    )

    if (-not (Test-Path -LiteralPath $CacheJsonPath)) {
        Write-Verbose "Local cache not found. Assuming safe to push."
        return $true
    }

    if (-not (Test-Path -LiteralPath $SourceJsonPath)) {
        Write-Verbose "Source file not found. Assuming safe to push."
        return $true
    }

    try {
        $cacheData = Get-Content -LiteralPath $CacheJsonPath -Raw | ConvertFrom-Json
        $expectedHash = $cacheData.Metadata.SourceHash

        if (-not $expectedHash) {
            Write-Verbose "No SourceHash in local cache. Assuming safe to push."
            return $true
        }

        $actualHash = (Get-FileHash -LiteralPath $SourceJsonPath -Algorithm SHA256).Hash.ToUpperInvariant()

        if ($expectedHash -eq $actualHash) {
            Write-Verbose "Source integrity check passed. Hashes match."
            return $true
        } else {
            Write-Verbose "Source integrity check FAILED. Hash mismatch detected."
            Write-Verbose "  Expected: $($expectedHash.Substring(0,16))..."
            Write-Verbose "  Actual:   $($actualHash.Substring(0,16))..."
            return $false
        }
    } catch {
        Write-Warning "Failed to verify source integrity: $_"
        return $false
    }
}