
param(
    [Parameter()]
    [string]$ConfigurationFile = ".\configuration-cecilia.json"
)
#region 0 Loading
Write-Verbose "0. Loading configuration"
$configuration = get-content -raw -path $ConfigurationFile | ConvertFrom-Json
#endregion


$r = @{
    "{{k2vm}}" = $configuration.infrastructure.azure.VirtualMachine.name.ToLower();
    "{{k2sql}}" = $configuration.infrastructure.azure.sql.server.name.ToLower();
    "{{sqladminlogin}}" = $configuration.infrastructure.azure.sql.admin.login.ToLower();
    "{{sqladminpassword}}" = $configuration.infrastructure.azure.sql.admin.password;
    "{{k2sqldb}}" = $configuration.infrastructure.azure.sql.database.name.ToLower();
    "{{k2host}}" = $(Get-AzPublicIpAddress -Name $configuration.infrastructure.azure.publicIP.name).DnsSettings.Fqdn
}

$regexes = $r.keys | ForEach-Object {[System.Text.RegularExpressions.Regex]::Escape($_)}
#$regex = [regex]($regexes -join '|')
$regex = [regex]("(?i)" + ($regexes -join '|'))
$callback = { $r[$args[0].Value] }

$unattended = Get-Content "..\src\K2Unattended.xml"
$unattended = $regex.Replace($unattended, $callback)
#Set-Content -Path C:\scripts\test.txt.out -Value $unattended