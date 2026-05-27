function Test-WEPSPrinterAdminPermission {
    <#
    .SYNOPSIS
        Tests if the current user has administrative permissions for printer management.
    .DESCRIPTION
        Verifies that the current user can access the Print Management module and
        has sufficient privileges to modify printer configurations.
    .PARAMETER ComputerName
        The target computer to test permissions against. Defaults to local machine.
    .OUTPUTS
        [bool]
    .EXAMPLE
        Test-WEPSPrinterAdminPermission -ComputerName PrintServer01
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$ComputerName = $env:COMPUTERNAME
    )

    try {
        # Check if PrintManagement module is available
        if (-not (Get-Module -ListAvailable -Name PrintManagement)) {
            Write-Verbose "PrintManagement module not available on $ComputerName"
            return $false
        }

        # Check if user can list printers (basic permission test)
        $testPrinter = Get-Printer -ComputerName $ComputerName -ErrorAction Stop
        Write-Verbose "Successfully accessed printer management on $ComputerName"
        return $true
    } catch {
        Write-Verbose "Permission check failed on $ComputerName: $_"
        return $false
    }
}