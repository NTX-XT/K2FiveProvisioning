param(
    [Parameter()]
    [string]$ConfigurationFile = ".\dist\configuration-trial.json"
)

#region 0. Loading and connecting Azure
if (-not $(Get-Module Az)) { 
    Write-Verbose "Importing Azure Module"
    Import-Module Az -Force 
} 
Write-Verbose "0. Loading configuration"
$configuration = get-content -raw -path $ConfigurationFile | ConvertFrom-Json

# TODO: Validate Configuration

Write-Verbose "0. Connecting to Azure"
Connect-AzAccount -Subscription $configuration.infrastructure.azure.tenant.subscription
#endregion

#region 1. Create Resource Group
Write-Verbose "1. Creating Resource Group"
$K2RG = @{
    Name     = $configuration.infrastructure.azure.resourceGroup.name
    Location = $configuration.infrastructure.azure.resourceGroup.location
}

## What if the Azure Resource group already exists ?
if ($(Get-AzResourceGroup -Name $K2RG.Name  -ErrorAction SilentlyContinue)) {
    Write-Error -Message "The Resource Group '$K2RG.Name' already exists."
    Exit 1       
}

New-AzResourceGroup @K2RG -ErrorAction SilentlyContinue

if (-not $?) {
    ## If an error occured, exit with code 1.
    Exit 1;
}

#endregion

#region 2. Provision Azure SQL DB
#Write-Verbose "2. Provisioning Azure SQL DB"

#$K2SQLAdmin = @{
#     Login    = $configuration.infrastructure.azure.sql.admin.login
#     Password = ConvertTo-SecureString -String $configuration.infrastructure.azure.sql.admin.password -AsPlainText -Force
# }

# ## Create the Azure SQL server (Version 12.0) with SQL authentication as required by K2 
# $K2SQLServer = @{
#     ResourceGroupName           = $configuration.infrastructure.azure.resourceGroup.name
#     Location                    = $configuration.infrastructure.azure.sql.server.location
#     ServerName                  = $configuration.infrastructure.azure.sql.server.name
#     ServerVersion               = "12.0"
#     SqlAdministratorCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $K2SQLAdmin.Login, $K2SQLAdmin.Password
# }
# $AzSQLServer = New-AzSqlServer @K2SQLServer

## Create the Azure SQL Server Firewall Rule for external use if requested

# if ($configuration.infrastructure.azure.sql.server.withExternal) {
#     $K2SQLFirewall = @{
#         ResourceGroupName = $configuration.infrastructure.azure.resourceGroup.name
#         ServerName        = $AzSQLServer.ServerName
#         FirewallRuleName  = "AllowAllWindowsAzureIps"
#         StartIpAddress    = "0.0.0.0" 
#         EndIpAddress      = "0.0.0.0" 
#     }
#     New-AzSqlServerFirewallRule @K2SQLFirewall
# }

## Create the Azure SQL Database with an S2 performance level (minimum requirement for K2 integration)
# $K2SQLDB = @{
#     DatabaseName                  = $configuration.infrastructure.azure.sql.database.name
#     ResourceGroupName             = $configuration.infrastructure.azure.resourceGroup.name
#     ServerName                    = $AzSQLServer.ServerName
#     RequestedServiceObjectiveName = "S2" 
# }
# New-AzSqlDatabase  @K2SQLDB
    
#endregion

#region 3. Create Virtual Networking
Write-Verbose "3. Creating Virtual Network"

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

$K2IPPublic = @{
    Name              = $configuration.infrastructure.azure.publicIP.name
    ResourceGroupName = $K2RG.Name
    Location          = $K2RG.Location
    Sku               = 'Standard'
    AllocationMethod  = 'Static'
    IpAddressVersion  = 'IPv4'
    DomainNameLabel   = $configuration.infrastructure.azure.publicIP.DomainNameLabel.ToLower()
    Zone              = 2
}
$AzIPPublic = New-AzPublicIpAddress @K2IPPublic

#endregion

#region 4. Create the VM
Write-Verbose "3. Creating Virtual Machine"

$K2VMAdmin = @{
    Login    = $configuration.infrastructure.azure.VirtualMachine.admin.login
    Password = ConvertTo-SecureString -String $configuration.infrastructure.azure.VirtualMachine.admin.password -AsPlainText -Force
}

$K2VM = @{
    ResourceGroupName   = $K2RG.Name
    Location            = $K2RG.Location
    Name                = $configuration.infrastructure.azure.VirtualMachine.name.ToLower()
    VirtualNetworkName  = $K2VNet.Name
    SubnetName          = $K2SubNet.Name
    PublicIpAddressName = $AzIPPublic.Name
    OpenPorts           = 80, 443, 3389, 5552, 5555, 5560, 5986
    ImageName           = $configuration.infrastructure.azure.VirtualMachine.imageName 
    Size                = $configuration.infrastructure.azure.VirtualMachine.size
    Credential          = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $K2VMAdmin.Login, $K2VMAdmin.Password     
}
New-AzVM @K2VM 
#endregion

Write-Verbose "Azure Provisioning completed"
Exit

#region 9. Clean-up
Remove-AzResourceGroup -ResourceGroupName $configuration.infrastructure.azure.resourceGroup.name -Confirm:$false -Force;
#endregion

#region 5. (optional) Create a file storage for the lifecycle of the provisioning and store configuration

## Create Storage Account
$K2StorageAccount = @{
    ResourceGroupName    = $configuration.infrastructure.azure.resourceGroup.name
    Name                 = $configuration.infrastructure.azure.storageAccount.name
    Location             = $configuration.infrastructure.azure.storageAccount.location
    Kind                 = $configuration.infrastructure.azure.storageAccount.kind
    SkuName              = $configuration.infrastructure.azure.storageAccount.skuName
    EnableLargeFileShare = $configuration.infrastructure.azure.storageAccount.enableLargeFileShare
}
$StorageAccount = New-AzStorageAccount @K2StorageAccount

## Create Storage Container
$K2StorageContainer = @{
    Name       = "k2setup"
    Context    = $StorageAccount.Context
    Permission = "Blob"
}
New-AzStorageContainer @K2StorageContainer

## Create File Share
$K2FileStorage = @{
    StorageAccount  = $StorageAccount
    Name            = $configuration.infrastructure.azure.fileStorage.name
    EnabledProtocol = "SMB"
    QuotaGiB        = 1024
}
New-AzRmStorageShare @K2FileStorage

$K2StorageDirectory = @{
    Context   = $StorageAccount.Context
    ShareName = $K2FileStorage.Name
    Path      = "K2Config"
}
New-AzStorageDirectory @K2StorageDirectory

##  Mount file share 
$runCommandparameters = @{
    AccountStorageKey  = $StorageAccountKey
    AccountStorageName = $K2StorageAccount.Name
    FileShareName      = $K2FileStorage.Name
}
Invoke-AzVMRunCommand -ResourceGroupName $K2RG.Name -VMName $K2VM.Name -CommandId 'RunPowerShellScript' -ScriptPath '.\mount-K2FileShareFromVM.ps1' `
    -Parameter $runCommandparameters

#endregion
