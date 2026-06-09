# Get-WEPSDriverConfig

## Synopsis
Retrieves driver configuration information from the module-loaded driver configuration data.

## Description
`Get-WEPSDriverConfig` retrieves printer driver configuration entries from the driver configuration data loaded into the module.

If no name is specified, the function returns the contents of `$script:DriverConfigInfo`.

If `-Name` is specified, the function searches for matching driver entries by name. By default, matching uses wildcard-style comparison equivalent to:

    `-like "*$Name*"`

If `-UsePreciseMatching` is specified, the function escapes the provided name and performs a regular expression match against the full driver name.

The function supports pipeline input by property name for `Name` and also supports the aliases `DriverName` and `Driver`.

## Parameters

### -Name
Specifies the driver name, or part of a driver name, to retrieve from the loaded driver configuration data.

By default, the function performs a wildcard-style contains match against the `Name` property.

If omitted, the function returns all loaded driver configuration data.

- Type: String
- Required: No
- Accepts pipeline input: ByPropertyName
- Aliases: DriverName, Driver

### -UsePreciseMatching
Uses precise name matching instead of the default wildcard-style name search.

When this switch is used, the supplied name is escaped with `[regex]::Escape()` and matched as a full-string regular expression.

- Type: Switch
- Required: No
- Accepts pipeline input: ByPropertyName

## Inputs
System.String

You can pipe objects containing a `Name`, `DriverName`, or `Driver` property to this function.

## Outputs
System.Object

Returns matching driver configuration objects from `$script:DriverConfigInfo`.

The returned objects are expected to include driver configuration properties such as:

- `Name`
- `DriverVersion`
- `FilePath`

## Example
```powershell
    PS C:\>Get-WEPSDriverConfig -Name pcl -Verbose

    Name                      DriverVersion FilePath
    ----                      ------------- --------
    Generic PCL Driver      100000000000000 C:\WEPS\ConfigFiles\Driver1.dat
```

## Example
```powershell
    PS C:\> PS C:\>Get-WEPSDriverConfig -Name PCL -Verbose -UsePreciseMatching
    PS C:\>
```

## Example
```powershell
    PS C:\>Get-WEPSDriverConfig -Name 'Generic Receipt Printer Driver' -Verbose

    Name                                     DriverVersion FilePath
    ----                                     ------------- --------
    Generic Receipt Printer Driver         200000000000000 C:\WEPS\ConfigFiles\Driver2.dat
```

## Example
```powershell
    PS C:\> Get-WEPSDriverConfig -Name 'Generic PCL Driver' -Verbose -UsePreciseMatching

    Name                                     DriverVersion FilePath
    ----                                     ------------- --------
    Generic PCL Driver                     100000000000000 C:\WEPS\ConfigFiles\Driver1.dat
```

## Notes
- The function reads from `$script:DriverConfigInfo`.
- The function does not read the JSON configuration file directly.
- The function depends on driver configuration data already being loaded into the module.
- Default matching uses `Where-Object Name -like "*$Name*"`.
- Precise matching uses an escaped regular expression in the form `^{0}$`.
- Matching is performed against the `Name` property of the loaded configuration objects.
- The function does not define a `FilePath` parameter.
- As written, the `begin` block references `$FilePath`, but `$FilePath` is not declared as a parameter or local input value in the function signature.
