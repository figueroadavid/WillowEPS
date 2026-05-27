# Willow EPS

This module is designed to support managing Willow EPS servers.  The majority of the functionality can also be used to support normal EPS servers, but that was not the intent of the module.

There are 2 major "workflows" to the module.
1. The day to day operations
2. Managing and updating the cache information

## Day to Day functions
These are the functions that are used for normal day to day operations

| Function | Purpose |
| :--- | :--- |
| `Add-WEPSPrinter` | Adds a new printer to the list of EPS servers stored in the ServerList.JSON file |
| `Add-WEPSPrinterPort` | Adds a new Windows printer port to the list of EPS servers stored in the ServerList.JSON file; it is normally called automatically by Add-WEPSPrinter |
| `Confirm-WEPSPrinterPort` | Used by the `Add-WEPSPrinterPort` function to determine of a printer port needs to be created |
| `Remove-WEPSPrinter` | Removes a printer from the list of EPS servers stored in the ServerList.JSON file |
| `Remove-WEPSPrinterPort` | Removes a printer port from the list of EPS servers stored in the ServerList.JSON file; it is normally called automatically by the Remove-WEPSPrinter function |
| `Set-WEPSPrinterConfig` | Applies a DAT file to a given printer to set the proper configuration |


## Cache information functions
These functions are used to manage the information in the cache, and the reference files used by the module.  

| Function | Purpose |
| :---     | :---    |
| `Add-WEPSDriverConfig` | Adds a new driver configuration to the DriverConfigInfo.JSON file |
| `Convert-WEPSDriverVersion` | This takes a driver value from `Get-Printer` and creates a pscustomobject with the version as an actual [version] object and a string representation |
| `Export-WEPSPrinterConfigData` | This uses the `rundll32.exe` utility to extract the configuration data at the machine level, and at the user level (DEVMODE data) and saves it to a file |
| `Get-WEPSDriverConfig` | This retrieves a DriverConfigInfo object from the DriverConfigInfo.JSON file|
| `Publish-WEPSConfig` | This allows the user to update the DriverConfigInfo.JSON file at the source, in addition to the locally cached version|
| `Remove-WEPSDriverConfig` | This removes a DriverConfigInfo object from the DriverConfigInfo.JSON file|
| `Update-WEPSDriverConfig` | This modified an existing DriverConfigInfo object in the DriverConfigInfo.JSON file |
| `Update-WEPSModuleDriverConfigInfo` | This updates the in-memory DriverConfigInfo variable by rereading the DriverConfigInfo.JSON file |

## Miscellaneous Functions 
| Function | Purpose |
| :---     | :---    |
| `Show-WEPSDashboard` | [Experimental] shows a Winforms GUI for the scripts |
| `Show-WEPSStatus` | [Experimental] This shows a toaster message indicating the Active or Passive status for the server |
| `Test-Port` | A general script to test if a given TCP port is responding to connection attempts |

There are numerous private functions in the module also. These are generally never directly used by the administrator.
* `Add-MenuHotKey`
* `Copy-WEPSFileAtomic`
* `Get-WEPSSHA256`
* `Intialize-WEPSAuditLog`
* `New-WEPSDatFile`
* `New-WEPSDirectory`
* `New-WEPSTargetServerMenu`
* `Show-WEPSProgress`
* `Test-WEPSPrinterAdminPermission`
* `Test-WEPSSourceIntegrity`
* `Update-WEPSCache`
* `Write-WEPSAuditLog`

## Workflows 

### Day to Day Workflow major steps
1. Add a new printer (`Add-WEPSPrinter`)
2. Apply the correct configuration to the new printer (`Set-WEPSPrinterConfig`)

### Periodic workflow major steps
1. Remove a printer (`Remove-WEPSPrinter`)
2. Creating a new DAT file for the driver from step 2 or 3. (`Export-WEPSPrinterConfigData`)
3. Look at the existing driver configuration data (`Get-WEPSDriverConfig`)

### Rare item & Cache maintenance steps 
These are rarely needed, but are used to manage the cache information for the local machine, and the original source.
1. Add/Update a printer driver (`Add-PrinterDriver`)
2. Create a new DAT file for an added/updated/modified driver (`Export-WEPSPrinterConfigData`)
3. Add the new driver information to the DriverConfigInfo.JSON (`Add-WEPSDriverConfig`)
4. Remove a driver configuration (`Remove-WEPSDriverConfig`)

