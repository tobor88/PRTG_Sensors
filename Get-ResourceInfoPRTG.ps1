#Requires -Version 3.0
#Requires -PSEdition Desktop
<#
.SYNOPSIS
This script is a custom PRTG sensor. It can be used to return information for a devices Disk, Processor/CPU, and Memory information


.DESCRIPTION
This script returns information for a devices disk, memory and processor/CPU and uses the defined threshold values to create PRTG notifications for each result


.PARAMETER ComputerName
Specifies the name of the computer to which to create the CIM session. Specify either a single computer name, or multiple computer names separated by a comma.

If ComputerName is not specified, a CIM session to the local computer is created.

You can specify the value for computer name in one of the following formats:

- One or more NetBIOS names

- One or more IP addresses

- One or more fully qualified domain names.


If the computer is in a different domain than the user, you must specify the fully qualified domain name.
You can also pass a computer name (in quotes) to `New-CimSession` by using the pipeline.

.PARAMETER ResourceMonitors
Specify all of the resource monitors you wish to monitor with this sensor separating multiple values with a comma

.PARAMETER LowDiskSpaceWarningThreshold
Define the Warning Threshold for your Low Disk Space monitor

.PARAMETER LowDiskSpaceCriticalThreshold
Define the Critical Threshold for your Low Disk Space monitor

.PARAMETER CpuUsageWarningThreshold
Define the Warning Threshold for your CPU Utilization monitor

.PARAMETER CpuUsageCriticalThreshold
Define the Critical Threshold for your CPU Utilization monitor

.PARAMETER MemoryWarningThreshold
Define the Warning Threshold for your Memory Usage monitor

.PARAMETER MemoryCriticalThreshold
Define the Critical Threshold for your Memory Usage monitor

.PARAMETER UseSSL
Specify the use of WinRM over HTTPS (port 5986) to build CIM sessions instead of WinRM (port 5985)

.PARAMETER SkipCACheck
Indicates that when connecting over HTTPS, the client does not validate that the server certificate is signed by a trusted certification authority (CA).

Use this parameter only when the remote computer is trusted using another mechanism, such as when the remote computer is part of a network that is physically secure and isolated, or when the remote computer is listed as a trusted host  
in a WinRM configuration.

.PARAMETER SkipCNCheck
Indicates that the certificate common name (CN) of the server does not need to match the hostname of the server.

Use this parameter only for remote operations that use the HTTPS protocol.

Note: use this parameter only for trusted computers.

.PARAMETER SkipRevocationCheck
Indicates that the revocation check for server certificates is skipped.

Note: use this parameter only for trusted computers.


.NOTES
Author: Robert H. Osborne
Alias: tobor
Contact: info@osbornepro.com


.LINK
https://www.paessler.com/prtg
https://www.paessler.com/manuals/prtg/custom_sensors
https://osbornepro.com
https://writeups.osbornepro.com
https://btpssecpack.osbornepro.com
https://github.com/tobor88
https://gitlab.com/tobor88
https://www.powershellgallery.com/profiles/tobor
https://www.linkedin.com/in/roberthosborne/
https://www.credly.com/users/roberthosborne/badges
https://www.hackthebox.eu/profile/52286


.INPUTS
System.String


.OUTPUTS
System.String
#>
[OutputType([System.String])]
[CmdletBinding(DefaultParameterSetName="WinRM")]
param (
    [Parameter(
        Position=0,
        Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipeLineByPropertyName=$False,
        HelpMessage="[H] Enter the name of the device you are reaching out too `n[E] EXAMPLE: servername.domainname.com "
    )]  # End Parameter
    [Alias("Device","Server")] # <---- The value 'Device' is required for PRTG to pass variable to cmdlet. Using -ComputerName is considered a best practice
    [String]$ComputerName,

    [Parameter(
        Mandatory=$False,
        ValueFromPipeline=$False,
        ValueFromPipeLineByPropertyName=$False
    )]  # End Parameter
    # OPTIONS: "CPULoad", "CPUCount", "DiskFreePercentage", "DiskFreeGigabytes", "TotalDisks", "MemoryFreePercentage", "MemoryFreeGigaByte"
    [String[]]$ResourceMonitors = @("CPULoad", "CPUCount", "DiskFreePercentage", "DiskFreeGigabytes", "TotalDisks", "MemoryFreePercentage", "MemoryFreeGigaByte"),

    [Parameter(
        Mandatory=$False,
        ValueFromPipeline=$False,
        ValueFromPipeLineByPropertyName=$False
    )]  # End Parameter
    [ValidateRange(1,100)]
    [Int]$LowDiskSpaceWarningThreshold = 80,

    [Parameter(
        Mandatory=$False,
        ValueFromPipeline=$False,
        ValueFromPipeLineByPropertyName=$False
    )]  # End Parameter
    [ValidateRange(1,100)]
    [Int]$LowDiskSpaceCriticalThreshold = 90,

    [Parameter(
        Mandatory=$False,
        ValueFromPipeline=$False,
        ValueFromPipeLineByPropertyName=$False
    )]  # End Parameter
    [ValidateRange(1,100)]
    [Int]$CpuUsageWarningThreshold = 85,

    [Parameter(
        Mandatory=$False,
        ValueFromPipeline=$False,
        ValueFromPipeLineByPropertyName=$False
    )]  # End Parameter
    [ValidateRange(1,100)]
    [Int]$CpuUsageCriticalThreshold = 95,

    [Parameter(
        Mandatory=$False,
        ValueFromPipeline=$False,
        ValueFromPipeLineByPropertyName=$False
    )]  # End Parameter
    [ValidateRange(1,100)]
    [Int]$MemoryWarningThreshold = 85,

    [Parameter(
        Mandatory=$False,
        ValueFromPipeline=$False,
        ValueFromPipeLineByPropertyName=$False
    )]  # End Parameter
    [ValidateRange(1,100)]
    [Int]$MemoryCriticalThreshold = 95,

    [Parameter(
        ParameterSetName="WinRMoverHTTPS",
        Mandatory=$False
    )]  # End Parameter
    [Switch]$UseSSL,

    [Parameter(
        ParameterSetName="WinRMoverHTTPS",
        Mandatory=$False
    )]  # End Parameter
    [Switch]$SkipCACheck,

    [Parameter(
        ParameterSetName="WinRMoverHTTPS",
        Mandatory=$False
    )]  # End Parameter
    [Switch]$SkipCNCheck,

    [Parameter(
        ParameterSetName="WinRMoverHTTPS",
        Mandatory=$False
    )]  # End Parameter
    [Switch]$SkipRevocationCheck,

    [Parameter(
        Mandatory=$False
    )]  # End Parameter
    [Switch]$IgnoreWarningMessage
) # End param

BEGIN {

    If ($ResourceMonitors.Count -gt 5 -and (!($IgnoreWarningMessage.IsPresent))) {

        Write-Warning -Message "[!] PRTG states that the fewer XML results returned, the better the chance they do not get convoluted during data transfer back to PRTG. PRTG claims a max of 50 results but they do not gurantee them"

    }  # End If

    $StringWriter = New-Object -TypeName System.IO.StringWriter
    $XmlWriter = New-Object -TypeName System.Xml.XmlTextWriter -ArgumentList $StringWriter
    $XmlWriter.Formatting = "indented"

} PROCESS {

    Write-Verbose -Message "[v] Evaluating whether to create a CIM session"
    If ($ComputerName.Split('.')[0].ToUpper() -like $Using:Env:COMPUTERNAME) {

        Write-Verbose -Message "[v] Returing information from local device"
        $OS = Get-CimInstance -ClassName "Win32_OperatingSystem"
        $CPUs = Get-CimInstance -ClassName "Win32_Processor"
        $Disks = Get-CimInstance -ClassName "Win32_LogicalDisk" -Filter "DriveType=3"

    } Else {

        Write-Verbose -Message "[v] Defining CIM Session options"
        $CimSessionOptions = New-CimSessionOption -UseSsl:$UseSSL.IsPresent -SkipRevocationCheck:$SkipRevocationCheck.IsPresent -SkipCACheck:$SkipCACheck.IsPresent -SkipCNCheck:$SkipCNCheck.IsPresent

        Write-Verbose -Message "[v] Attempting to establish the CIM session for $ComputerName"
        $CIMSession = New-CimSession -ComputerName $ComputerName -SessionOption $CimSessionOptions

        Write-Verbose -Message "[v] Using CIM Session to return information"
        $OS = Get-CimInstance -CimSession $CIMSession -ClassName "Win32_OperatingSystem"
        $CPUs = Get-CimInstance -CimSession $CIMSession -ClassName  "Win32_Processor"
        $Disks = Get-CimInstance -CimSession $CIMSession -ClassName  "Win32_LogicalDisk" -Filter "DriveType=3"

    } # End If Else


    Write-Verbose -Message "[v] Building XML formatted values using the returned resource information"
    If ($ResourceMonitors -contains "CPULoad") {

        ForEach ($CPU in $CPUs) {

            $CPUsTotal += 1
            $CpuLoadXml += "<Result>
                <Channel>CPU Load #$CPUsTotal</Channel>
                <Value>" + $CPU.LoadPercentage + "</Value>
                <Unit>Percent</Unit>
                <LimitWarningMsg>WARNING: CPU is at or above $CpuUsageWarningThreshold% capacity</LimitWarningMsg>
                <LimitErrorMsg>CRITICAL: CPU is at or above $CpuUsageCriticalThreshold% capacity</LimitErrorMsg>
                <LimitMaxError>$CpuUsageCriticalThreshold.00</LimitMaxError>
                <LimitMaxWarning>$CpuUsageWarningThreshold.00</LimitMaxWarning>
                <LimitMode>1</LimitMode>
            </Result>"

        } # End ForEach

    } Else {

        Write-Verbose -Message "[v] CPU Load monitoring was not specified"

    }  # End If Else


    If ($ResourceMonitors -contains "CPUCount") {

        $CpuTotalXml ="<Result>
            <Channel>Total CPUs</Channel>
            <Value>" + $CPUsTotal + "</Value>
            <Unit>Count</Unit>
        </Result>"

    } Else {

        Write-Verbose -Message "[v] CPU Total Count monitor was not specified"

    }  # End If Else


    If ($ResourceMonitors -contains "DiskFreePercentage" -or $ResourceMonitors -contains "DiskFreeGigabytes") {

        Write-Verbose -Message "[v] Building XML for the returned disk usage information"
        ForEach ($Disk in $Disks) {

            $TotalDriveSpace = $Disk.Size
            $FreeDriveSpace = $Disk.FreeSpace
            $DrivePercentageFree = [Math]::Round(($Disk.FreeSpace/$Disk.Size)*100,2).ToString("###")

            $DisksTotal += 1
            If ($ResourceMonitors -contains "DiskFreeGigabytes") {

                $DiskUsageXml += "<Result>
                    <Channel>Total Space Drive " + $Disk.DeviceID + "</Channel>
                    <Value>" + $TotalDriveSpace + "</Value>
                    <VolumeSize>GigaByte</VolumeSize>
                    </Result>"

                $DiskUsageXml += "<Result>
                    <Channel>Free Space Drive " + $Disk.DeviceID + "</Channel>
                    <Value>" + $FreeDriveSpace + "</Value>
                    <VolumeSize>GigaByte</VolumeSize>
                </Result>"

            } Else {

                Write-Verbose -Message "[v] Disk Free in Gigabytes monitor was not specified"

            }  # End If Else


            If ($ResourceMonitors -contains "DiskFreePercentage") {

                If ($Disk.DeviceID -like 'C:') {

                    $DiskUsageXml += "<Result>
                        <Channel>Percentage Free on Drive " + $Disk.DeviceID + "</Channel>
                        <Value>" + $DrivePercentageFree + "</Value>
                        <Unit>Percent</Unit>
                        <LimitWarningMsg>WARNING: Disk Space Free is at or below $LowDiskSpaceWarningThreshold% capacity</LimitWarningMsg>
                        <LimitErrorMsg>CRITICAL: Available Disk space is at or has fallen below $LowDiskSpaceCriticalThreshold% availability</LimitErrorMsg>
                        <LimitMinError>$LowDiskSpaceCriticalThreshold.00</LimitMinError>
                        <LimitMinWarning>$LowDiskSpaceWarningThreshold.00</LimitMinWarning>
                        <LimitMode>1</LimitMode>
                    </Result>"

                } Else {

                    $DiskUsageXml += "<Result>
                        <Channel>Percentage Free on Drive " + $Disk.DeviceID + "</Channel>
                        <Value>" + $DrivePercentageFree + "</Value>
                        <Unit>Percent</Unit>
                    </Result>"

                } # End Else

            } Else {

                Write-Verbose -Message "[v] Disk Space Percentage monitor was not specified"

            }  # End If Else

        } # End ForEach

        If ($ResourceMonitors -contains "TotalDisks") {

            $DiskTotalToXml ="<Result>
                <Channel>Total Disks</Channel>
                <Value>" + $DisksTotal + "</Value>
                <Unit>Count</Unit>
            </Result>"

        } Else {

            Write-Verbose -Message "[v] Total Disk monitor was not specified"

        }  # End If Else

    } Else {

        Write-Verbose -Message "[v] No Disk Monitoring options were selected"

    }  # End If Else

    Write-Verbose -Message "[v] Building XML values for returned Memory usage information"
    $TotalMemory = ($OS.TotalVisibleMemorySize * 1KB)

    If ($ResourceMonitors -contains "MemoryFreePercentage") {

        $MemoryFreePercentage = [Math]::Round(($OS.FreePhysicalMemory/$OS.TotalVisibleMemorySize)*100,2)
        $MemoryInUsePercentage = [Math]::Round(100-(($OS.FreePhysicalMemory/$OS.TotalVisibleMemorySize)*100),2)
        $MemoryPercentageXml = "<Result>
        <Channel>Total Memory</Channel>
        <Value>" + $TotalMemory + "</Value>
        <VolumeSize>GigaByte</VolumeSize>
        <LimitErrorMsg>ERROR: Connection to $ComputerName could not be established</LimitErrorMsg>
        <LimitMinError>1</LimitMinError>
        <LimitMode>1</LimitMode>
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
        <LimitWarningMsg>WARNING: CPU is at or above $MemoryWarningThreshold% capacity</LimitWarningMsg>
        <LimitErrorMsg>CRITICAL: CPU is at or above $MemoryCriticalThreshold% capacity</LimitErrorMsg>
        <LimitMaxError>$MemoryCriticalThreshold.00</LimitMaxError>
        <LimitMaxWarning>$MemoryWarningThreshold.00</LimitMaxWarning>
        <LimitMode>1</LimitMode>
    </Result>"

    } Else {

        Write-Verbose -Message "[v] Memory Free Percentage monitor was not specified"

    }  # End If Else


    If ($ResourceMonitors -contains "MemoryFreeGigaByte") {

        $MemoryFree = [Math]::Round($OS.FreeVirtualMemory / 1MB, 3)
        $MemoryInUse = [Math]::Round(($OS.TotalVisibleMemorySize - $OS.FreeVirtualMemory) / 1MB, 3)

        $MemoryFreeGbXml = "<Result>
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
        </Result>"

    } Else {

        Write-Verbose -Message "[v] Memory Usage in Gigabytes monitor was not specified"

    }  # End If Else

    $Xml="<PRTG>
            $CpuTotalXml
            $CpuLoadXml
            $DiskTotalToXml
            $DiskUsageXml
            $MemoryFreeGbXml
            $MemoryPercentageXml
        </PRTG>
"

} END {

    [Xml]$Xml.WriteTo($XmlWriter)
    $XmlWriter.Flush()
    $StringWriter.Flush()
    Return $StringWriter.ToString()

}  # End BPE
