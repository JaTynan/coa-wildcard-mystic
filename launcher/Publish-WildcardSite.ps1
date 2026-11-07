<#
Publishes the friends' download site from the VM: the launcher, its settings and the client manifest.

The site folder (default F:\wildcard-site) is what the web server serves at the root; the client folder
(default F:\CoAClient) is served under /client/. Run by patch night after it updates the client folder,
or by hand after changing the client (for example after a client update in the manager).

  - launcher.json    realm address, first-install archive link and size, current launcher version
  - manifest.json    every client file with its size, MD5 and modified time (personal folders left out)
  - WildcardLauncher.zip, WildcardLauncher.ps1, index.html
#>
param(
    [string] $Client = 'F:\CoAClient',
    [string] $Site = 'F:\wildcard-site',
    [string] $Settings = (Join-Path $PSScriptRoot 'launcher-settings.json')
)
$ErrorActionPreference = 'Stop'

$skipFolders = @('WTF', 'Cache', 'Logs', 'Errors', 'Screenshots')
New-Item -ItemType Directory -Force -Path $Site | Out-Null
$config = Get-Content $Settings -Raw | ConvertFrom-Json

# ---------------------------------------------------------------- manifest (hashes reused while size and time match)
$cacheFile = Join-Path $Site '.hash-cache.json'
$cache = @{}
if (Test-Path $cacheFile) {
    try { (Get-Content $cacheFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $cache[$_.Name] = $_.Value } } catch { }
}
$md5 = [Security.Cryptography.MD5]::Create()
$root = (Resolve-Path $Client).Path.TrimEnd('\')
$files = New-Object Collections.Generic.List[object]
$newCache = @{}
foreach ($item in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
    $relative = $item.FullName.Substring($root.Length + 1)
    if ($skipFolders -contains ($relative -split '\\')[0]) { continue }
    if ($item.Name -ieq 'realmlist.wtf') { continue }   # the launcher writes its own (the server address)
    if ($item.Name -ieq 'web.config') { continue }      # IIS's own settings for /client; IIS never serves it
    $stamp = "$($item.Length)|$($item.LastWriteTimeUtc.Ticks)"
    $known = $cache[$relative]
    if ($known -and $known.stamp -eq $stamp) { $hash = $known.md5 }
    else {
        $stream = [IO.File]::OpenRead($item.FullName)
        try { $hash = ([BitConverter]::ToString($md5.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
        finally { $stream.Close() }
    }
    $newCache[$relative] = [pscustomobject] @{ stamp = $stamp; md5 = $hash }
    $mtime = ([DateTimeOffset] [datetime]::SpecifyKind($item.LastWriteTimeUtc, 'Utc')).ToUnixTimeSeconds()
    $files.Add([pscustomobject] @{ path = $relative; size = $item.Length; md5 = $hash; mtime = $mtime })
}
$md5.Dispose()
$manifest = [pscustomobject] @{ generated = (Get-Date).ToUniversalTime().ToString('o'); files = $files; remove = @($config.remove) }
$manifest | ConvertTo-Json -Depth 4 -Compress | Set-Content (Join-Path $Site 'manifest.json.new') -Encoding UTF8
Move-Item (Join-Path $Site 'manifest.json.new') (Join-Path $Site 'manifest.json') -Force
$newCache | ConvertTo-Json -Depth 3 -Compress | Set-Content $cacheFile -Encoding UTF8

# ---------------------------------------------------------------- launcher and page
$launcherVersion = [int] ((Select-String -Path (Join-Path $PSScriptRoot 'WildcardLauncher.ps1') -Pattern '^\$LauncherVersion = (\d+)').Matches[0].Groups[1].Value)
[pscustomobject] @{
    realm = $config.realm
    clientArchiveUrl = $config.clientArchiveUrl
    clientArchiveBytes = [long] $config.clientArchiveBytes
    launcherVersion = $launcherVersion
} | ConvertTo-Json | Set-Content (Join-Path $Site 'launcher.json') -Encoding UTF8

Copy-Item (Join-Path $PSScriptRoot 'WildcardLauncher.ps1') $Site -Force
Copy-Item (Join-Path $PSScriptRoot 'site\index.html') $Site -Force
$stage = Join-Path $env:TEMP 'wildcard-launcher'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'WildcardLauncher.ps1'), (Join-Path $PSScriptRoot 'Start Wildcard.cmd') $stage
Set-Content (Join-Path $stage 'launcher-site.txt') $config.site -Encoding ASCII
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath (Join-Path $Site 'WildcardLauncher.zip') -Force
Remove-Item $stage -Recurse -Force

"Published {0} client files ({1:N1} GB), launcher version {2}, to {3}." -f $files.Count, (($files | Measure-Object -Property size -Sum).Sum / 1GB), $launcherVersion, $Site
