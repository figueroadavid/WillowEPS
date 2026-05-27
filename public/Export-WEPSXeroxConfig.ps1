function Export-WEPSXeroxConfig {
    <#
    .SYNOPSIS
        Exports a subset of registry values for a given printer.
    .DESCRIPTION
        Exports a defined allow-list of registry values for a printer driver
        configuration into a JSON file. This can be used for configuration
        replication using a companion import function.
    .NOTES
        The exported data is written to a JSON file and may include binary
        values encoded as Base64.
		
		The script was designed to help replicate specific features of a Xerox printer that uses the 
		Xerox Global Print Driver PCL6, particularly the stapling feature, which is controlled 
		by a specific set of registry values.  It has not been tested against other printers or drivers 
		not using the 5591.900.0.0 version of the driver. If used with other drivers or versions, 
		proceed with caution at your own risk.
    .EXAMPLE
        Export-WEPSXeroxConfig -PrinterName "PRN-01" -FilePath "C:\Temp\PrinterConfig.json"
    .PARAMETER PrinterName
        The name of the printer to export configuration from.
    .PARAMETER FilePath
        The destination JSON file path.
    .PARAMETER Force
        Overwrites the destination file if it already exists.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PrinterName,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter()]
        [switch]$Force
    )

    if ((Test-Path -LiteralPath $FilePath) -and (-not $Force)) {
        Write-Warning ('The file ({0}) already exists, and Force not specified, not proceeding' -f $FilePath)
        return
    }

    $currentExtension = $FilePath.Split('.')[-1]
    if ($currentExtension -ne 'json') {
        Write-Warning ('The extension for {0} is not .json; appending .json, new name: {0}.json' -f $FilePath)
        $FilePath = '{0}.json' -f $FilePath
    }

    $baseKey = "registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Print\Printers\$PrinterName"

    $ValueMap = @{
        '' = @(
            'Default DevMode'
        )
        'DSDriver' = @(
            'printBinNames',
            'printColor',
            'printStaplingSupport',
            'printMediaSupported',
            'printMaxXExtent',
            'printMaxYExtent',
            'printMinXExtent',
            'printMinYExtent',
            'printRate',
            'printPagesPerMinute'
        )
        'PrinterDriverData' = @(
            'xColor',
            'xUPDCurrentModel',
            'xCurrentProdUID',
            'XrxDeviceSettings',
            'NamedSettingsSupported',
            'TrayFormTable',
            'TrayFormMapSize',
            'TrayFormMap',
            'TrayFormKeywordSize',
            'TrayFormKeyword',
            'FontCart',
            'AdminDevDefaults',
            'AdminDocDefaults'
        )
    }

    $result = foreach ($subKey in $ValueMap.Keys) {
        $fullKey = if ($subKey) {
            Join-Path $baseKey $subKey
        } else {
            $baseKey
        }

        if (-not (Test-Path $fullKey)) {
            throw ('Printer {0} not found in registry.' -f $PrinterName)
        }

        $regKey = Get-Item $fullKey

        foreach ($valueName in $ValueMap[$subKey]) {
            try {
                $kind = $regKey.GetValueKind($valueName)
                $data = $regKey.GetValue($valueName, $null, 'DoNotExpandEnvironmentNames')

                if ($null -eq $data) { continue }

                $serialized =
                    if ($kind -eq 'Binary') {
                        '<BINARY_DATA_REDACTED>'
                    }
                    else {
                        $data
                    }

                [pscustomobject]@{
                    SubKey = $subKey
                    Name   = $valueName
                    Kind   = $kind
                    Data   = $serialized
                }
            }
            catch {
                # Intentionally ignored
            }
        }
    }

    $result | ConvertTo-Json -Depth 4 | Set-Content -Path $FilePath -Encoding UTF8
}