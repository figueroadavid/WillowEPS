
function Convert-UInt64ToVersion {
    param (
        [UInt64]$Value
    )

    $Major = ($Value -shr 48) -band 0xFFFF
    $Minor = ($Value -shr 32) -band 0xFFFF
    $Build = ($Value -shr 16) -band 0xFFFF
    $Revision =  $Value -band 0xFFFF

    [version]::new($Major, $Minor, $Build, $Revision)
}
