param(
    [Parameter()]
    [string]$ConfigurationFile = ".\dist\configuration-trial.json"
)
#region 0 Loading
Write-Verbose "0. Loading configuration"
$configuration = get-content -raw -path $ConfigurationFile | ConvertFrom-Json
#endregion

#region 1. Invoke script to enable PS Remoting
Write-Verbose "1. Enabling PS Remoting on remote Azure VM"

$runCommandparameters = @{
    RemoteUser = $configuration.infrastructure.azure.VirtualMachine.admin.login
    DnsName = $(Get-AzPublicIpAddress -Name $configuration.infrastructure.azure.publicIP.name).DnsSettings.Fqdn
}
Invoke-AzVMRunCommand -ResourceGroupName $configuration.infrastructure.azure.resourceGroup.name -VMName $configuration.infrastructure.azure.VirtualMachine.name -CommandId 'RunPowerShellScript' `
-ScriptPath 'src\deploy_localfiles\Enable-K2PSRemoting.ps1' -Parameter $runCommandparameters
#endregion

