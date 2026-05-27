function Convert-WEPSDriverVersion {
    <#
    .SYNOPSIS
        Converts a 64-bit driver version value into a readable version string.
    .DESCRIPTION
        Converts a UInt64 driver version value into its component parts (major, minor,
        build, revision) using bit shifting and masking, and returns a structured object.
    .PARAMETER DriverVersion
        The numeric driver version value.
    .EXAMPLE
        Convert-WEPSDriverVersion -DriverVersion 1234567890123456
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [uint64]$DriverVersion
    )

    $major    = ($DriverVersion -shr 48) -band 0xFFFF
    $minor    = ($DriverVersion -shr 32) -band 0xFFFF
    $build    = ($DriverVersion -shr 16) -band 0xFFFF
    $revision = $DriverVersion -band 0xFFFF

    $version       = [version]::new($major, $minor, $build, $revision)
    $versionString = $version.ToString()

    [PSCustomObject]@{
        DriverVersion = $DriverVersion
        Version       = $version
        VersionString = $versionString
    }
}
}