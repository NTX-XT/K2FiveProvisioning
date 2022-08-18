New-Variable -Name K2DevSession -Value $null -Scope Script -Force
New-Variable -Name K2BinPath -Value "C:\Program Files\K2\Host Server\Bin" -Scope Script -Force

function Get-K2DevSession {
	if ($null -ne $script:K2DevSession -and $script:K2DevSession.State -eq "Broken") {	
		$script:K2DevSession = $null
	}

	if ($null -eq $script:K2DevSession) {	
		Connect-K2Dev
	}
	return $script:K2DevSession
}

function Get-K2BinPath {
	return $script:K2BinPath
}

function Connect-K2Dev {
	if ($null -eq $script:K2DevSession) {
		$userName = 'remote_user'
		$password = '******'
		$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
		$cred = New-Object System.Management.Automation.PSCredential($username, $secpasswd)

		$dnsName = '*******.*******.cloudapp.azure.com'
		$pso = New-PSSessionOption -SkipCACheck

		$script:K2DevSession = New-PSSession -ComputerName $dnsName -UseSSL -SessionOption $pso -Credential $cred
	}
}

function Disconnect-K2Dev {
	if ($null -ne $script:K2DevSession) {
		$script:K2DevSession | Disconnect-PSSession 
	}
}

function Get-K2ServerStatus {
	Invoke-Command -Session (Get-K2DevSession) -ScriptBlock { Get-Service -Name "K2 Server" }		
}

function Stop-K2Server {
	Invoke-Command -Session (Get-K2DevSession) -ScriptBlock { Stop-Service -Name "K2 Server" }		
	return Get-K2ServerStatus
}

function Start-K2Server {
	Invoke-Command -Session (Get-K2DevSession) -ScriptBlock { Start-Service -Name "K2 Server" }		
	return Get-K2ServerStatus
}

function Restart-K2Server {
	Stop-K2Server
	Start-K2Server
}

function Copy-ToK2Server {
	param(
		[Parameter()]
		[string]$Source,
		[Parameter()]
		[string]$Destination
	)
	Stop-K2Server
	Copy-Item -ToSession (Get-K2DevSession) -Path $Source -Destination $Destination
	Start-K2Server 
}

function Copy-ToK2ServerBin {
	param(
		[Parameter()]
		[string]$Source
	)
	Copy-ToK2Server -Source $Source -Destination $script:K2BinPath
}

function Copy-ToK2ServerSecurityPoviders {
	param(
		[Parameter()]
		[string]$Source
	)
	Copy-ToK2Server -Source $Source -Destination (Join-Path -Path ($script:K2BinPath) -ChildPath "securityproviders")
}

function Copy-FromK2Server {
	param(
		[Parameter()]
		[string]$Source,
		[Parameter()]
		[string]$Destination
	)
	Copy-Item -FromSession (Get-K2DevSession) -Path $Source -Destination $Destination
}

function Copy-AssemblyFromK2Server {
	param(
		[Parameter()]
		[string]$AssemblyName,
		[Parameter()]
		[string]$Destination
	)
	Copy-FromK2Server -Source (Join-Path -Path $script:K2BinPath -ChildPath "$($AssemblyName).dll") -Destination $Destination
}

function Copy-SecurityProviderAssemblyFromK2Server {
	param(
		[Parameter()]
		[string]$AssemblyName,
		[Parameter()]
		[string]$Destination
	)
	Copy-FromK2Server -Source (Join-Path -Path $script:K2BinPath -ChildPath "securityproviders\$($AssemblyName).dll") -Destination $Destination
}