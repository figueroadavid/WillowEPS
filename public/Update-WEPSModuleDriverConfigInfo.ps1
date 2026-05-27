function Update-WEPSModuleDriverConfigInfo {
    <#
    .SYNOPSIS
        Updates the DriverConfig.json file used by the WillowEPS module.
    .DESCRIPTION
        This function scans the installed printer drivers on the local machine and updates the DriverConfig.json file
        with the latest driver information, including driver names, versions, and associated DAT file paths.
    .EXAMPLE
        Update-WEPSModuleDriverConfigInfo
    .NOTES
    #>
    $Script:DriverConfigData = Get-Content -Path $script:DriverConfigInfoPath -Raw | ConvertFrom-Json
}
