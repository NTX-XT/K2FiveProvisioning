param(
    [Parameter()]
    [string]$PackagingFile = ".\packaging.json",
    [string]$ConfigurationFile = ".\configuration.json"
)

#region 0. Loading 
$packaging = get-content -raw -path $PackagingFile | ConvertFrom-Json
$configuration = get-content -raw -path $ConfigurationFile | ConvertFrom-Json
#endregion

#region 1. Download K2 releases
$packaging.k2Five.installer, $packaging.k2Five.clientToolsInstaller, $packaging.k2Five.identityServiceInstaller | ForEach-Object{
    Invoke-WebRequest -Uri $_ -OutFile $configuration.setup.repository
}
#endregion
