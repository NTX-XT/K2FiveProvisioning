param(
    [Parameter()]
    [string]$username, 
    [string]$userpass,
    [string]$dnsname
)

$packaging = get-content -raw -path C:\K2\packaging.json | ConvertFrom-Json

Start-Transcript -Path "C:\K2\K2Provisioning.log"

#region 2.0 Download
$packaging.k2Five.installer, $packaging.k2Five.clientToolsInstaller, $packaging.k2Five.identityServiceInstaller, $packaging.prerequisites.k2Server.vcRedist | ForEach-Object{
    $filePath = "C:/K2/" + [System.Web.HttpUtility]::UrlDecode($_).split('/')[-1] #PS V6++ (Split-Path [System.Web.HttpUtility]::UrlDecode($_) -Leaf)
    Invoke-WebRequest -Uri $_ -OutFile $filePath -UseBasicParsing
}
#endregion

#region 3.0 Install prerequisites

## Minimmum
Install-WindowsFeature NET-Framework-Features, NET-Framework-45-Features -IncludeAllSubFeature 

## Prerequisites for K2 Sites
Install-WindowsFeature Web-Server -IncludeAllSubFeature -IncludeManagementTools 

# Import-Module "WebAdministration"
# New-Item C:\inetpub\K2 -type Directory
# New-Item IIS:\AppPools\K2
# Set-ItemProperty -Path IIS:\AppPools\K2 -Name managedRuntimeVersion -Value 'v2.0'
# Set-ItemProperty -Path IIS:\AppPools\K2 -Name managedPipelineMode -Value 'Classic'
# Set-ItemProperty -Path IIS:\AppPools\K2 -Name processmodel.identityType -Value 3
# Set-ItemProperty -Path IIS:\AppPools\K2 -Name processmodel.userName -Value $username
# Set-ItemProperty -Path IIS:\AppPools\K2 -Name processmodel.password -Value $userpass
# New-Item iis:\Sites\K2 -bindings @{protocol="https";bindingInformation=":443:" + $dnsname} -physicalPath C:\inetpub\K2
# $certificate = $(Get-ChildItem Cert:\LocalMachine\My -DnsName $dnsname)
# (Get-WebBinding -Name K2 -Port 443 -Protocol "https" -HostHeader $dnsname).AddSslCertificate($certificate.Thumbprint, "my")
# Set-WebConfiguration system.webServer/security/authentication/anonymousAuthentication -PSPath IIS:\ -Location K2 -Value @{enabled="False"}
# Set-WebConfiguration system.webServer/security/authentication/windowsAuthentication -PSPath IIS:\ -Location K2 -Value @{enabled="True"}

## Prerequisites for K2 Server
C:\k2\vc_redist.x64.exe /install /q /norestart

## Disable Loopbackcheck
New-ItemProperty HKLM:\System\CurrentControlSet\Control\Lsa -Name "DisableLoopbackCheck" -value "1" -PropertyType dword

## Create self-signed certificate 
New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My -KeyAlgorithm "RSA" -KeyLength "2048"

## Create host entries
Add-Content -Path $env:WINDIR\System32\drivers\etc\hosts -Value "`n127.0.0.1`t$env:COMPUTERNAME`n127.0.0.1`t$dnsname" -Force
#endregion

#region 4.0 Extract K2 package using 7-ZIP console application
Invoke-WebRequest -Uri "https://www.7-zip.org/a/7zr.exe" -OutFile "C:\K2\7zr.exe" -UseBasicParsing
$setupfile = 'C:\K2\' + [System.Web.HttpUtility]::UrlDecode($packaging.k2Five.installer).split('/')[-1]
$setuppath = $setupfile.replace('.exe','')
C:\K2\7zr.exe x $setupfile $("-o" + $setuppath)
#endregion

Exit
#region 5.0 Install K2 using unattended
Set-Location  $setuppath\installation
.\SourceCode.SetupManager.exe /install:"C:\K2\K2Unattended.xml" 
#endregion

Stop-Transcript