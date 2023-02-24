param(
    [Parameter()]
    [string]$ConfigurationFile = ".\configuration.json"
)

#region 0 Loading
$configuration = get-content -raw -path $ConfigurationFile | ConvertFrom-Json
$computerName = $(Get-AzPublicIpAddress -Name $configuration.infrastructure.azure.publicIP.name).DnsSettings.Fqdn
#endregion

#region 1. Connect to K2 VM
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $configuration.infrastructure.azure.VirtualMachine.admin.login, $(ConvertTo-SecureString -String $configuration.infrastructure.azure.VirtualMachine.admin.password -AsPlainText -Force)
$so = New-PsSessionOption -SkipCACheck -SkipCNCheck
$s = New-PSSession -ComputerName $computerName -Credential $credential -SessionOption $so -UseSSL
#endregion

#region 2. Provision K2 Directory
Invoke-Command -ComputerName $computerName -ScriptBlock { New-Item -Path C:\K2 -type directory -Force } -Credential $credential -SessionOption $so -UseSSL
Copy-Item .\packaging.json -Destination C:\K2\packaging.json -ToSession $s -Force
Copy-Item .\deploy_localfiles\prepare-K2Deployment.ps1 -Destination C:\K2\prepare-K2Deployment.ps1 -ToSession $s
Copy-Item .\deploy_localfiles\K2Unattended.xml -Destination C:\K2\K2Unattended.xml -ToSession $s
#endregion

#region 3. Start Script 
## Create K2Service Account
Invoke-Command -ComputerName $computerName -ScriptBlock {
    New-LocalUser "K2Service" -Password $args[0] -FullName "K2Service" -Description "K2 Service Account"
    Add-LocalGroupMember -Group "Administrators" -Member "K2Service"
} -Credential $credential -SessionOption $so -UseSSL -ArgumentList $(ConvertTo-SecureString -String $configuration.infrastructure.azure.VirtualMachine.admin.password -AsPlainText -Force)

## Start Deployment
Invoke-Command -ComputerName $computerName -ScriptBlock { 
    C:\K2\prepare-K2Deployment.ps1 -username $args[0] -userpass $args[1] -dnsname $args[2]
} -Credential $credential -SessionOption $so -UseSSL -ArgumentList $configuration.infrastructure.azure.VirtualMachine.admin.login, `
$configuration.infrastructure.azure.VirtualMachine.admin.password, $computerName

#endregion

#region 4. Restart
Restart-Computer -ComputerName $computerName -Wait -For PowerShell -Timeout 600 -Delay 5
#endregion



