param(
    [Parameter()]
    [string]$ConfigurationFile = ".\configuration.json"
)

#region 0. Loading and connecting Azure
if (-not $(Get-Module Az)) { Import-Module Az -Force } 
# TODO: add subscription name and tenant id in the configuration
Connect-AzAccount -Subscription sub_immersion -TenantId 07948bdc-f1ec-40d6-a490-2380819cc701;  
$configuration = get-content -raw -path $ConfigurationFile | ConvertFrom-Json
#endregion

#region 1. Create Resource Group

$K2RG = @{
    Name     = $configuration.infrastructure.azure.resourceGroup.name
    Location = $configuration.infrastructure.azure.resourceGroup.location
}

## What if the Azure Resource group already exists ?
if ($(Get-AzResourceGroup -Name $K2RG.Name  -ErrorAction SilentlyContinue)) {
    Write-Error -Message "The Resource Group '$K2RG.Name' already exists."
    Exit 1       
}

New-AzResourceGroup @K2RG -ErrorAction SilentlyContinue;

if (-not $?) {
    ## If an error occured, exit with code 1.
    Exit 1;
}

#endregion

#region 2. Provision Azure SQL DB

$K2SQLAdmin = @{
    Login    = $configuration.infrastructure.azure.sql.admin.login
    Password = $configuration.infrastructure.azure.sql.admin.password 
}

## Create the Azure SQL server (Version 12.0) with SQL authentication as required by K2 
$K2SQLServer = @{
    ResourceGroupName           = $K2RG.Name
    Location                    = $configuration.infrastructure.azure.sql.server.location
    ServerName                  = $configuration.infrastructure.azure.sql.server.name
    ServerVersion               = "12.0"
    SqlAdministratorCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $K2SQLAdmin.Login, $(ConvertTo-SecureString -String $K2SQLAdmin.Password -AsPlainText -Force)
}
$AzSQLServer = New-AzSqlServer @K2SQLServer

## Create the Azure SQL Server Firewall Rule

# TODO: Add a configuration option to enable external access to SQL Server.
$K2SQLFirewall = @{
    ResourceGroupName = $K2RG.Name
    ServerName        = $AzSQLServer.ServerName
    FirewallRuleName  = "AllowedIPs"
    StartIpAddress    = "0.0.0.0" 
    EndIpAddress      = "0.0.0.0" 
}
New-AzSqlServerFirewallRule @K2SQLFirewall

## Create the Azure SQL Database with an S2 performance level (minimum requirement for K2 integration)
$K2SQLDB = @{
    DatabaseName                  = $configuration.infrastructure.azure.sql.database.name
    ResourceGroupName             = $K2RG.Name
    ServerName                    = $AzSQLServer.ServerName
    RequestedServiceObjectiveName = "S2" 
}
New-AzSqlDatabase  @K2SQLDB
    
#endregion

#region 3. Create Virtual Networking

$K2VNet = @{
    Name              = $configuration.infrastructure.azure.virtualNetwork.name
    ResourceGroupName = $K2RG.Name
    Location          = $K2RG.Location
    AddressPrefix     = '10.0.0.0/16'    
}
$AzVNet = New-AzVirtualNetwork @K2VNet

$K2SubNet = @{
    Name           = 'default'
    VirtualNetwork = $AzVNet
    AddressPrefix  = '10.0.0.0/24'
}
Add-AzVirtualNetworkSubnetConfig @K2SubNet
$AzVNet | Set-AzVirtualNetwork

#endregion

#region 4. Create the VM

$K2VMAdmin = @{
    Login    = $configuration.infrastructure.azure.VirtualMachine.admin.login
    Password = $configuration.infrastructure.azure.VirtualMachine.admin.password
}

# TODO: Add size and ImageName to the configuration, with best practices as defaults

$K2VM = @{
    ResourceGroupName  = $K2RG.Name
    Location           = $K2RG.Location
    Name               = $configuration.infrastructure.azure.VirtualMachine.name
    VirtualNetworkName = $K2VNet.Name
    SubnetName         = $K2SubNet.Name
    OpenPorts          = 80, 3389
    ImageName          = "MicrosoftWindowsServer:WindowsServer:2019-Datacenter:latest" 
    Size               = "Standard_DS3"
    Credential         = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $K2VMAdmin.Login, $(ConvertTo-SecureString -String $K2VMAdmin.Password -AsPlainText -Force)      
}
New-AzVM @K2VM

#endregion

Exit

#region 9. Clean-up
Remove-AzResourceGroup -ResourceGroupName $K2RG.Name -Confirm:$false -Force;
#endregion