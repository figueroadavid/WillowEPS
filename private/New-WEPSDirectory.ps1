function New-WEPSDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        $null = New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop
    }
}
