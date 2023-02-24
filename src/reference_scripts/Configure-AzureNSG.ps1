$resourceGroupName = "*******"
$vmName = "********"

Import-Module Az
if ($null -eq $account) {
    $account = Connect-AzAccount
}

$vm = Get-AzVM -Name $vmName -ResourceGroupName $resourceGroupName

$config = @(
    [PSCustomObject]@{
        Name = "DEV_WinRM"
        Port = "5986"
    },
    [PSCustomObject]@{
        Name = "DEV_SQL_Server_Instance"
        Port = "1433"
    },
    [PSCustomObject]@{
        Name = "DEV_VS2022_Remote_Debug"
        Port = "4026"
    }
)

foreach ($niPath in $vm.NetworkProfile.NetworkInterfaces) {
    $niId = $niPath.id.Split('/')[-1]
    $ni = Get-AzNetworkInterface -Name $niId
    $nsgName = $ni.NetworkSecurityGroup.Id.Split('/')[-1]
    $nsg = Get-AzNetworkSecurityGroup -Name $nsgName
    $priority = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg | Sort-Object -Property Priority -Descending | Select-Object -first 1 -ExpandProperty Priority
    Write-Host "Configuring $($nsg.Name)" -ForegroundColor Green
    foreach ($item in $config) {
        if ($null -ne (Get-AzNetworkSecurityRuleConfig -Name $item.Name -NetworkSecurityGroup $nsg -ErrorAction SilentlyContinue)) {
            Write-Host "Network rule $($item.Name) found." -ForegroundColor Yellow
        }
        else {
            $priority = $priority + 10
            Add-AzNetworkSecurityRuleConfig -Name $item.Name -NetworkSecurityGroup $nsg -Protocol Tcp -SourcePortRange * -DestinationPortRange $item.Port -Access Allow -Direction Inbound -SourceAddressPrefix "*" -DestinationAddressPrefix "*" -Priority $priority | Out-Null     
            Write-Host "Network rule $($item.Name) added." -ForegroundColor Green
        }
    }
    
    Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg | Out-Null
}