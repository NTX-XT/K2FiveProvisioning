
param(
    [Parameter()]
    [string]$Installer,
    [string]$ClientToolInstaller,
    [string]$IdentityServiceInstaller,
    [array]$Patches

)

#region 1.0 Prepare K2 Repository
MKdir -Path "C:\" -Name "K2" 
#endregion

Start-Transcript -Path "C:\K2\K2Provisioning.log"

#region 2.0 Download
$Installer, $ClientToolInstaller, $IdentityServiceInstaller | ForEach-Object{
    $filePath = "C:\K2\" + (Split-Path [System.Web.HttpUtility]::UrlDecode($_) -Leaf)
    Invoke-WebRequest -Uri $_ -OutFile $filePath -UseBasicParsing
}
#endregion

Stop-Transcript