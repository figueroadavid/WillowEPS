# Test-Port

## Synopsis
Tests whether a TCP port is reachable on a specified computer and returns a Boolean result.

## Description
`Test-Port` tests connectivity to a specified TCP port on a target computer name or IP address.

The function uses `[Net.Sockets.TcpClient]` and an asynchronous connection attempt so that a custom timeout can be applied. If the connection completes within the timeout, the function returns `$true`. If the connection times out or fails, the function returns `$false`.

By default, the function tests TCP port `9100`, which is commonly used for raw TCP printing.

## Parameters

### -ComputerName
Specifies the resolvable computer name or IP address to test.

- Type: String
- Required: Yes
- Accepts pipeline input: ByPropertyName

### -TCPPort
Specifies the TCP port to test.

The default value is `9100`.

- Type: Int32
- Required: No
- Default: 9100
- Accepts pipeline input: ByPropertyName
- Valid range: 0 through 65535

### -TimeOutInSeconds
Specifies how long the function waits for the TCP connection attempt before returning `$false`.

- Type: Int32
- Required: No
- Default: 3
- Accepts pipeline input: ByPropertyName

## Inputs
System.String

System.Int32

You can pipe objects containing `ComputerName`, `TCPPort`, or `TimeOutInSeconds` properties to this function.

## Outputs
System.Boolean

Returns `$true` when the TCP connection succeeds within the timeout.

Returns `$false` when the connection times out or fails.

## Examples

### Example

Tests TCP port `445` on `server1`.

```powershell
Test-Port -ComputerName 'server1' -TCPPort 445
True
```

### Example

Tests TCP port `445` on `notserver1`.

```powershell
Test-Port -ComputerName 'notserver1' -TCPPort 445
False
```

### Example

Tests the default TCP port `9100`.

```powershell
Test-Port -ComputerName 'printserver01'
```

### Example

Tests TCP port `9100` with a custom timeout.

```powershell
Test-Port -ComputerName 'printserver01' -TCPPort 9100 -TimeOutInSeconds 10
```

## Notes
- The function uses `[Net.Sockets.TcpClient]` for the TCP connection test.
- The default TCP port is `9100`.
- The timeout is implemented with `AsyncWaitHandle.WaitOne()`.
- If the connection attempt exceeds the configured timeout, the function closes the TCP client and returns `$false`.
- If `EndConnect()` throws an error, the function returns `$false`.
- When verbose output is enabled, the function writes connection status messages with `Write-Verbose`.
- As written, the function only writes the Boolean result when verbose output is not enabled.
- The comment-based help example contains `-TCPPport`; the actual parameter name is `-TCPPort`.
