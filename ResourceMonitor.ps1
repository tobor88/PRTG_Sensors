param (
    [string]$Device
) # End param

If ($Device -like '<YOUR PRTG SERVER HOSTNAME GOES HERE>')
{

    $OS = Get-CimInstance -ClassName "Win32_OperatingSystem" -ComputerName "$Device"

    $CPUs = Get-CimInstance -ClassName "Win32_Processor" -ComputerName "$Device"

    $Disks = Get-CimInstance -ClassName "Win32_LogicalDisk" -ComputerName "$Device" | Where-Object -Property 'DriveType' -eq 3 

} # End if

Else
{

    $CimSessionOptions = New-CimSessionOption -UseSsl # -SkipRevocationCheck -SkipCACheck -SkipCNCheck # Uncomment these if the EXE script is failing to run as one of these options may be the issue.

    $CIMSession = New-CimSession -ComputerName $Device -SessionOption $CimSessionOptions

    $OS = Get-CimInstance -CimSession $CIMSession -ClassName "Win32_OperatingSystem"

    $CPUs = Get-CimInstance -CimSession $CIMSession -ClassName  "Win32_Processor"

    $Disks = Get-CimInstance -CimSession $CIMSession -ClassName  "Win32_LogicalDisk" | Where-Object -Property 'DriveType' -eq 3 

} # End Else

ForEach ($CPU in $CPUs)
{

    [int]$CPUsTotal += 1

    $XmlCPUs += "<Result><Channel>CPU Load #$CPUsTotal</Channel><Value>" + $CPU.LoadPercentage + "</Value><Unit>Percent</Unit><LimitWarningMsg>WARNING: CPU is at or above 85% capacity</LimitWarningMsg><LimitErrorMsg>CRITICAL: CPU is at or above 95% capacity</LimitErrorMsg><LimitMaxError>95.00</LimitMaxError><LimitMaxWarning>85.00</LimitMaxWarning><LimitMode>1</LimitMode></Result>"

} # End ForEach

# Hard Disks
ForEach ($Disk in $Disks)
{

    $TotalDriveSpace = ($Disk.Size)

    $FreeDriveSpace = ($Disk.FreeSpace)

    $DrivePercentageFree = [math]::Round(($Disk.FreeSpace/$Disk.Size)*100,2).ToString("###")

    [int]$DisksTotal += 1

    $XmlDisks += "<Result><Channel>Total Space Drive " + $Disk.DeviceID + "</Channel><Value>" + $TotalDriveSpace + "</Value><VolumeSize>GigaByte</VolumeSize></Result>"

    $XmlDisks += "<Result><Channel>Free Space Drive " + $Disk.DeviceID + "</Channel><Value>" + $FreeDriveSpace + "</Value><VolumeSize>GigaByte</VolumeSize></Result>"

    $XmlDisks += "<Result><Channel>Percentage Free on Drive " + $Disk.DeviceID + "</Channel><Value>" + $DrivePercentageFree + "</Value><Unit>Percent</Unit><LimitWarningMsg>WARNING: Disk Space Free is at or below 15% capacity</LimitWarningMsg><LimitErrorMsg>CRITICAL: Available Disk space is at or has fallen below 10% availability</LimitErrorMsg><LimitMinError>10.00</LimitMinError><LimitMinWarning>15.00</LimitMinWarning><LimitMode>1</LimitMode></Result>"

} # End ForEach

$TotalMemory = ($OS.TotalVisibleMemorySize * 1KB)

#$MemoryFree = [math]::Round($OS.FreeVirtualMemory / 1MB, 3)

#$MemoryInUse = [math]::Round(($OS.TotalVisibleMemorySize - $OS.FreeVirtualMemory) / 1MB, 3)

$MemoryFreePercentage = [math]::Round(($OS.FreePhysicalMemory/$OS.TotalVisibleMemorySize)*100,2)

$MemoryInUsePercentage = [math]::Round(100-(($OS.FreePhysicalMemory/$OS.TotalVisibleMemorySize)*100),2)

<# The below can be added to the XML variable if Total CPUs is a wanted option.
        <Result>
            <Channel>Total CPUs</Channel>
            <Value>" + $CPUsTotal + "</Value>
            <Unit>Count</Unit>
        </Result>


# Below this line can be added to XML to add a total disk count to output
The fewer xml results the better the chance they dont get convoluted during data transfer to prtg which is finicky
PRTG claims a max of 50 results but they do not gurantee their success.

        <Result>
            <Channel>Total Disks</Channel>
            <Value>" + $DisksTotal + "</Value>
            <Unit>Count</Unit>
        </Result>

Below this line is for switching out or adding memory in Gigabytes
        <Result>
            <Channel>Memory Free</Channel>
            <Value>" + $MemoryFree + "</Value>
            <VolumeSize>GigaByte</VolumeSize>
            <Float>1</Float>
        </Result>
        <Result>
            <Channel>Memory In Use</Channel>
            <Value>" + $MemoryInUse + "</Value>
            <VolumeSize>GigaByte</VolumeSize>
            <Float>1</Float>
        </Result>
#>

$Xml="<PRTG>
        $XmlCPUs
        $XmlDisks
        <Result>
            <Channel>Total Memory</Channel>
            <Value>" + $TotalMemory + "</Value>
            <VolumeSize>GigaByte</VolumeSize>
        </Result>
        <Result>
            <Channel>Memory Free Percentage</Channel>
            <Value>" + $MemoryFreePercentage + "</Value>
            <Float>1</Float>
            <Unit>Percent</Unit>
        </Result>
        <Result>
            <Channel>Memory In Use Percentage</Channel>
            <Value>" + $MemoryInUsePercentage + "</Value>
            <Float>1</Float>
            <Unit>Percent</Unit>
            <LimitWarningMsg>WARNING: CPU is at or above 85% capacity</LimitWarningMsg>
            <LimitErrorMsg>CRITICAL: CPU is at or above 95% capacity</LimitErrorMsg>
            <LimitMaxError>95.00</LimitMaxError>
            <LimitMaxWarning>85.00</LimitMaxWarning>
            <LimitMode>1</LimitMode>
        </Result>
    </PRTG>
    "

    Function Write-Xml ([xml]$Xml)
    {
        # Making XML Human Readable
        $StringWriter = New-Object System.IO.StringWriter;

        $XmlWriter = New-Object System.Xml.XmlTextWriter $StringWriter;

        $XmlWriter.Formatting = "indented";

        $Xml.WriteTo($XmlWriter);

        $XmlWriter.Flush();

        $StringWriter.Flush();

        Write-Output $StringWriter.ToString();

    } # End Function Write-Xml

    Write-Xml "$Xml"
