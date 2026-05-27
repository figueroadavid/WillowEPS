function Copy-WEPSFileAtomic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $destDir = Split-Path -Path $Destination -Parent
    New-WEPSDirectory -Path $destDir

    $tmp = '{0}.{1}.tmp' -f $Destination, ([guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath $Source -Destination $tmp -Force -ErrorAction Stop
    Move-Item -LiteralPath $tmp -Destination $Destination -Force -ErrorAction Stop
}