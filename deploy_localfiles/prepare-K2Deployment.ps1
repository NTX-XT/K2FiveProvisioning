$packaging = get-content -raw -path C:\K2\packaging.json | ConvertFrom-Json

Start-Transcript -Path "C:\K2\K2Provisioning.log"

Write-host $packaging.k2Five.installer

#region 2.0 Download
$packaging.k2Five.installer, $packaging.k2Five.clientToolsInstaller, $packaging.k2Five.identityServiceInstaller | ForEach-Object{
    $filePath = "C:\K2\" + (Split-Path [System.Web.HttpUtility]::UrlDecode($_) -Leaf)
    Invoke-WebRequest -Uri $_ -OutFile $filePath -UseBasicParsing
}
#endregion

Stop-Transcript