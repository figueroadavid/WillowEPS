function New-WEPSDatFile {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [string]$PrinterName,

        [parameter()]
        [string]$FilePath,

        [parameter()]
        [switch]$Force
    )

    begin {
        if (Test-Path -LiteralPath $FilePath -and -not $PSBoundParameters.ContainsKey('Force')) {
            throw ('The output file ({0}) already exists, and -Force not specified, unable to continue' -f $FilePath)
        }

        $thisDriverName = (Get-Printer -Name $PrinterName).drivername
        $thisDriver = Get-PrinterDriver -Name $thisDriverName

        if (-not $thisDriver) {
            throw ('There was an issue trying to retrieve the driver for {0}; unable to continue' -f $PrinterName)
        }
    }

    process {
        $thisDriver = $AllDrivers | Where-Object Name -eq $DriverName
        $thisDriverVersion = $thisDriver.version
        $thisDriverVersionString = ConvertFrom-DriverVersion -Version $thisDriverVersion
        if ($PSBoundParameters.Keys -notcontains 'FilePath') {
            $NewFileName = '{0}_{1}.dat' -f ($thisDriver.Name -split ' ')[0], $thisDriverVersionString.Version.ToString()
            $FilePath = [System.IO.Path]::Combine($script:CacheDataDir, $NewFileName)
        }
       
        if (([System.IO.FileInfo]$FilePath).Extension -ne '.dat') {
            $newFilePath = $FilePath = [System.IO.Path]::ChangeExtension($FilePath, '.dat')
            Write-Warning -Message ('File ({0}) will be renamed to ({1})' -f $FilePath, $newFilePath)
            $FilePath = $newFilePath
        }
    }
}