<#
Applies server-settings.txt to the server's config files, or records values in it.

  Apply-Settings.cmd          sets every setting listed (except ? ones) in its config file
  Save-Current.cmd            fills in the ? values from the active realm's config files
  Save-From-CoA-Realm.cmd     fills in the ? values from the CoA realm's saved settings
                              (the manager keeps each inactive realm's configs in
                              Settings\realm-profiles\<realm>.json)

The manager rebuilds Core\configs\worldserver.conf from Settings\worldserver.conf.template, so
worldserver.conf settings are written to both. Every file changed is first copied to
Core\configs\settings-backup\<date-time>\.
#>
param(
    [switch] $Capture,
    [string] $Realm = '',
    [string] $Server = 'C:\Games\CoA Server',
    # Patch night: no 'Press Enter' at the end
    [switch] $Unattended
)
$ErrorActionPreference = 'Stop'

function Done([string] $message, [int] $code = 0) {
    Write-Host ''
    if ($code) { Write-Host $message -ForegroundColor Red } else { Write-Host $message -ForegroundColor Green }
    Write-Host ''
    if (-not $Unattended) { Read-Host 'Press Enter to close' | Out-Null }
    exit $code
}

# Any unexpected error: show it and wait, instead of closing the window.
trap { Done "The script stopped with an error:`n$_`nFiles are only saved at the very end; old copies of anything saved are in Core\configs\settings-backup." 1 }

$configs = Join-Path $Server 'Core\configs'
$template = Join-Path $Server 'Settings\worldserver.conf.template'
$listPath = Join-Path $PSScriptRoot 'server-settings.txt'
if (-not (Test-Path $configs)) { Done "No config folder at $configs." 1 }
if (-not (Test-Path $listPath)) { Done "server-settings.txt is missing; keep it next to this script." 1 }

$pattern = '^\s*([^|#]+?)\s*\|\s*([^=\s]+)\s*=\s*(.*?)\s*$'
$list = @(Get-Content $listPath)

function KeyPattern([string] $key) { '^\s*' + [regex]::Escape($key) + '\s*=' }

function CurrentValue([string[]] $lines, [string] $key) {
    $value = $null
    foreach ($line in $lines) {
        # the server reads the last line for a setting, so the last one counts
        if ($line -match ((KeyPattern $key) + '\s*(.*?)\s*$')) { $value = $Matches[1] }
    }
    return $value
}

# The real files behind one entry of the list: worldserver.conf and authserver.conf also have master copies.
function Targets([string] $file) {
    $paths = @(Join-Path $configs $file)
    # The manager keeps master copies of the two main configs and rebuilds the live files from them.
    $master = Join-Path $Server "Settings\$file.template"
    if ($file -in @('worldserver.conf', 'authserver.conf') -and (Test-Path $master)) { $paths = @($master) + $paths }
    return $paths
}

# Speed (22 Nov): each file is read once and indexed by setting name, so a setting is found by looking it up
# instead of testing every line of the file against it (261 settings x 2 copies of worldserver.conf took
# 3 minutes of patch night's downtime). The index lists the lines a setting is on, as KeyPattern would match them:
# not a comment, the name, optional spaces, then "="; names compare without regard to case, like -match.
$cache = @{}
$index = @{}
$lineKey = '^\s*([^#=\s][^=]*?)\s*='
function IndexLine([string] $path, [int] $i) {
    if ($cache[$path][$i] -match $lineKey) {
        $name = $Matches[1].ToLowerInvariant()
        if (-not $index[$path].ContainsKey($name)) { $index[$path][$name] = New-Object System.Collections.Generic.List[int] }
        $index[$path][$name].Add($i)
    }
}
function LinesOf([string] $path, [string] $key) {
    $found = $index[$path][$key.ToLowerInvariant()]
    if ($found) { return ,$found }
    return ,@()
}
# Encoding (22 Nov): Get-Content read these UTF-8 files as Windows-1252 and they were written back as UTF-8, so every
# write turned each non-ASCII character (an en dash in a comment, a Cyrillic addon prefix in a value) into several:
# after 16 writes playerbots.conf had grown from 240 KB to 22 MB, and one SQUID value no longer matched. Files are now
# read as UTF-8 (Windows-1252 only if they are not valid UTF-8) and written back in the encoding they were read in;
# lines already garbled are restored (Repair), which is exact: it undoes the same step as many times as it was done.
$encodings = @{}
$repaired = @{}
$utf8 = New-Object System.Text.UTF8Encoding($false, $true)
$ansi = [System.Text.Encoding]::GetEncoding(1252)
# Windows-1252 as Get-Content decoded it: bytes 0x80-0x9F are typographic characters (five are undefined and stay
# as their own code), every other byte is the character with the same code.
$cp1252High = 0x20AC,0x81,0x201A,0x0192,0x201E,0x2026,0x2020,0x2021,0x02C6,0x2030,0x0160,0x2039,0x0152,0x8D,0x017D,0x8F,
              0x90,0x2018,0x2019,0x201C,0x201D,0x2022,0x2013,0x2014,0x02DC,0x2122,0x0161,0x203A,0x0153,0x9D,0x017E,0x0178
# A .NET dictionary: a PowerShell hashtable would treat upper- and lower-case letters as the same key.
$toByte = New-Object 'System.Collections.Generic.Dictionary[char,byte]'
for ($b = 0; $b -lt 256; $b++) { $code = if ($b -ge 0x80 -and $b -le 0x9F) { $cp1252High[$b - 0x80] } else { $b }; $toByte[[char] $code] = [byte] $b }
function Repair([string] $line) {
    # Only a line showing the tell-tale A-tilde or A-circumflex of a UTF-8 character read as Windows-1252.
    while ($line.IndexOf([char] 0xC3) -ge 0 -or $line.IndexOf([char] 0xC2) -ge 0) {
        $bytes = New-Object byte[] $line.Length
        for ($i = 0; $i -lt $line.Length; $i++) {
            if (-not $toByte.ContainsKey($line[$i])) { return $line }
            $bytes[$i] = $toByte[$line[$i]]
        }
        try { $undone = $utf8.GetString($bytes) } catch { return $line }
        if ($undone -eq $line) { return $line }
        $line = $undone
    }
    return $line
}
function ReadPath([string] $path) {
    if (-not $cache.ContainsKey($path)) {
        $cache[$path] = $null
        if (Test-Path $path) {
            $bytes = [IO.File]::ReadAllBytes($path)
            $start = if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { 3 } else { 0 }
            try { $text = $utf8.GetString($bytes, $start, $bytes.Length - $start); $encodings[$path] = New-Object System.Text.UTF8Encoding($false) }
            catch { $text = $ansi.GetString($bytes); $encodings[$path] = $ansi }
            # Built step by step: an if-expression would unroll the list into a fixed-size array.
            $lines = New-Object System.Collections.ArrayList
            $fixed = 0
            foreach ($line in ($text -split "`r?`n")) {
                $restored = Repair $line
                if ($restored -ne $line) { $fixed++ }
                [void] $lines.Add($restored)
            }
            # A final line break leaves one empty piece at the end: it is not a line.
            if ($lines.Count -and $lines[$lines.Count - 1] -eq '' -and $text.EndsWith("`n")) { $lines.RemoveAt($lines.Count - 1) }
            if ($fixed) { $repaired[$path] = $fixed }
            $cache[$path] = $lines
            $index[$path] = @{}
            for ($i = 0; $i -lt $lines.Count; $i++) { IndexLine $path $i }
        }
    }
    # The comma keeps PowerShell from unrolling the list into a copy, so edits reach the cache.
    if ($null -eq $cache[$path]) { return $null }
    return ,$cache[$path]
}

# One config file out of a realm profile. The manager stores each file as a JSON list of bytes.
$profileText = $null
function ReadFromProfile([string] $file) {
    $isMain = $file -in @('worldserver.conf', 'authserver.conf')
    $rel = if ($isMain) { "Settings/$file.template" } else { 'Core/configs/' + ($file -replace '\\', '/') }
    $start = $profileText.IndexOf('"' + $rel + '"')
    if ($start -lt 0 -and $isMain) {
        $rel = "Core/configs/$file"
        $start = $profileText.IndexOf('"' + $rel + '"')
    }
    if ($start -lt 0) { return $null }
    $open = $profileText.IndexOf('[', $start)
    $close = $profileText.IndexOf(']', $open)
    $numbers = $profileText.Substring($open + 1, $close - $open - 1) -split '[^0-9]+' | Where-Object { $_ }
    $bytes = [byte[]] $numbers
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    return ,($text -split "`r?`n")
}

if ($Capture) {
    $source = 'the active realm'
    if ($Realm) {
        $profilePath = Join-Path $Server "Settings\realm-profiles\$Realm.json"
        if (-not (Test-Path $profilePath)) { Done "No saved settings for realm '$Realm' at $profilePath." 1 }
        $profileText = [IO.File]::ReadAllText($profilePath)
        $source = "the $Realm realm's saved settings"
    }
    $filled = 0; $missing = 0; $profileFiles = @{}
    for ($i = 0; $i -lt $list.Count; $i++) {
        if ($list[$i] -notmatch $pattern -or $Matches[3] -ne '?' -or $Matches[1] -ieq 'realmlist' -or $Matches[1] -ieq 'realm') { continue }
        $file = $Matches[1]; $key = $Matches[2]
        if ($Realm) {
            if (-not $profileFiles.ContainsKey($file)) { $profileFiles[$file] = ReadFromProfile $file }
            $lines = $profileFiles[$file]
        } else {
            $lines = ReadPath (Targets $file)[0]
        }
        $value = if ($lines) { CurrentValue $lines $key } else { $null }
        if ($null -eq $value) {
            Write-Host "  not found: $key in $file" -ForegroundColor Yellow
            $missing++
            continue
        }
        $list[$i] = "$file | $key = $value"
        Write-Host "  recorded:  $key = $value"
        $filled++
    }
    [IO.File]::WriteAllLines($listPath, [string[]] $list)
    Done "Recorded $filled value(s) from $source in server-settings.txt ($missing not found)."
}

# The list belongs to one realm ("realm | active = wildcard"): never apply it to another.
$forRealm = ''
foreach ($entry in $list) { if ($entry -match '^\s*realm\s*\|\s*active\s*=\s*(\S+)\s*$') { $forRealm = $Matches[1].ToLower() } }
if ($forRealm) {
    $realmFile = Join-Path $Server 'Settings\realm-profile.json'
    $activeRealm = if (Test-Path $realmFile) { [string] (Get-Content $realmFile -Raw | ConvertFrom-Json).active } else { 'coa' }
    if ($activeRealm.ToLower() -ne $forRealm) {
        Done "These settings are for the $forRealm realm, but the manager has the $activeRealm realm active. Nothing was changed." 1
    }
}

$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$backup = Join-Path $configs "settings-backup\$stamp"
$changedPaths = @{}
$changed = 0; $same = 0; $skipped = 0

foreach ($entry in $list) {
    if ($entry -notmatch $pattern) { continue }
    $file = $Matches[1]; $key = $Matches[2]; $value = $Matches[3]
    # realmlist | address is written to the database by patch night after each start, not to a config file.
    if ($file -ieq 'realmlist' -or $file -ieq 'realm') { continue }
    if ($value -eq '?') { $skipped++; continue }
    $wanted = "$key = $value"
    $any = $false; $differs = $false
    foreach ($path in Targets $file) {
        $lines = ReadPath $path
        if ($null -eq $lines) { continue }
        $any = $true
        $found = $false
        foreach ($i in (LinesOf $path $key)) {
            if ($lines[$i] -match (KeyPattern $key)) {
                $found = $true
                if ((CurrentValue @($lines[$i]) $key) -ne $value) { $lines[$i] = $wanted; $differs = $true; $changedPaths[$path] = $true }
            }
        }
        if (-not $found) { [void] $lines.Add($wanted); IndexLine $path ($lines.Count - 1); $differs = $true; $changedPaths[$path] = $true }
    }
    if (-not $any) { Write-Host "  no file:   $file (skipped $key)" -ForegroundColor Yellow; $skipped++; continue }
    if ($differs) { $changed++; Write-Host "  set:       $wanted  ($file)" } else { $same++ }
}

# Garbled lines restored on reading are saved too.
foreach ($path in $repaired.Keys) {
    $changedPaths[$path] = $true
    Write-Host "  repaired:  $($repaired[$path]) garbled line(s) in $(Split-Path $path -Leaf) ($([int] ((Get-Item $path).Length / 1KB)) KB before)"
}

foreach ($path in $changedPaths.Keys) {
    $copy = Join-Path $backup ($path.Substring($Server.Length).TrimStart('\'))
    New-Item -ItemType Directory -Force -Path (Split-Path $copy) | Out-Null
    Copy-Item $path $copy -Force
    # No byte-order mark: the server's config reader does not expect one. Same encoding as it was read in.
    [IO.File]::WriteAllLines($path, [string[]] $cache[$path], $encodings[$path])
}
# Backups: the newest 20 runs that changed something are kept.
Get-ChildItem (Join-Path $configs 'settings-backup') -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending |
    Select-Object -Skip 20 | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# Check (22 Nov): is each setting one the installed server knows? Every config file ships with a .dist copy listing
# the settings that version reads. A setting not in it was probably renamed or removed by an update, and the server
# ignores it. Settings the .dist lists that our file lacks are new options the server runs on defaults for (the
# server's own start-up warnings, which patch night adds to this report, show the same from the other side).
$report = New-Object System.Collections.Generic.List[string]
$report.Add("Settings check, $(Get-Date -Format 'yyyy-MM-dd HH:mm'): each setting in server-settings.txt against the .dist file the installed server shipped.")
$unknown = New-Object System.Collections.Generic.List[string]
$known = 0; $noDist = @{}
$distKeys = @{}
foreach ($entry in $list) {
    if ($entry -notmatch $pattern) { continue }
    $file = $Matches[1]; $key = $Matches[2]
    if ($file -ieq 'realmlist' -or $file -ieq 'realm') { continue }
    if (-not $distKeys.ContainsKey($file)) {
        $distKeys[$file] = $null
        $dist = Join-Path $configs "$file.dist"
        if (Test-Path $dist) {
            $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            # Commented-out examples ("#Key = value") count as known as well.
            foreach ($line in [IO.File]::ReadAllLines($dist)) { if ($line -match '^\s*#?\s*([A-Za-z][\w.\-]*)\s*=') { [void] $names.Add($Matches[1]) } }
            $distKeys[$file] = $names
        }
    }
    if ($null -eq $distKeys[$file]) { $noDist[$file] = $true; continue }
    if ($distKeys[$file].Contains($key)) { $known++ } else { $unknown.Add("$file | $key") }
}
# Our patched server reads settings of its own that the official .dist never lists (SQUID's Wildcard options, ...).
# A setting name the world server program contains is one it reads; only the rest are really unknown.
$ours = New-Object System.Collections.Generic.List[string]
$exePath = Join-Path $Server 'Core\worldserver.exe'
if ($unknown.Count -and (Test-Path $exePath)) {
    $program = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($exePath))
    foreach ($item in @($unknown)) {
        if ($program.IndexOf(($item -split '\|')[1].Trim(), [StringComparison]::Ordinal) -ge 0) { $ours.Add($item); [void] $unknown.Remove($item) }
    }
    $program = $null
}
$known += $ours.Count
$report.Add('')
$report.Add("Known to the server: $known ($($ours.Count) of them read by our patched server only, not in the official .dist).")
$report.Add("Unknown, in neither the .dist nor the server program (renamed or removed by an update? the server ignores these): $($unknown.Count).")
foreach ($line in $unknown) { $report.Add("  $line") }
if ($ours.Count) { $report.Add(''); $report.Add('Read by our patched server only:'); foreach ($line in $ours) { $report.Add("  $line") } }
if ($noDist.Count) { $report.Add(''); $report.Add("No .dist to check against (our own module configs): $(($noDist.Keys | Sort-Object) -join ', ').") }
$newOptions = New-Object System.Collections.Generic.List[string]
foreach ($file in ($distKeys.Keys | Sort-Object)) {
    if ($null -eq $distKeys[$file]) { continue }
    $live = ReadPath (Targets $file)[-1]
    if ($null -eq $live) { continue }
    $missing = @($distKeys[$file] | Where-Object { -not $index[(Targets $file)[-1]].ContainsKey($_.ToLowerInvariant()) } | Sort-Object)
    if ($missing.Count) { $newOptions.Add("  $file ($($missing.Count)): $($missing -join ', ')") }
}
$report.Add('')
$report.Add("Options the .dist lists that our config files do not set (the server uses its defaults; new in an update?):")
if ($newOptions.Count) { foreach ($line in $newOptions) { $report.Add($line) } } else { $report.Add('  none') }
[IO.File]::WriteAllLines((Join-Path $PSScriptRoot 'settings-report.txt'), [string[]] $report)
Write-Host "  checked:   $known known to the server, $($unknown.Count) unknown$(if ($unknown.Count) { ' (' + ($unknown -join '; ') + ')' }); report in settings-report.txt"

$note = if ($changed) { "Old copies are in $backup`nRestart the server in the manager to use them." } else { 'Nothing needed changing.' }
Done "Changed $changed setting(s), $same already right, $skipped skipped.`n$note"
