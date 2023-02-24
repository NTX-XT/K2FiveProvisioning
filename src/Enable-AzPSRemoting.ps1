param(
    [Parameter()]
    [string]$ConfigurationFile = ".\configuration.json"
)
#region 0 Loading
$configuration = get-content -raw -path $ConfigurationFile | ConvertFrom-Json
#endregion

#region 1. Invoke script to enable PS Remoting
$runCommandparameters = @{
    RemoteUser = $configuration.infrastructure.azure.VirtualMachine.admin.login
    DnsName = $(Get-AzPublicIpAddress -Name $configuration.infrastructure.azure.publicIP.name).DnsSettings.Fqdn
}
Invoke-AzVMRunCommand -ResourceGroupName $configuration.infrastructure.azure.resourceGroup.name -VMName $configuration.infrastructure.azure.VirtualMachine.name -CommandId 'RunPowerShellScript' `
-ScriptPath '.\deploy_localfiles\Enable-K2PSRemoting.ps1' -Parameter $runCommandparameters
#endregion

