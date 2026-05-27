# Add-WEPSDriverConfig 

This script will add a new driver configuration file to the DriverConfigInfo.JSON included with the module.
It requires that the following information is provided:
* `DriverName` - the name of the driver as it is installed on the server. 
* `DatFilePath` - the path to the DAT file extracted from a printer using this driver. 
* `PushToSource` - if this configuration is to be added to the central store for the module, this switch enables that functionality, and updates the central copy of DriverConfigInfo.JSON and copies the DAT file up to the central store.

