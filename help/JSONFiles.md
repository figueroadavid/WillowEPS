# JSON Files
There are 2 major JSON files required for the WillowEPS module.

1. `ServerList.JSON` - this includes the list of environments, servers, and assigned user accounts.
2. `DriverConfigInfo.JSON` - this includes metadata about the available driver installations, configuration DAT files, etc.

## ServerList.JSON
The format of the file is this:
```JSON 
{
	"environment": {
		"Servers": [
			"server01",
			"server02"
		]
		"Account" : "accountname"
	},
	"environment2": {
		"Servers": [
			"server03",
			"server04"
		], 
		"Account" : "accountname"
	}
}
```	

Each environment name/group gets it's own section, and then has a section for the associated servers, and the associated account (if any).  

If the current user has an account listed in this JSON file, the appropriate servers for all of those environments is added to the list of servers that will be managed.  If the user account is NOT listed in the JSON file, the user is presented with a powershell menu of environments to select, and the servers for the selected environments are added. 

## DriverConfigInfo.JSON 
This file contains entries for the printer drivers, their associated versions, the associated configuration DAT files etc. 

```JSON 
{
  "Metadata": {
    "SourceHash": "1ACBC08B2543FDD891766676D98A4520B96E3C0936B89D44990F924B5700E32A",
    "SchemaVersion": "2.0",
    "ModuleVersion": "0.0.1",
    "LastModified": "2026-04-07T07:45:40.5906677-05:00",
    "ModifiedBy" :"administrator@domain.tld",
    "LastSyncedAt": "2026-04-07T07:45:40.5906677-05:00"
  },
  "Drivers": [
    {
		"Name": "Microsoft XPS Document Writer v4",
		"DriverVersion": 2814751477596161,
		"DriverVersionString": "10.0.26100.1"
		"DATFilePath": "C:\\ProgramData\\WillowEPS\\Cache\\Data\\Microsoft XPS Document Writer v4.dat"
		"SHA256": "12345"
	},
	{
		"Name": "Microsoft Virtual Print Class Driver",
		"DriverVersion": 2814751477604196,
		"DriverVersionString": "10.0.26100.8036"
		"DATFilePath": "C:\\ProgramData\\WillowEPS\\Cache\\Data\\Microsoft Virtual Print Class Driver.dat"
		"SHA256": "12345"
	},
	{
		"Name": "Microsoft Print To PDF",
		"DriverVersion": 2814751477600644,
		"DriverVersionString": "10.0.26100.4484"
		"DATFilePath": "C:\\ProgramData\\WillowEPS\\Cache\\Data\\Microsoft Print To PDF.dat"
		"SHA256": "12345"
	},
	{
		"Name": "Microsoft IPP Class Driver",
		"DriverVersion": 2814751477604196,
		"DriverVersionString": "10.0.26100.8036"
		"DATFilePath": "C:\\ProgramData\\WillowEPS\\Cache\\Data\\Microsoft IPP Class Driver.dat"
		"SHA256": "12345"
	},
	{
		"Name": "Microsoft Shared Fax Driver",
		"DriverVersion": 2814751477604196,
		"DriverVersionString": "10.0.26100.8036"
		"DATFilePath": "C:\\ProgramData\\WillowEPS\\Cache\\Data\\Microsoft Shared Fax Driver.dat"
		"SHA256": "12345"
	},
	{
		"Name": "Microsoft enhanced Point and Print compatibility driver",
		"DriverVersion": 2814751477604196,
		"DriverVersionString": "10.0.26100.8036"
		"DATFilePath": "C:\\ProgramData\\WillowEPS\\Cache\\Data\\Microsoft enhanced Point and Print compatibility driver.dat"
		"SHA256": "12345"
	}
  ]
}
```

The JSON file contains a _Metadata_ section used to validate the cache structure on the computer, and the _Drivers_ section that contains all the relevant information for storing and applying driver config files created with `rundll32.exe`. 

The _Metadata_ section contains this information:
* `SourceHash` - this is the SHA256 hash of the DriverConfigInfo.JSON itself as it was just before computing the hash itself, since a file cannot contain a hash of itself.  
* `SchemaVersion` - this is the version of the schema for the file.  It is simply a human readable reference.
* `ModuleVersion` - this is the version of the WillowEPS module 
* `LastModified` - this is a timestamp of the last time the file was changed through the scripts.  It uses the `Get-Date -format 'o'` command to generate the timestamp.
* `ModifiedBy` - this is the account name of the person modifying the file using the scripts.  It uses $env:USERNAME @ $env:USERDNSDOMAIN as the _stamp_.
* `LastSyncedAt` - this is the time stamp of the last time the cache was updated by the user.  When the module is imported, the scripts validate the SHA256 stamp above (SourceHash) and if the local SourceHash is not the same as the copy in the central store, the cache is recopied. It also uses the `Get-Date -format 'o'` to generate the timestamp.

Each driver section contains:
* `Name` - the name of the driver as it is installed on the computer.
* `DriverVersion` - this is the version of the driver as reported by the `Get-PrinterDriver` function
* `DriverVersionString` - this is the human readable driver version
* `DATFilePath` - this is to the _cached_ local copy of the DAT file containing the configuration information (DEVMODE data).
* `SHA256` - this is the SHA256 hash of the DATFile listed above.  This helps confirm the DAT file is the original file. This is _NOT_ a security measure, it is a file integrity measure. 