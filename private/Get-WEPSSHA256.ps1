function Get-WEPSSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
}
