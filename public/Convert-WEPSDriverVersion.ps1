function Convert-WEPSDriverVersion {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [uint64]$DriverVersion
    )

    $major    = ($DriverVersion -shr 48) -band 0xFFFF
    $minor    = ($DriverVersion -shr 32) -band 0xFFFF
    $build    = ($DriverVersion -shr 16) -band 0xFFFF
    $revision =  $DriverVersion          -band 0xFFFF

    try {
        $version = [version]::new($major, $minor, $build, $revision)
        $versionString = $version.ToString()
    }
    catch {
        throw "Invalid driver version components derived from '$DriverVersion'. Error: $($_.Exception.Message)"
    }

    [PSCustomObject]@{
        DriverVersion = $DriverVersion
        Version       = $version
        VersionString = $versionString
    }
}