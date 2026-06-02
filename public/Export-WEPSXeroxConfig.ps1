function Export-WEPSXeroxConfig {
    <#
    .SYNOPSIS
        Exports a subset of registry values for a given printer.

    .DESCRIPTION
        Exports a defined allow-list of registry values for a printer driver
        configuration into a JSON file. This output can be used to replicate
        configuration settings using a companion import function.

        The exported data is written to a JSON file and may include values
        of type REG_BINARY. Binary values are intentionally replaced with
        placeholder text ('<BINARY_DATA_REDACTED>') instead of being serialized.

        This function is primarily designed for use with the Xerox Global Print Driver
        (PCL6), v5591.900.0.0 particularly for capturing configuration elements such as stapling
        and tray mappings that are stored in registry-backed structures.

        The function targets the following registry paths:
            HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers\<PrinterName>\
            HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers\<PrinterName>\DSDriver\
            HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers\<PrinterName>\PrinterDriverData\

        Only specific allow-listed values are exported.

        The script has not been tested with non-Xerox drivers, and behavior with other drivers
        or other driver versions is not guaranteed.

    .PARAMETER PrinterName
        The name of the printer to export configuration from.
        This must match a valid printer installed on the system.

    .PARAMETER FilePath
        The output file path for the JSON export.
        If the file extension is not '.json', it will be automatically appended.

    .PARAMETER Force
        Overwrites the destination file if it already exists.
        If not specified and the file exists, the operation will be skipped.

    .NOTES
        Designed primarily for Xerox Global Print Driver (PCL6) environments.

        This function was originally created to capture registry-backed configuration
        for Xerox printer features (such as stapling) that are not easily replicated
        through standard PrintUI or GPO methods.

        Behavior outside of Xerox GPD (e.g., other vendors or driver versions)
        is not guaranteed and should be validated before use.

        Binary registry values are not exported directly to avoid JSON serialization issues.

    .EXAMPLE
        Export-WEPSXeroxConfig -PrinterName "PRN-01" -FilePath "C:\Temp\PRN-01.json"

        Exports the Xerox-specific registry configuration for printer PRN-01
        into C:\Temp\PRN-01.json.

    .EXAMPLE
        Export-WEPSXeroxConfig -PrinterName "PRN-02" -FilePath "C:\Temp\PRN-02" -Verbose

        Exports the configuration for PRN-02 and automatically appends ".json"
        to the output file name (resulting in PRN-02.json).

    .EXAMPLE
        Export-WEPSXeroxConfig -PrinterName "PRN-03" -FilePath "C:\Temp\PRN-03.json" -Force

        Overwrites the existing export file for PRN-03 without prompting.

    .EXAMPLE
        Get-Printer -Name "PRN-*" | ForEach-Object {
            Export-WEPSXeroxConfig -PrinterName $_.Name -FilePath ("C:\Temp\{0}.json" -f $_.Name)
        }

        Iterates over multiple printers and exports each configuration to a separate JSON file.
        This function processes one printer per invocation and does not support bulk export natively.
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
                        [Convert]::ToBase64String($data)
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