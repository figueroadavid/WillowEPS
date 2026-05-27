function Export-WEPSPrinterConfigData {

    [CmdletBinding()]    
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$PrinterName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$FileName = (Convert-ToValidFileName -Text $PrinterName -Extension '.dat')
    )

    # --- Resolve file path (DO NOT pre-quote) ---
    $ResolvedFileName = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($FileName)

    # --- Validate printer exists first ---
    try {
        $printer = Get-Printer -Name $PrinterName -ErrorAction Stop
    }
    catch {
        throw "Printer '$PrinterName' not found. Cannot export configuration."
    }

    $DriverName = $printer.DriverName

    # --- Build rundll32 path (no Join-Path) ---
    $rundllPath = [System.IO.Path]::Combine($env:SystemRoot, 'System32', 'rundll32.exe')

    # --- Build argument string (quote only here) ---
    $ArgString = 'printui.dll,PrintUIEntry /Ss /n "{0}" /a "{1}" g u' -f $PrinterName, $ResolvedFileName

    $ProcStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $ProcStartInfo.FileName               = $rundllPath
    $ProcStartInfo.Arguments              = $ArgString
    $ProcStartInfo.UseShellExecute        = $false
    $ProcStartInfo.RedirectStandardOutput = $true
    $ProcStartInfo.RedirectStandardError  = $true
    $ProcStartInfo.CreateNoWindow         = $true
    $ProcStartInfo.Verb                   = 'RunAs'

    $Process = [System.Diagnostics.Process]::new()
    $Process.StartInfo = $ProcStartInfo

    $null = $Process.Start()
    $Process.WaitForExit()

    if ($Process.ExitCode -ne 0) {
        $errorText = $Process.StandardError.ReadToEnd()
        if (-not $errorText) {
            $errorText = 'No additional error output returned.'
        }

        Write-Error "Failed to export print driver data for printer '$PrinterName'. ExitCode=$($Process.ExitCode). $errorText"
        return
    }

    Write-Verbose ('Successfully exported print driver data for printer "{0}" to file "{1}" using driver "{2}".' -f $PrinterName, $ResolvedFileName, $DriverName)

    "Successfully exported print driver data for printer '{0}' to file '{1}'; using driver '{2}'." -f $PrinterName, $ResolvedFileName, $DriverName
}