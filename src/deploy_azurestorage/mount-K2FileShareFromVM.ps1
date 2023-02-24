param(
    [Parameter()]
    [string]$AccountStorageKey,
    [string]$AccountStorageName,
    [string]$FileShareName
)

cmdkey /add:$($AccountStorageName).file.core.windows.net /user:$($AccountStorageName) /pass:$AccountStorageKey
net use Z: \\$($AccountStorageName).file.core.windows.net\$($FileShareName)