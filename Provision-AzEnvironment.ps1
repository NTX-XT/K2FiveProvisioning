# Script that will provision the K2 Five Azure Env
Import-Module Az -Force
Connect-AzAccount -Subscription sub_immersion


# 1. Create the resource group
# 2. Provision Azure SQL DB
# 3. Create networking (vNet)
# 4. Create the VM