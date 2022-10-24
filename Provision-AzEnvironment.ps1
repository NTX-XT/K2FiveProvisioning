param(
    [Parameter()]
    [string]$ConfigurationFile = ".\configuration.json"
)

#region 0. Loading and connecting Azure
if (-not $(Get-Module Az)) { Import-Module Az -Force } 
$configuration = get-content -raw -path $ConfigurationFile | ConvertFrom-Json
Connect-AzAccount -Subscription $configuration.infrastructure.azure.tenant.Subscription -TenantId $configuration.infrastructure.azure.tenant.id;  
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
    Password = ConvertTo-SecureString -String $configuration.infrastructure.azure.sql.admin.password -AsPlainText -Force
}

## Create the Azure SQL server (Version 12.0) with SQL authentication as required by K2 
$K2SQLServer = @{
    ResourceGroupName           = $K2RG.Name
    Location                    = $configuration.infrastructure.azure.sql.server.location
    ServerName                  = $configuration.infrastructure.azure.sql.server.name
    ServerVersion               = "12.0"
    SqlAdministratorCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $K2SQLAdmin.Login, $K2SQLAdmin.Password
}
$AzSQLServer = New-AzSqlServer @K2SQLServer

## Create the Azure SQL Server Firewall Rule for external use if requested

if ($configuration.infrastructure.azure.sql.server.withExternal){
    $K2SQLFirewall = @{
        ResourceGroupName = $K2RG.Name
        ServerName        = $AzSQLServer.ServerName
        FirewallRuleName  = "AllowAllWindowsAzureIps"
        StartIpAddress    = "0.0.0.0" 
        EndIpAddress      = "0.0.0.0" 
    }
    New-AzSqlServerFirewallRule @K2SQLFirewall
}

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
    Password = ConvertTo-SecureString -String $configuration.infrastructure.azure.VirtualMachine.admin.password -AsPlainText -Force
}

## Create the VM Configuration

$K2VM = @{
    ResourceGroupName  = $K2RG.Name
    Location           = $K2RG.Location
    Name               = $configuration.infrastructure.azure.VirtualMachine.name
    VirtualNetworkName = $K2VNet.Name
    SubnetName         = $K2SubNet.Name
    OpenPorts          = 80, 3389
    ImageName          = $configuration.infrastructure.azure.VirtualMachine.imageName 
    Size               = $configuration.infrastructure.azure.VirtualMachine.size
    Credential         = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $K2VMAdmin.Login, $K2VMAdmin.Password     
}
New-AzVM @K2VM | Out-Null

#endregion

#region 5. (optional) Create a file storage for the lifecycle of the provisioning and store configuration

## Create Storage Account
$K2StorageAccount = @{
    ResourceGroupName = $K2RG.Name
    Name = $configuration.infrastructure.azure.storageAccount.name
    Location = $configuration.infrastructure.azure.storageAccount.location
    Kind = $configuration.infrastructure.azure.storageAccount.kind
    SkuName = $configuration.infrastructure.azure.storageAccount.skuName
    EnableLargeFileShare = $configuration.infrastructure.azure.storageAccount.enableLargeFileShare
}
$StorageAccount = New-AzStorageAccount @K2StorageAccount
$StorageAccountKey = $(Get-AzStorageAccountKey -ResourceGroupName K2Demo1 -AccountName K2Demo1StorageAcct | Where-Object{$_.KeyName -eq "key1"}).Value

## Create Storage Container
$K2StorageContainer = @{
    Name = "k2setup"
    Context = $StorageAccount.Context
    Permission = "Blob"
}
New-AzStorageContainer @K2StorageContainer

## Create File Share
$K2FileStorage = @{
    StorageAccount = $StorageAccount
    Name = $configuration.infrastructure.azure.fileStorage.name
    EnabledProtocol = "SMB"
    QuotaGiB = 1024
}
New-AzRmStorageShare @K2FileStorage

$K2StorageDirectory = @{
    Context = $StorageAccount.Context
    ShareName = $K2FileStorage.Name
    Path = "K2Config"
}
New-AzStorageDirectory @K2StorageDirectory

##  Mount file share 
$runCommandparameters =@{
    AccountStorageKey = $StorageAccountKey
    AccountStorageName = $K2StorageAccount.Name
    FileShareName = $K2FileStorage.Name
}
Invoke-AzVMRunCommand -ResourceGroupName $K2RG.Name -VMName $K2VM.Name -CommandId 'RunPowerShellScript' -ScriptPath '.\mount-K2FileShareFromVM.ps1' `
-Parameter $runCommandparameters

#endregion

#region 6. Continue on uploading content file

#TODO: Focus on 1st approach: deploying on local files
#TODO: 2nd approach: deploying on azure storage later

#endregion

Exit

#region 9. Clean-up
Remove-AzResourceGroup -ResourceGroupName $K2RG.Name -Confirm:$false -Force;
#endregion

#region 0. Create Address IP Public
$ip = @{
    Name = "K2IPPublic"
    ResourceGroupName = $K2RG.Name
    Location = 'eastus'
    Sku = 'Standard'
    AllocationMethod = 'Static'
    IpAddressVersion = 'IPv4'
    Zone = 2
}
New-AzPublicIpAddress @ip
#endregion