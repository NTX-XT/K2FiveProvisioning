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
#end-region

#region 2. Provision K2 Directory
Invoke-Command -ComputerName $computerName -ScriptBlock { New-Item -Path C:\K2 -type directory -Force } -Credential $credential -SessionOption $so -UseSSL
Copy-Item .\packaging.json -Destination C:\K2\packaging.json -ToSession $s -Force
Copy-Item .\deploy_localfiles\prepare-K2Deployment.ps1 -Destination C:\K2\prepare-K2Deployment.ps1 -ToSession $s
#endregion

#region 3. Start Script 
Invoke-Command -ComputerName $computerName -ScriptBlock { C:\K2\prepare-K2Deployment.ps1 } -Credential $credential -SessionOption $so -UseSSL
#endregion