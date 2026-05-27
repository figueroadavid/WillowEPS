@{
    RootModule        = 'WillowEPS.psm1'
    ModuleVersion     = '0.0.1'
    GUID              = '804c6250-2448-4a1e-b1b9-bcb4fee64a43'

    Author            = 'David R. Figueroa II'
    CompanyName       = 'Organization'
    Copyright         = '(c) 2026 Author. All rights reserved.'
    Description       = 'Manages print servers, including printer creation and configuration.'

    RequiredModules   = @(
        'PrintManagement'
    )

    FunctionsToExport = @(
		'Add-WEPSDriverConfig',
		'Add-WEPSPrinter',
		'Add-WEPSPrinterPort',
		'Confirm-WEPSPrinterPort',
		'Connect-WEPSPrinterWebPage',
		'Convert-WEPSDriverVersion',
		'Export-WEPSPrinterConfigData',
		'Export-WEPSXeroxConfig',
		'Get-WEPSDriverConfig',
		'Import-WEPSXeroxConfig',
		'Publish-WEPSConfig',
		'Remove-WEPSDriverConfig',
		'Remove-WEPSPrinter',
		'Remove-WEPSPrinterPort',
		'Set-WEPSPrinterConfig',
		'Show-WEPSDashboard',
		'Show-WEPSStatus',
		'Test-Port',
		'Update-WEPSDriverConfig',
		'Update-WEPSModuleDriverConfigInfo'

    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags = @('printing', 'module', 'admin', 'audit')
            LicenseUri = ''
            ProjectUri = ''
            IconUri = ''
            ReleaseNotes = 'v0.0.1: Initial release with audit logging and configuration management functionality'
        }
    }
}