function Export-WEPSPrinterConfigData {
    <#
    .SYNOPSIS
        Exports print driver data for a specified printer.
    .DESCRIPTION
        Uses rundll32.exe to export print driver data for a specified printer.
        Outputs the driver name used by the printer.
    .PARAMETER PrinterName
        The name of the printer.
    .PARAMETER FileName
        The output .dat file path.
     .NOTES
        The script requires the printmanagement module to be installed and the user to have administrative privileges.
        The script specifically uses the 'd' and 'g' options in the rundll32.exe command to ensure that the both
        the machine and user-specific settings are exported.
        In the case of a Zebra printer, it is critical that the script be run as the service account used to run the print services.
    .LINK
        https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/rundll32-printui
	.EXAMPLE
        Export-WEPSPrinterConfigData -PrinterName "PRN-01" -FileName "PRN-01.dat"
    #>

    [CmdletBinding()]    
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$PrinterName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$FileName = (Convert-ToValidFileName -Text $PrinterName -Extension '.dat')
    )

    $FileName = '"{0}"' -f $PSCmdlet.GetUnresolvedProviderPathFromPSPath($FileName)

    $rundllPath = Join-Path $env:SystemRoot 'System32\rundll32.exe'

    $ProcStartinfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcStartinfo.FileName = $rundllPath
    $ProcStartinfo.Arguments = "printui.dll,PrintUIEntry /Ss /n $PrinterName /a $FileName g u"
    $ProcStartinfo.UseShellExecute = $false
    $ProcStartinfo.RedirectStandardOutput = $true
    $ProcStartinfo.RedirectStandardError = $true
    $ProcStartinfo.CreateNoWindow = $true
    $ProcStartinfo.Verb = "runas"
   
    $process = [System.Diagnostics.Process]::Start($ProcStartinfo)
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        Write-Error "Failed to export print driver data for printer '$PrinterName'. Exit code: $($process.ExitCode)"
    }
    else {
        $DriverName = (Get-Printer -Name $PrinterName).DriverName
        'Successfully exported print driver data for printer "{0}" to file {1}; using driver "{2}".' -f $PrinterName, $FileName, $DriverName
    }
}