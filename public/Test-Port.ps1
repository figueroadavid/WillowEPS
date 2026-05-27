function Test-Port {
    <#
    .SYNOPSIS
        Tests TCP ports and returns a True/False result (boolean)
    .DESCRIPTION
        Uses a TCP net connection client specifying a timeout to allow the user to test specific ports, and
        to specify a timeout.
    .EXAMPLE
        PS C:\> Test-Port -ComputerName server1 -TCPPort 445
        True

    .EXAMPLE
        PS C:\> Test-Port -ComputerName notserver1 -TCPPport 445
        False

    .PARAMETER ComputerName
        The resolvable name (or IP Address) to run the test against

    .PARAMETER TCPPort
        The TCP port to test; it is defaulted to 9100 (standard TCP printing)

    .PARAMETER TimeOutInSeconds
        This is the timeout that the command will wait for a response before returing a $false result

    .INPUTS
        [string]
        [int]

    .OUTPUTS
        [bool]

    .NOTES
        I wrote this because the existing Test-Connection and Test-NetConnection do not offer timeouts.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$ComputerName,

        [parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(0,65535)]
        [int]$TCPPort = 9100,

        [parameter(ValueFromPipelineByPropertyName = $true)]
        [int]$TimeOutInSeconds = 3
    )

    $TCPClient = [Net.Sockets.TcpClient]::new()
    $TimeOutTimeSpan = New-TimeSpan -Seconds $TimeOutInSeconds
    $Connection = $TCPClient.BeginConnect($ComputerName, $TCPPort, $null, $null)
    $ConnectionWait = $Connection.AsyncWaitHandle.WaitOne($TimeOutTimeSpan)
    if (!$ConnectionWait)
    {
        $TCPClient.Close()
        Write-Verbose -Message ('Connection Timeout to {0} on port {1}' -f $ComputerName, $TCPPort)
        $ValidConnection = $false
    }
    else
    {
        $Error.Clear()
        try {
            $null = $TCPClient.EndConnect($Connection)
            $ValidConnection = $true
        }
        catch {
            Write-Verbose -Message ('Error detected:{0}' -f $Error[0])
            $ValidConnection = $false
        }

        $TCPClient.Close()
    }
    if ($VerbosePreference -eq 'Continue') {
        if ($ValidConnection) {
            $Message = 'TCP Port {0} is open on {1}' -f $TCPPort, $ComputerName
        }
        else {
            $Message = 'TCP Port {0} is not open on {1}' -f $TCPPort, $ComputerName
        }
        Write-Verbose -Message $Message
    }
    else {
        $ValidConnection
    }
}
