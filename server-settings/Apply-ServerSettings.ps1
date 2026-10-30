<#
Applies server-settings.txt to the server's config files, or records the server's current values in it.

  Apply-Settings.cmd  sets every setting listed (except ? ones) in its config file
  Save-Current.cmd    fills in the ? values from the config files as they are now

Every file changed is first copied to Core\configs\settings-backup\<date-time>\.
#>
param(
    [switch] $Capture,
    [string] $Server = 'C:\Games\CoA Server'
)
$ErrorActionPreference = 'Stop'

function Done([string] $message, [int] $code = 0) {
    Write-Host ''
    if ($code) { Write-Host $message -ForegroundColor Red } else { Write-Host $message -ForegroundColor Green }
    Write-Host ''
    Read-Host 'Press Enter to close'
    exit $code
}

$configs = Join-Path $Server 'Core\configs'
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

$cache = @{}
function ReadConf([string] $file) {
    if (-not $cache.ContainsKey($file)) {
        $path = Join-Path $configs $file
        $cache[$file] = if (Test-Path $path) { [System.Collections.ArrayList]@(Get-Content $path) } else { $null }
    }
    # The comma keeps PowerShell from unrolling the list into a copy, so edits reach the cache.
    if ($null -eq $cache[$file]) { return $null }
    return ,$cache[$file]
}

if ($Capture) {
    $filled = 0; $missing = 0
    for ($i = 0; $i -lt $list.Count; $i++) {
        if ($list[$i] -notmatch $pattern -or $Matches[3] -ne '?') { continue }
        $file = $Matches[1]; $key = $Matches[2]
        $lines = ReadConf $file
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
    Done "Recorded $filled value(s) in server-settings.txt ($missing not found)."
}

$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$backup = Join-Path $configs "settings-backup\$stamp"
$changedFiles = @{}
$changed = 0; $same = 0; $skipped = 0

foreach ($entry in $list) {
    if ($entry -notmatch $pattern) { continue }
    $file = $Matches[1]; $key = $Matches[2]; $value = $Matches[3]
    if ($value -eq '?') { $skipped++; continue }
    $lines = ReadConf $file
    if ($null -eq $lines) { Write-Host "  no file:   $file (skipped $key)" -ForegroundColor Yellow; $skipped++; continue }

    $wanted = "$key = $value"
    $found = $false; $differs = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match (KeyPattern $key)) {
            $found = $true
            if ($lines[$i].Trim() -ne $wanted -and (CurrentValue @($lines[$i]) $key) -ne $value) {
                $lines[$i] = $wanted; $differs = $true
            }
        }
    }
    if (-not $found) { [void] $lines.Add($wanted); $differs = $true }
    if ($differs) { $changedFiles[$file] = $true; $changed++; Write-Host "  set:       $wanted  ($file)" }
    else { $same++ }
}

foreach ($file in $changedFiles.Keys) {
    $path = Join-Path $configs $file
    $copy = Join-Path $backup $file
    New-Item -ItemType Directory -Force -Path (Split-Path $copy) | Out-Null
    Copy-Item $path $copy -Force
    # No byte-order mark: the server's config reader does not expect one.
    [IO.File]::WriteAllLines($path, [string[]] $cache[$file])
}

$note = if ($changed) { "Old copies are in $backup`nRestart the server in the manager (or .reload config) to use them." } else { 'Nothing needed changing.' }
Done "Changed $changed setting(s), $same already right, $skipped skipped.`n$note"
