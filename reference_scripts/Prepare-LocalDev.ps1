$assemblyNames = @(
    "SourceCode.Azure.ActiveDirectory",
    "SourceCode.HostClientAPI",
    "SourceCode.HostServerInterfaces",
    "SourceCode.Logging",
    "SourceCode.HostServerInterfaces"
)

$securityProviderAssemblyNames = @(
    "SourceCode.Security.Providers.AzureActiveDirectory"   
)

Import-Module .\K2RemoteDev.psm1 -Force

$assemblyNames | ForEach-Object { Copy-AssemblyFromK2Server -AssemblyName $_ -Destination ..\lac }
$securityProviderAssemblyNames | ForEach-Object { Copy-SecurityProviderAssemblyFromK2Server -AssemblyName $_ -Destination ..\lac }