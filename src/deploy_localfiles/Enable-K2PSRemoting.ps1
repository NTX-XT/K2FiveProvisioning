param(
    [string]$RemoteUser,
    [string]$DnsName
)

#region 1. Enable PS Remoting
Enable-PSRemoting -SkipNetworkProfileCheck -Force
Set-Item WSMan:localhost\client\trustedhosts -value * -Force
New-NetFirewallRule -Name "Allow WinRM HTTPS" -DisplayName "WinRM HTTPS" -Enabled True -Profile Any -Action Allow -Direction Inbound -LocalPort 5986 -Protocol TCP
$thumbprint = (New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation Cert:\LocalMachine\My).Thumbprint
$command = "winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=""$DnsName""; CertificateThumbprint=""$thumbprint""}"
cmd.exe /C $command

    #region 1.1 Configure Remote User
    Add-LocalGroupMember -Group "Remote Management Users" -Member $RemoteUser -ErrorAction SilentlyContinue   
    #endregion

net stop winrm
net start winrm
Write-Host "Powershell remoting has been enabled." -ForegroundColor Green
#endregion

