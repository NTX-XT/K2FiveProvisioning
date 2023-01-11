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

## Prerequisites for K2 Server
C:\k2\vc_redist.x64.exe /install /q /norestart
 
#endregion

## @TODO: Restart server is needed to start the K2 install


Stop-Transcript