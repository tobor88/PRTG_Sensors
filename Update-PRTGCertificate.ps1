#Requires -Version 3.0
#Requires -Module PSPKI
Function Update-PRTGCertifiate {
<#
.SYNOPSIS
This cmdlet is used to update the HTTPS certificate used by a PRTG server


.DESCRIPTION
Replace the SSL certificate on a local server hosting the PRTG service


.PARAMETER PfxPath
Define the file location of the PFX certificate file

.PARAMETER Password
Enter the password to unlock the PFX file

.PARAMETER CertPath
Enter a path to save your public certificate file too

.PARAMETER CertDestination
Enter the destination path to save your certificates public cert on a remote device

.PARAMETER KeyPath
Enter a path to save your certificate key file

.PARAMETER KeyDestination
Enter the destination path to save your certificate key file for a remote service

.PARAMETER CAPath
Enter the path to the Root CA file that will get trusted on a remote computer

.PARAMETER CADestination
Enter the destination path to save a Root CA file on a remote computer in accordance with that services documentation

.PARAMETER OverwriteExistingCertificate
Tell the cmdlet you do not wish to back up any pre-existing certificate files for PRTG and overwrite the current ones


.EXAMPLE
Update-SSLCertificate -CertPath C:\Temp\cert.pem -KeyPath C:\Temp\key.pem -CertDestination "C:\Program Files (x86)\PRTG Network Monitor\cert\prtg.crt" -KeyDestination "C:\Program Files (x86)\PRTG Network Monitor\cert\prtg.key" -CAPath $CAChainFile -CADestination "C:\Program Files (x86)\PRTG Network Monitor\cert\root.pem" -PfxCertificate "C:\Temp\ssl-cert.pfx" -KeyPassword (ConvertTo-SecureString -AsPlainTest -Force -String 'Str0ngK3yP@ssw0rd!') -Service "PRTGCoreService","PRTGProbeService" -ComputerName "prtg.domain.com" -UseSSL -Credential (Get-Credential)
# This example replaces the public certiticate, private key certificate, and CA chain certificate files on a PRTG server. It restarts the two PRTG services and saves a copy of the replaced certificates as .old files


.NOTES
Author: Robert H. Osborne
Alias: tobor
Contact: rosborne@osbornepro.com


.LINK
https://osbornepro.com
https://encrypit.osbornepro.com
https://writeups.osbornepro.com
https://btpssecpack.osbornepro.com
https://github.com/tobor88
https://github.com/OsbornePro
https://gitlab.com/tobor88
https://www.powershellgallery.com/profiles/tobor
https://www.linkedin.com/in/roberthosborne/
https://www.credly.com/users/roberthosborne/badges
https://www.hackthebox.eu/profile/52286
#>
[OutputType([System.Management.Automation.PSObject])]
[CmdletBinding(DefaultParameterSetName="PFX")]
    param(
        [Parameter(
            ParameterSetName="PFX",
            Position=0,
            Mandatory=$True,
            HelpMessage="[H] Define the absolute path to your PFX certificate file `n[E] EXAMPLE: C:\ProgramData\Certify\assets\_.yourdomain.com\wildcard.pfx")]  # End Parameter
        [ValidateScript({$_.Extension -like ".pfx"})]
        [System.IO.FileInfo]$PfxPath,

        [Parameter(
            ParameterSetName="PFX",
            Position=1,
            Mandatory=$True,
            HelpMessage="[H] Enter the password being used to protect the PFX file's private key `n[E] EXAMPLE: ConvertTo-SecureString -String 'Str0ngk#3yP@ssw0rd!' -AsPlainText -Force")]  # End Parameter
        [SecureString]$Password,

        [Parameter(
            ParameterSetName="AlreadyExtracted",
            Position=0,
            Mandatory=$True,
            HelpMessage="[H] Define the absolute path of your extracted public certificate `n[E] EXAMPLE: C:\Temp\cert.crt"
        )] # End Parameter
        [ValidateScript({$_.Extension -like ".crt"})]
        [System.IO.FileInfo]$CertPath,

        [Parameter(
            ParameterSetName="AlreadyExtracted",
            Position=1,
            Mandatory=$True,
            HelpMessage="[H] Define the absolute path of your extracted certificates key `n[E] EXAMPLE: C:\Temp\key.key"
        )] # End Parameter
        [ValidateScript({$_.Extension -like ".key"})]
        [System.IO.FileInfo]$KeyPath,

        [Parameter(
            ParameterSetName="AlreadyExtracted",
            Position=2,
            Mandatory=$True,
            HelpMessage="[H] Define the absolute path of your Full Chain CA certificates `n[E] EXAMPLE: C:\Temp\root.pem"
        )] # End Parameter
        [ValidateScript({$_.Extension -like ".pem"})]
        [System.IO.FileInfo]$CAPath,

        [Parameter(
            Position=3,
            Mandatory=$False,
            HelpMessage="[H] Set the aboslute path to save your certificate file on the remote machine running a service with HTTPS`n[E] EXAMPLE: C:\ProgramData\Tenable\Nessus\nessus\CA\servercert.pem"
        )]  # End Parameter
        [String]$CertDestination = "C:\Program Files (x86)\PRTG Network Monitor\cert\prtg.crt",

        [Parameter(
            Position=4,
            Mandatory=$False,
            HelpMessage="[H] Set the aboslute path to save your certificates Key file on the remote machine running a service with HTTPS`n[E] EXAMPLE: C:\ProgramData\Tenable\Nessus\nessus\CA\serverkey.pem"
        )]  # End Parameter
        [String]$KeyDestination = "C:\Program Files (x86)\PRTG Network Monitor\cert\prtg.key",

        [Parameter(
            Position=5,
            Mandatory=$False,
            HelpMessage="[H] Set the aboslute path to save your certificates Key file on the remote machine running a service with HTTPS`n[E] EXAMPLE: C:\ProgramData\Tenable\Nessus\nessus\CA\serverkey.pem"
        )]  # End Parameter
        [String]$CADestination = "C:\Program Files (x86)\PRTG Network Monitor\cert\root.pem",
        
        [Parameter(
            Mandatory=$False
        )]  # End Parameter
        [Switch][Bool]$OverwriteExistingCertificate
    )  # End param

    $IdentityCheck = New-Object -TypeName System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    If (!($IdentityCheck.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))) {

        Throw "[x] You are required to run this script using elevated admin privileges"

    }  # End If

    $Modules = "PSPKI"
    If (!(Get-Module -ListAvailable -Name $Modules)) {

        Install-Module -Name $Modules

    }  # End If
    Import-Module -Name $Modules -Force
    $PRTGServices = @("PRTGCoreService","PRTGProbeService")
    $PFXCertificate = Get-PfxCertificate -FilePath $PfxPath.FullName -Password $Password


    If (!($OverwriteExistingCertificate.IsPresent)) {

        Write-Verbose -Message "[v] Backing up the existing PRTG certificate files"
        Move-Item -Path $KeyDestination -Destination "$($KeyDestination)_$(Get-Date -Format 'yyyy-MM-dd_hh-mm-ss').old" -Force -Confirm:$False -ErrorAction Inquire
        Move-Item -Path $CertDestination -Destination "$($CertDestination)_$(Get-Date -Format 'yyyy-MM-dd_hh-mm-ss').old" -Force -Confirm:$False -ErrorAction Inquire
        Move-Item -Path $CADestination -Destination "$($CADestination)_$(Get-Date -Format 'yyyy-MM-dd_hh-mm-ss').old" -Force -Confirm:$False -ErrorAction Inquire
    
    }  # End If

    If ($PSCmdlet.ParameterSetName -eq "PFX") {

        Write-Verbose -Message "[v] Extrating the Public Certificate from the PFX file $($PfxPath.Name) to $($CertDestination)"
        Export-Certificate -Cert $PFXCertificate -FilePath $CertDestination.Replace(".crt", ".cer") -Type CERT -Force | Out-Null
        Start-Process -FilePath "C:\Windows\System32\certutil.exe" -ArgumentList @("-f", "-encode", $CertDestination.Replace(".crt", ".cer"), $CertDestination) -Wait -WorkingDirectory "C:\Windows\System32" -NoNewWindow -Confirm:$False
        Remove-Item -Path $CertDestination.Replace(".crt", ".cer") -Force -Confirm:$False -Verbose:$False -ErrorAction SilentlyContinue -WarningAction SilentlyContinue


        Write-Verbose -Message "[v] Extracting the Full CA Chain from the PFX file $($PfxPath.Name) to $($CADestination)"
        $AllCACerts = @()
        $Chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
        $Chain.Build($PfxCertificate) | Out-Null
        $Chain.ChainElements | ForEach-Object {

            Export-Certificate -FilePath $CADestination -Cert $_.Certificate -Type CERT -Force | Out-Null
            Start-Process -FilePath "C:\Windows\System32\certutil.exe" -ArgumentList @("-f", "-encode", $CADestination.Replace(".crt", ".cer"), $CADestination) -Wait -WorkingDirectory "C:\Windows\System32" -NoNewWindow -Confirm:$False
            $AllCACerts += Get-Content -Path $CADestination -Force

        }  # End ForEach-Object
        Set-Content -Path $CADestination -Value $AllCACerts


        Write-Verbose -Message "[v] Extracting private key from the PFX file"
        Convert-PfxToPem -InputFile $PfxPath.FullName -Outputfile $KeyDestination -Password $Password
        $FileContents = Get-Content -Path $KeyDestination -Raw
        $FileContents -Match "(?ms)(\s*((?<privatekey>-----BEGIN PRIVATE KEY-----.*?-----END PRIVATE KEY-----)|(?<certificate>-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----))\s*){2}"
        $Matches["privatekey"] | Out-File -FilePath $KeyDestination -Force
        
        # STILL TRYING TO FIND A WAY TO NATIVELY EXPORT THE PRIVATE KEY FROM A PFX FILE ON WINDOWS USING NATIVE LIBRARIES
        #---------------------------------------------------------------------------------------------------------------------
        #$CertFlags = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509KeyStorageFlags
        #$CertFlags.value__ = 4
        #$CertObj = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2($PfxPath.FullName, $Password, $CertFlags)       
        # Maybe a der or encrypted file comes out here somehow
        #Start-Process -FilePath "C:\Windows\System32\certutil.exe" -ArgumentList @("-f", "-encode", $KeyDestination.Replace(".key", ".txt"), $KeyDestination) -Wait -WorkingDirectory "C:\Windows\System32" -NoNewWindow -Confirm:$False
        #Remove-Item -Path $KeyDestination.Replace(".key", ".txt") -Force -Confirm:$False -Verbose:$False -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    } Else {

        Write-Verbose -Message "[v] Copying over new certificate files to PRTG default location"
        Copy-Item -Path $KeyPath -Destination $KeyDestination -Force -Confirm:$False -ErrorAction Inquire
        Copy-Item -Path $CertPath -Destination $CertDestination -Force -Confirm:$False -ErrorAction Inquire
        Copy-Item -Path $CAPath -Destination $CADestination -Force -Confirm:$False -ErrorAction Inquire
    
    }  # End If Else

    Write-Verbose -Message "[v] Restarting PRTG services: $PRTGServices"
    Restart-Service -Name $PRTGServices -Force

}  # End Function Update-PRTGCertificate
