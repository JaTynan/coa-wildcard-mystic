<#
Publishes the friends' download site from the VM: the launcher, its settings and the client manifest.

The site folder (default F:\wildcard-site) is what the web server serves at the root; the client folder
(default F:\CoAClient) is served under /client/. Run by patch night after it updates the client folder,
or by hand after changing the client (for example after a client update in the manager).

  - launcher.json    realm address, first-install archive link and size, current launcher version
  - manifest.json    every client file with its size, MD5 and modified time (personal folders left out)
  - WildcardLauncher.zip, WildcardLauncher.ps1, and the site folder (index.html, how-to-play.html, images)
  - changelog.json   the last week of merged pull requests, by day, for the homepage's "Recent changes". A PR body
                     line "Changelog: <text>" replaces its title there; "Changelog: skip" leaves it out.
#>
param(
    [string] $Client = 'F:\CoAClient',
    [string] $Site = 'F:\wildcard-site',
    [string] $Settings = (Join-Path $PSScriptRoot 'launcher-settings.json'),
    [string] $Repo = 'JaTynan/coa-wildcard-mystic',
    [int] $ChangelogDays = 7
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
# The whole site folder: pages (index.html, how-to-play.html) and images.
Copy-Item (Join-Path $PSScriptRoot 'site\*') $Site -Recurse -Force

# ---------------------------------------------------------------- changelog (a GitHub hiccup keeps the last one)
$changeCount = 0
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
try {
    $since = (Get-Date).Date.AddDays(1 - $ChangelogDays)
    # Windows PowerShell hands back a top-level JSON array as ONE object; assigning it directly (no @(), which would
    # nest it) keeps the array itself, so foreach sees each pull request.
    $pulls = Invoke-RestMethod -UseBasicParsing -Headers @{ 'User-Agent' = 'wildcard-site' } `
        -Uri "https://api.github.com/repos/$Repo/pulls?state=closed&base=main&sort=updated&direction=desc&per_page=100"
    $entries = New-Object Collections.Generic.List[object]
    foreach ($pull in $pulls) {
        if (-not $pull.merged_at) { continue }
        # Windows PowerShell may already have turned the date into a DateTime; otherwise parse GitHub's ISO text.
        $merged = if ($pull.merged_at -is [datetime]) { $pull.merged_at.ToLocalTime() }
                  else { [DateTimeOffset]::Parse([string] $pull.merged_at, [Globalization.CultureInfo]::InvariantCulture).ToLocalTime().DateTime }
        if ($merged -lt $since) { continue }
        $text = [string] $pull.title
        if ([string] $pull.body -match '(?m)^Changelog:[ \t]*(.+?)\s*$') {
            if ($Matches[1] -ieq 'skip') { continue }
            $text = $Matches[1]
        }
        $entries.Add([pscustomobject] @{ merged = $merged; text = $text; number = [int] $pull.number })
    }
    $days = New-Object Collections.Generic.List[object]
    foreach ($group in ($entries | Sort-Object merged -Descending | Group-Object { $_.merged.ToString('yyyy-MM-dd') } | Sort-Object Name -Descending)) {
        $first = $group.Group[0].merged
        $items = @($group.Group | ForEach-Object { [pscustomobject] @{ text = $_.text; number = $_.number } })
        $days.Add([pscustomobject] @{ date = $group.Name; label = $first.ToString('dddd d MMMM'); items = $items })
    }
    $changeCount = $entries.Count
    $changelog = [pscustomobject] @{ generated = (Get-Date).ToUniversalTime().ToString('o'); days = $days.ToArray() }
    ConvertTo-Json -InputObject $changelog -Depth 5 | Set-Content (Join-Path $Site 'changelog.json') -Encoding UTF8
}
catch { $changeCount = -1; $changeError = $_.Exception.Message }
$stage = Join-Path $env:TEMP 'wildcard-launcher'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'WildcardLauncher.ps1'), (Join-Path $PSScriptRoot 'Start Wildcard.cmd') $stage
Set-Content (Join-Path $stage 'launcher-site.txt') $config.site -Encoding ASCII
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath (Join-Path $Site 'WildcardLauncher.zip') -Force
Remove-Item $stage -Recurse -Force

$changes = if ($changeCount -lt 0) { "changelog not refreshed ($changeError)" } else { "$changeCount change(s) in the last $ChangelogDays days" }
"Published {0} client files ({1:N1} GB), launcher version {2}, {3}, to {4}." -f $files.Count, (($files | Measure-Object -Property size -Sum).Sum / 1GB), $launcherVersion, $changes, $Site
