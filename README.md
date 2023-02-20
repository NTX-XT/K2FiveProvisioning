# K2FiveProvisioning

Steps :
1- Provision-AzEnvironment.ps1 -> provision all Azure resources : Resource group, Azure SQL Server and Database, Azure Network and Public Address, Dnsname, Azure Virtual Machine
2- Enable-AzPSRemoting.ps1 -> start Enable-K2PSRemoting.ps1 on remote machine
3- Install-K2Prereqs.ps1 -> copy installation files and start prepare-K2Deployment.ps1 locally on the remote machine
