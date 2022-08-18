$dnsName = '********.********.cloudapp.azure.com'

function disableESCForKey($key) {
    $escEnabled = Get-ItemProperty -Path $key | Select-Object 'IsInstalled' -ExpandProperty 'IsInstalled'
    if ($escEnabled -eq 1) {
        Set-ItemProperty -Path $key -Name "IsInstalled" -Value 0
    }
}

function disableLUA {
    $luaEnabled = Get-Itemproperty -path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\policies\system' | Select-Object 'EnableLUA' -ExpandProperty 'EnableLUA'
    if ($luaEnabled -eq 1) {
        Set-Itemproperty -path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\policies\system' -Name 'EnableLUA' -value 0
    }
    Write-Host "LUA has been disabled." -ForegroundColor Green
}

function disableESC() {
    disableESCForKey -key "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    disableESCForKey -key "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"

    Stop-Process -Name Explorer -Force
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}

function disableFirewall() {
    Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False
    Write-Host "Firewall has been disabled." -ForegroundColor Green
}

function configureRemoteUser() {
    $userName = "remote_user"
    $password = "********"

    $user = Get-LocalUser -Name $userName -ErrorAction SilentlyContinue
    if ($null -eq $user) {
        $secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
        $user = New-LocalUser -Name $userName -Password $secpasswd -AccountNeverExpires -UserMayNotChangePassword
    }

    Add-LocalGroupMember -Group "Administrators" -Member $userName -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group "Remote Management Users" -Member $userName -ErrorAction SilentlyContinue   
}

function enablePSRemoting() {
    $certificateName = "psremoting"

    Enable-PSRemoting -SkipNetworkProfileCheck -Force
    Set-Item WSMan:localhost\client\trustedhosts -value * -Force
    $cert = Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.FriendlyName -eq $certificateName } | Select-Object -first 1
    if ($null -eq $cert) {
        $cert = New-SelfSignedCertificate -DnsName $dnsName -CertStoreLocation cert:\LocalMachine\My -FriendlyName $certificateName
    }
    winrm delete winrm/config/Listener?Address=*+Transport=HTTPS
    winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$dnsName`";CertificateThumbprint=`"$($cert.ThumbPrint)`"}"
    configureRemoteUser
    net stop winrm
    net start winrm
    Write-Host "Powershell remoting has been enabled." -ForegroundColor Green
}

function configureVS2022RemoteDebug() {
    Invoke-WebRequest -Uri "https://download.visualstudio.microsoft.com/download/pr/78d9190c-0169-41a2-8225-71504527a7db/501ffdc1401c905367e966e744160aa89d68b02ec33a71347d0e77ce47ff282c/VS_RemoteTools.exe" -OutFile "C:\VS_RemoteTools.exe"
    Start-Process -FilePath "c:\VS_RemoteTools.exe" -NoNewWindow -Wait -ArgumentList "/install /quiet"
    Set-Service -Name "msvsmon170" -StartupType Automatic
    Start-Service -Name "msvsmon170"
}

disableESC
disableLUA
disableFirewall
enablePSRemoting
configureVS2022RemoteDebug

