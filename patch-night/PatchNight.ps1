<#
Patch night: keeps the server on the patched world server and James's settings, unattended.

Run weekly by the scheduled task (Register-PatchNight.cmd), or by hand (Run-PatchNight-Now.cmd).

  1. Finds which manager release is installed (from the official world server's revision).
  2. Looks for this repository's patched build of that release (GitHub Releases).
  3. Downloads this repository's current server-settings (edit them on GitHub, they apply here).
  4. Warns players in game, stops the server, installs the patched build if it is new,
     applies the settings, starts the server and checks it came up on the expected build.
  5. If the patched server does not come up, puts the official one back and starts that.

Everything is written to patch-night.log next to this script; last-run.txt holds the outcome
of the latest run. The manager's own Update button stays manual: click it any time before
patch night and this picks the new release up. Use at your own risk.
#>
param(
    [string] $Server = 'C:\Games\CoA Server',
    [string] $Repo = 'JaTynan/coa-wildcard-mystic',
    [int] $WarnMinutes = 10,
    [switch] $Unattended,
    # Start-Server.cmd: only apply the local settings and start the server (keeps SQUID's bots on Wildcard)
    [switch] $StartOnly
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$here = $PSScriptRoot
$work = Join-Path $here 'work'
$logFile = Join-Path $here 'patch-night.log'
$lastRun = Join-Path $here 'last-run.txt'
New-Item -ItemType Directory -Force -Path $work | Out-Null

$core = Join-Path $Server 'Core'
$live = Join-Path $core 'worldserver.exe'
$official = Join-Path $core 'worldserver.official.exe'
$marker = Join-Path $core 'worldserver.patched.txt'
$releaseRecord = Join-Path $core 'worldserver.patched-release.txt'
$python = Join-Path $Server 'Runtime\python\python.exe'
$manage = Join-Path $Server 'Scripts\manage.py'
$bridge = Join-Path $here 'launcher_bridge.py'
$serverLog = Join-Path $core 'Logs\Server.log'
$settingsDir = Join-Path $Server 'server-settings'
$headers = @{ 'User-Agent' = 'coa-patch-night' }

function Log([string] $message, [string] $level = 'INFO') {
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $level, $message
    Add-Content -Path $logFile -Value $line
    $colour = @{ INFO = 'Gray'; OK = 'Green'; WARN = 'Yellow'; FAIL = 'Red' }[$level]
    Write-Host $line -ForegroundColor $colour
}

function Finish([string] $outcome, [int] $code) {
    $level = if ($code) { 'FAIL' } else { 'OK' }
    Log $outcome $level
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  $outcome" | Set-Content -Path $lastRun -Encoding utf8
    Log '---- patch night finished ----'
    if (-not $Unattended) { Write-Host ''; Read-Host 'Press Enter to close' | Out-Null }
    exit $code
}

trap { Finish "Stopped with an unexpected error: $_" 1 }

function Revision([string] $exe) {
    # "AzerothCore rev. a76415e00eba+ 2026-10-28 ..." -> a76415e00eba
    $ErrorActionPreference = 'Continue'
    $text = (& $exe --version 2>&1 | Out-String)
    if ($LASTEXITCODE) { return $null }
    if ($text -match 'rev\.\s+([0-9a-f]{7,40})') { return $Matches[1] }
    return $null
}

function OfficialExe {
    # The live program is ours when it matches the hash Install.cmd recorded; the official one is then the saved copy.
    if ((Test-Path $marker) -and (Test-Path $official) -and
        ((Get-Content $marker -Raw).Trim() -eq (Get-FileHash $live).Hash)) { return $official }
    return $live
}

$script:callNumber = 0
function Invoke-Quiet([string] $file, [string[]] $arguments, [string] $stdin, [int] $minutes) {
    # Waits for this process only: Start-Process -Wait would also wait for the world server it starts,
    # which keeps running. Each call gets its own output files, since a started server can keep them open.
    $script:callNumber++
    $base = Join-Path $work ('call{0}' -f $script:callNumber)
    Set-Content -Path "$base.in" -Value $stdin -Encoding ascii
    $proc = Start-Process -FilePath $file -WorkingDirectory $Server -WindowStyle Hidden -PassThru `
        -ArgumentList $arguments -RedirectStandardInput "$base.in" -RedirectStandardOutput "$base.out" -RedirectStandardError "$base.err"
    $null = $proc.Handle   # keeps the exit code readable after the process ends
    if (-not $proc.WaitForExit($minutes * 60000)) {
        return @{ Code = -1; Text = "Timed out after $minutes minutes." }
    }
    $text = ((Get-Content "$base.out" -Raw -ErrorAction SilentlyContinue) + "`n" +
             (Get-Content "$base.err" -Raw -ErrorAction SilentlyContinue)).Trim()
    return @{ Code = $proc.ExitCode; Text = $text }
}

function Launcher([string] $verb, [string] $stdin = '', [int] $minutes = 5) {
    # The same way the manager runs its launcher: Runtime python, its bridge, Scripts\manage.py <verb>.
    return Invoke-Quiet $python @('-B', "`"$bridge`"", "`"$manage`"", $verb) $stdin $minutes
}

function Ra([string] $command) {
    $result = Launcher 'ra-once' $command
    return $result.Text
}

function WorldRunning { [bool] (Get-Process worldserver -ErrorAction SilentlyContinue) }

function StopServer {
    if (-not (WorldRunning)) { Log 'Server is already stopped.'; return }
    $result = Launcher 'stop-all'
    if ($result.Code) { throw "stop-all failed: $($result.Text)" }
    $deadline = (Get-Date).AddMinutes(5)
    while ((WorldRunning) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 5 }
    if (WorldRunning) { throw 'The world server did not stop within 5 minutes.' }
    Log 'Server stopped.'
}

function RestoreRealmAddress {
    # The launcher resets the realm list to 127.0.0.1 at every start; the manager then writes the "Play with
    # friends" address back (friends.rs, reapply). Do the same, or other computers see the realm but cannot join it.
    # 1. "realmlist | address = ..." in server-settings.txt, if set; 2. the manager's Play with friends address.
    $address = ''; $source = ''; $lan = $false
    $list = Join-Path $settingsDir 'server-settings.txt'
    if (Test-Path $list) {
        foreach ($line in Get-Content $list) {
            if ($line -match '^\s*realmlist\s*\|\s*address\s*=\s*(\S+)\s*$') { $address = $Matches[1]; $source = 'server-settings' }
        }
    }
    if (-not $address) {
        $friendsFile = "$Server.manager\friends.json"
        if (-not (Test-Path $friendsFile)) { Log 'No realm address in server-settings or Play with friends; the realm stays on this computer only.'; return }
        $friends = Get-Content $friendsFile -Raw | ConvertFrom-Json
        if ($friends.mode -eq 'local' -or -not $friends.host) { Log 'Play with friends is off; the realm stays on this computer only.'; return }
        $address = [string] $friends.host; $source = 'Play with friends'; $lan = $friends.mode -eq 'lan'
    }
    if ($address -notmatch '^[A-Za-z0-9.\-]+$') { Log "Unexpected realm address '$address' ($source); not applied." 'WARN'; return }
    # An address of this computer is a home-network address: also set it as the realm's local address, with its mask.
    if ($source -eq 'server-settings') { $lan = [bool] (Get-NetIPAddress -IPAddress $address -AddressFamily IPv4 -ErrorAction SilentlyContinue) }
    $local = ''
    if ($lan) {
        $ip = Get-NetIPAddress -IPAddress $address -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ip) {
            $bits = ('1' * $ip.PrefixLength).PadRight(32, '0')
            $mask = (0..3 | ForEach-Object { [Convert]::ToInt32($bits.Substring($_ * 8, 8), 2) }) -join '.'
            $local = ",localAddress='$address',localSubnetMask='$mask'"
        }
    }
    # The realms that run: the active one, plus any started together with it (realm-profile.json).
    $ids = @(1)
    $realmFile = Join-Path $Server 'Settings\realm-profile.json'
    if (Test-Path $realmFile) {
        $state = Get-Content $realmFile -Raw | ConvertFrom-Json
        $byMode = @{ coa = 1; wildcard = 2; reborn = 3 }
        $active = if ($state.active) { $byMode[[string] $state.active] } else { 1 }
        $ids = @($active)
        if ($state.simultaneous) { $ids += $(if ($active -eq 1) { 2 } else { 1 }) }
        if ($state.with_reborn) { $ids += 3 }
    }
    $sql = "UPDATE acore_auth.realmlist SET address='$address'$local WHERE id IN ($($ids -join ','));"
    $mysql = Join-Path $Server 'mysql\bin\mysql.exe'
    $ini = Join-Path $Server 'mysql\admin-client.ini'
    $result = Invoke-Quiet $mysql @("--defaults-file=`"$ini`"", '--batch', '--skip-column-names') $sql 2
    if ($result.Code) { Log "Could not set the realm address: $($result.Text)" 'WARN' }
    else { Log "Realm list points friends at $address again, from $source (realm $($ids -join ', '))." }
}

function StartAndCheck([string] $expected) {
    $started = Get-Date
    Log 'Starting the server (this waits until the world is up, up to 25 minutes)...'
    $result = Launcher 'start-all' '' 60
    if ($result.Code) { Log "start-all reported a problem: $($result.Text)" 'WARN'; return $false }
    RestoreRealmAddress
    # The world is up when this start's Server.log says so, from the expected build.
    $deadline = (Get-Date).AddMinutes(30)
    while ((Get-Date) -lt $deadline) {
        if ((Test-Path $serverLog) -and (Get-Item $serverLog).LastWriteTime -gt $started) {
            $text = Get-Content $serverLog -Raw
            if ($text -match 'World Initialized In') {
                $first = ($text -split "`r?`n")[0]
                if ($first -notmatch 'rev\.\s+([0-9a-f]{7,40})') { Log "Cannot read the revision in Server.log: $first" 'WARN'; return $false }
                $running = $Matches[1]
                if (-not ($expected.StartsWith($running) -or $running.StartsWith($expected))) {
                    Log "The server came up on core $running, expected $expected." 'WARN'; return $false
                }
                Start-Sleep -Seconds 60
                if (-not (WorldRunning)) { Log 'The world server stopped within a minute of starting.' 'WARN'; return $false }
                Log "Server is up on core $running."
                return $true
            }
        }
        if (-not (WorldRunning) -and (Get-Date) -gt $started.AddMinutes(2)) { Log 'The world server is not running.' 'WARN'; return $false }
        Start-Sleep -Seconds 15
    }
    Log 'The world did not finish loading within 30 minutes.' 'WARN'
    return $false
}

function RunScript([string] $path, [string[]] $arguments) {
    $result = Invoke-Quiet 'powershell.exe' (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$path`"") + $arguments) '' 10
    foreach ($line in ($result.Text -split "`r?`n")) { if ($line.Trim()) { Log "  $($line.Trim())" } }
    return $result.Code
}

if ($StartOnly) {
    Log '---- start server (Start-Server.cmd) ----'
    foreach ($needed in $live, $python, $manage, $bridge) {
        if (-not (Test-Path $needed)) { Finish "Missing $needed; nothing was changed." 1 }
    }
    if (WorldRunning) { Finish 'The server is already running. Stop it in the manager first to restart it with bots.' 1 }
    $applySettings = Join-Path $settingsDir 'Apply-ServerSettings.ps1'
    if (-not (Test-Path $applySettings)) { Finish "No settings kit at $settingsDir; nothing was changed." 1 }
    Log 'Applying server-settings...'
    if (RunScript $applySettings @('-Server', "`"$Server`"", '-Unattended')) { Log 'Applying the settings reported a problem.' 'WARN' }
    $expected = Revision $live
    if (-not $expected) { Finish "Cannot read the revision of $live." 1 }
    if (StartAndCheck $expected) { Finish "Server started on core $expected with your settings." 0 }
    Finish 'The server did not come up. See patch-night.log, or start it in the manager.' 1
}

Log '---- patch night started ----'
foreach ($needed in $live, $python, $manage, $bridge) {
    if (-not (Test-Path $needed)) { Finish "Missing $needed; nothing was changed." 1 }
}

# 1. Which release does the manager have installed?
$officialExe = OfficialExe
$installed = Revision $officialExe
if (-not $installed) { Finish "Cannot read the revision of $officialExe; nothing was changed." 1 }
Log "The manager's installed core is $installed (from $(Split-Path $officialExe -Leaf))."

# 2. Our patched build of that release, if GitHub has one.
$release = $null; $releaseCore = $null
try {
    $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases?per_page=50" -Headers $headers
    foreach ($candidate in $releases) {
        if ($candidate.draft -or $candidate.body -notmatch 'Core:\s+\S+\s+([0-9a-f]{40})') { continue }
        $sha = $Matches[1]
        if ($sha.StartsWith($installed)) { $release = $candidate; $releaseCore = $sha; break }
    }
} catch {
    Log "Cannot reach GitHub releases: $($_.Exception.Message)" 'WARN'
}
$liveIsOurs = (OfficialExe) -eq $official
$installedTag = if ((Test-Path $releaseRecord) -and $liveIsOurs) { (Get-Content $releaseRecord -Raw).Trim() } else { '' }
$installNeeded = $false
if ($release) {
    Log "Patched build available: $($release.tag_name)."
    $installNeeded = $release.tag_name -ne $installedTag
    if (-not $installNeeded) { Log 'It is already installed.' }
} elseif ($liveIsOurs) {
    Log 'No patched build found for this core, but the installed patched server matches it already.' 'WARN'
} else {
    Log "No patched build for core $installed yet; the official server keeps running (no Mystic Enchants on Wildcard)." 'WARN'
}

# 3. This repository's current settings (falls back to the local copy).
$repoInstaller = $null
try {
    $zip = Join-Path $work 'repo.zip'
    Invoke-WebRequest -Uri "https://github.com/$Repo/archive/refs/heads/main.zip" -OutFile $zip -Headers $headers -UseBasicParsing
    $repoDir = Join-Path $work 'repo'
    if (Test-Path $repoDir) { Remove-Item $repoDir -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $repoDir -Force
    $repoRoot = Get-ChildItem $repoDir -Directory | Select-Object -First 1 | ForEach-Object { $_.FullName }
    $repoInstaller = Join-Path $repoRoot 'vm\Install-WildcardServer.ps1'
    $fresh = Join-Path $repoRoot 'server-settings'
    if ($fresh -and (Test-Path (Join-Path $fresh 'server-settings.txt'))) {
        New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
        Copy-Item (Join-Path $fresh '*') $settingsDir -Force
        Log 'Downloaded the current server-settings from GitHub.'
    }
} catch {
    Log "Cannot download the settings from GitHub ($($_.Exception.Message)); using the local copy." 'WARN'
}
$applySettings = Join-Path $settingsDir 'Apply-ServerSettings.ps1'
if (-not (Test-Path $applySettings)) { Finish "No settings kit at $settingsDir; nothing was changed." 1 }

# Download the patched build before taking the server down.
$package = $null
if ($installNeeded) {
    $asset = $release.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
    if (-not $asset) { Finish "Release $($release.tag_name) has no zip; nothing was changed." 1 }
    $zip = Join-Path $work $asset.name
    Log "Downloading $($asset.name) ($([int]($asset.size / 1MB)) MB)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -Headers $headers -UseBasicParsing
    $package = Join-Path $work 'package'
    if (Test-Path $package) { Remove-Item $package -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $package -Force
    if (-not (Test-Path (Join-Path $package 'Install-WildcardServer.ps1'))) { Finish 'The downloaded package has no installer; nothing was changed.' 1 }
}

# 4. Warn players, stop, install, apply settings, start, check.
if (WorldRunning) {
    $info = Ra 'server info'
    $players = if ($info -match 'Connected players:\s*(\d+)') { [int] $Matches[1] } else { -1 }
    if ($players -ne 0 -and $WarnMinutes -gt 0) {
        Log "Players online: $(if ($players -lt 0) { 'unknown' } else { $players }). Warning them $WarnMinutes minutes ahead."
        Ra "announce Patch night: the server restarts in $WarnMinutes minutes for maintenance." | Out-Null
        Start-Sleep -Seconds (60 * ($WarnMinutes - 1))
        Ra 'announce Patch night: the server restarts in 1 minute. Find a safe spot!' | Out-Null
        Start-Sleep -Seconds 60
    } else {
        Log 'No players online.'
    }
}
StopServer

$expected = $installed
if ($installNeeded) {
    Log "Installing $($release.tag_name)..."
    # The newest installer from this repository (it knows -Unattended), pointed at the downloaded build.
    $installer = if ($repoInstaller -and (Test-Path $repoInstaller)) { $repoInstaller } else { Join-Path $package 'Install-WildcardServer.ps1' }
    $code = RunScript $installer @('-Server', "`"$Server`"", '-Package', "`"$package`"", '-Unattended')
    if ($code) {
        Log 'The installer refused or failed; continuing with the server as it was.' 'WARN'
        $installNeeded = $false
    } else {
        $release.tag_name | Set-Content -Path $releaseRecord -Encoding ascii
        $expected = $releaseCore
    }
} elseif ($liveIsOurs -and $release) {
    $expected = $releaseCore
}

Log 'Applying server-settings...'
if (RunScript $applySettings @('-Server', "`"$Server`"", '-Unattended')) { Log 'Applying the settings reported a problem.' 'WARN' }

if (StartAndCheck $expected) {
    $what = if ($installNeeded) { "installed $($release.tag_name)" } elseif ((OfficialExe) -eq $official) { 'patched server unchanged' } else { 'official server (no patched build yet)' }
    Finish "Patch night OK: $what, settings checked, server up on core $expected." 0
}

# 5. The patched server did not come up: back to the official one.
if ((OfficialExe) -eq $official) {
    Log 'Putting the official world server back...' 'WARN'
    StopServer
    Copy-Item $official $live -Force
    Remove-Item $marker -ErrorAction SilentlyContinue
    Remove-Item $releaseRecord -ErrorAction SilentlyContinue
    if (StartAndCheck $installed) { Finish 'Patch night FAILED on the patched server; the official server is running instead (no Mystic Enchants). See patch-night.log.' 1 }
}
Finish 'Patch night FAILED: the server is not up. Start it in the manager and check patch-night.log.' 1
