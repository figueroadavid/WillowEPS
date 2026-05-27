#Requires -Module PrintManagement
#Requires -RunAsAdministrator

# --- Global Variables & Paths ---
$script:ModuleSourcePath        = '<SOURCE_PATH>'
$script:ModuleBase              = $PSScriptRoot
$script:ModuleHelpDir           = [System.IO.Path]::Combine($script:ModuleBase, 'Help')
$script:SourceDataDir           = [System.IO.Path]::Combine($script:ModuleSourcePath, 'Data')
$script:SourceHelpDir           = [System.IO.Path]::Combine($script:ModuleSourcePath, 'Help')

$script:CRLF                    = [System.Environment]::NewLine
$script:PrivateDirectory        = [System.IO.Path]::Combine($script:ModuleBase, 'Private')
$script:PublicDirectory         = [System.IO.Path]::Combine($script:ModuleBase, 'Public')
$script:DataDir                 = [System.IO.Path]::Combine($script:ModuleBase, 'Data')

$script:CacheRoot               = [System.IO.Path]::Combine($env:ProgramData, 'PrintModule')
$script:CacheBase               = [System.IO.Path]::Combine($script:CacheRoot, 'Cache')
$script:CacheDataDir            = [System.IO.Path]::Combine($script:CacheBase, 'Data')
$script:CacheHelpDir            = [System.IO.Path]::Combine($script:CacheBase, 'Help')
$script:DriverConfigInfo        = [System.IO.Path]::Combine($script:CacheDataDir, 'DriverConfigInfo.json')
$script:DriverConfigInfoPath    = [System.IO.Path]::Combine($script:DataDir, 'DriverConfigInfo.json')

$script:TargetServers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$script:TargetEnvironments = $null

# --- Initialization ---
function Initialize-Module {
    Write-Verbose "Initializing PrintModule Module..."
    
    # Ensure Cache Directories Exist
    New-WEPSDirectory -Path $script:CacheDataDir
    New-WEPSDirectory -Path $script:CacheHelpDir
    New-WEPSDirectory -Path $script:CacheRoot

    # Load Source Data (if available)
    if (Test-Path -LiteralPath $script:DriverConfigInfoPath) {
        try {
            $raw = Get-Content -LiteralPath $script:DriverConfigInfoPath -Raw -ErrorAction Stop
            $script:DriverConfigInfo = $raw | ConvertFrom-Json -ErrorAction Stop
            
            # Normalize structure (ensure Drivers array exists)
            if (-not $script:DriverConfigInfo.PSObject.Properties.Name -contains 'Drivers') {
                $script:DriverConfigInfo = [PSCustomObject]@{
                    Metadata = $null
                    Drivers = $script:DriverConfigInfo
                }
            }
        } catch {
            throw "Module: Failed to load source driver config. $_"
        }
    } else {
        Write-Warning "Module: Source config not found. Using empty cache."
        $script:DriverConfigInfo = [PSCustomObject]@{ Metadata = $null; Drivers = @() }
    }

    # Load Server List
    $script:ServerListDataPath = [System.IO.Path]::Combine($script:DataDir, 'ServerList.json')
    if (Test-Path -LiteralPath $script:ServerListDataPath) {
        try {
            $raw = Get-Content -LiteralPath $script:ServerListDataPath -Raw -ErrorAction Stop
            $script:ServerListData = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Module: Failed to load server list. $_"
        }
		
		if ($script:ServerListData) {
			$script:AvailableEnvironments = @($script:ServerListData.PSObject.Properties.Name | Sort-Object)
		}
    }

    # Initialize Audit Log
    Initialize-ModuleAuditLog

    # Perform Cache Sync (Pull)
    # Perform Cache Sync (Pull)
    $syncParams = @{
        DriverConfigInfo    = $script:DriverConfigInfo.Drivers
        CacheDataDir        = $script:CacheDataDir
        CacheHelpDir        = $script:CacheHelpDir
        SourceDataDir       = $script:SourceDataDir
        SourceHelpDir       = $script:SourceHelpDir
        ModuleDataDir       = $script:DataDir
        ModuleHelpDir       = $script:ModuleHelpDir
        Force               = $false
    }
    
    $syncResult = Update-WEPSCache @syncParams
    
    if ($syncResult.PullPerformed) {
        Write-Verbose "Cache synchronized. Source changed: $($syncResult.SourceChanged)"
    } else {
        Write-Verbose "Cache is current."
    }

    # Register Argument Completers
    Register-ArgumentCompleter -CommandName 'Add-WEPSDriverConfig','Remove-WEPSDriverConfig','Update-WEPSDriverConfig' -ParameterName 'DriverName' -ScriptBlock $DriverNameCompleter
    Register-ArgumentCompleter -CommandName 'Add-WEPSPrinter','Export-WEPSPrinterConfigData','Remove-WEPSPrinter','Set-WEPSPrinterConfig' -ParameterName 'PrinterName' -ScriptBlock $PrinterNameCompleter
    Register-ArgumentCompleter -CommandName 'Add-WEPSPrinter','Add-WEPSPrinterPort','Remove-WEPSPrinter','Remove-WEPSPrinterPort' -ParameterName 'Environments' -ScriptBlock $EnvironmentNameCompleter

	# --- Argument Completers (Inline for brevity) ---
	$DriverNameCompleter = {
		param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
		# Refresh cache if needed
		$drivers = $script:DriverConfigInfo.Drivers.Name
		$drivers | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
			[System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
		}
	}

	$PrinterNameCompleter = {
		param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
		try {
			$printers = Get-Printer -ErrorAction Stop
			$printers | Where-Object { [string]::IsNullOrEmpty($wordToComplete) -or $_.Name -like "*$wordToComplete*" } | Sort-Object Name | ForEach-Object {
				[System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Name)
			}
		} catch { @() }
	}
	
	$EnvironmentNameCompleter = {
		param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

		$environments = @($script:AvailableEnvironments)

		$environments | Where-Object { [string]::IsNullOrEmpty($wordToComplete) -or $_ -like "$wordToComplete*" } |
			ForEach-Object {
				[System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
			}
	}
	

# --- Import Functions ---
Get-ChildItem -Path $script:PrivateDirectory -File -Filter *.ps1 | 
	Where-Object FullName -notmatch '\.tests\.ps1$' | 
	ForEach-Object { . $_.FullName }
Get-ChildItem -Path $script:PublicDirectory -File -Filter *.ps1 | 
	Where-Object FullName -notmatch '\.tests\.ps1$' | 
	ForEach-Object { . $_.FullName }

# --- Run Initialization ---
Initialize-Module