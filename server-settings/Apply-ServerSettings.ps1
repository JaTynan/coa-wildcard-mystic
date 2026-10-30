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

# The real files behind one entry of the list: worldserver.conf also has the manager's master copy.
function Targets([string] $file) {
    $paths = @(Join-Path $configs $file)
    if ($file -ieq 'worldserver.conf' -and (Test-Path $template)) { $paths = @($template) + $paths }
    return $paths
}

$cache = @{}
function ReadPath([string] $path) {
    if (-not $cache.ContainsKey($path)) {
        $cache[$path] = $null
        if (Test-Path $path) {
            # Built step by step: an if-expression would unroll the list into a fixed-size array.
            $lines = New-Object System.Collections.ArrayList
            foreach ($line in @(Get-Content $path)) { [void] $lines.Add($line) }
            $cache[$path] = $lines
        }
    }
    # The comma keeps PowerShell from unrolling the list into a copy, so edits reach the cache.
    if ($null -eq $cache[$path]) { return $null }
    return ,$cache[$path]
}

# One config file out of a realm profile. The manager stores each file as a JSON list of bytes.
$profileText = $null
function ReadFromProfile([string] $file) {
    $rel = if ($file -ieq 'worldserver.conf') { 'Settings/worldserver.conf.template' } else { 'Core/configs/' + ($file -replace '\\', '/') }
    $start = $profileText.IndexOf('"' + $rel + '"')
    if ($start -lt 0 -and $file -ieq 'worldserver.conf') {
        $rel = 'Core/configs/worldserver.conf'
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
        if ($list[$i] -notmatch $pattern -or $Matches[3] -ne '?') { continue }
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

$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$backup = Join-Path $configs "settings-backup\$stamp"
$changedPaths = @{}
$changed = 0; $same = 0; $skipped = 0

foreach ($entry in $list) {
    if ($entry -notmatch $pattern) { continue }
    $file = $Matches[1]; $key = $Matches[2]; $value = $Matches[3]
    if ($value -eq '?') { $skipped++; continue }
    $wanted = "$key = $value"
    $any = $false; $differs = $false
    foreach ($path in Targets $file) {
        $lines = ReadPath $path
        if ($null -eq $lines) { continue }
        $any = $true
        $found = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match (KeyPattern $key)) {
                $found = $true
                if ((CurrentValue @($lines[$i]) $key) -ne $value) { $lines[$i] = $wanted; $differs = $true; $changedPaths[$path] = $true }
            }
        }
        if (-not $found) { [void] $lines.Add($wanted); $differs = $true; $changedPaths[$path] = $true }
    }
    if (-not $any) { Write-Host "  no file:   $file (skipped $key)" -ForegroundColor Yellow; $skipped++; continue }
    if ($differs) { $changed++; Write-Host "  set:       $wanted  ($file)" } else { $same++ }
}

foreach ($path in $changedPaths.Keys) {
    $copy = Join-Path $backup ($path.Substring($Server.Length).TrimStart('\'))
    New-Item -ItemType Directory -Force -Path (Split-Path $copy) | Out-Null
    Copy-Item $path $copy -Force
    # No byte-order mark: the server's config reader does not expect one.
    [IO.File]::WriteAllLines($path, [string[]] $cache[$path])
}

$note = if ($changed) { "Old copies are in $backup`nRestart the server in the manager to use them." } else { 'Nothing needed changing.' }
Done "Changed $changed setting(s), $same already right, $skipped skipped.`n$note"
