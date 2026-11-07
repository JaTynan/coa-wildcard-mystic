<#
Wildcard launcher: keeps a friend's copy of the client up to date with James's server, then starts the game.

  1. Reads launcher.json from the server's site (the site address is in launcher-site.txt next to this file).
  2. Updates itself if the site has a newer launcher.
  3. First run: downloads the whole client (one archive, from the seedbox), resuming if interrupted, and unpacks it.
  4. Every run: compares the client with the site's manifest and downloads only the files that differ. A file
     whose size and modified time match the manifest is taken as current; others are checked by MD5.
  5. Points the game at the server (realmList in WTF\Config.wtf and realmlist.wtf in each Data\<locale>
     folder, which the game reads first), then the Play button starts it.

If the site cannot be reached, the game can still be started with whatever is installed.
Every step and error goes to launcher.log next to this file (the Log button opens it), and the window says
whether the game server itself is reachable.
#>
$LauncherVersion = 5
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$here = $PSScriptRoot
$clientDir = Join-Path $here 'CoAClient'
$stateFile = Join-Path $here 'launcher-state.json'
$siteFile = Join-Path $here 'launcher-site.txt'
$secretFile = Join-Path $here 'launcher-secret.json'
$logFile = Join-Path $here 'launcher.log'
$site = if (Test-Path $siteFile) { (Get-Content $siteFile -Raw).Trim().TrimEnd('/') } else { 'https://wildcard.jtlab.cc' }
$headers = @{}
if (Test-Path $secretFile) {
    $secret = Get-Content $secretFile -Raw | ConvertFrom-Json
    if ($secret.id) { $headers['CF-Access-Client-Id'] = $secret.id; $headers['CF-Access-Client-Secret'] = $secret.secret }
}

# ------------------------------------------------------------------ window
$form = New-Object Windows.Forms.Form
$form.Text = 'Wildcard'
$form.Size = New-Object Drawing.Size(520, 250)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = [Drawing.Color]::FromArgb(24, 24, 28)
$form.ForeColor = [Drawing.Color]::Gainsboro

$title = New-Object Windows.Forms.Label
$title.Text = 'Wildcard'
$title.Font = New-Object Drawing.Font('Segoe UI', 18, [Drawing.FontStyle]::Bold)
$title.ForeColor = [Drawing.Color]::FromArgb(230, 180, 60)
$title.Location = New-Object Drawing.Point(20, 12)
$title.AutoSize = $true
$form.Controls.Add($title)

$status = New-Object Windows.Forms.Label
$status.Text = 'Starting...'
$status.Font = New-Object Drawing.Font('Segoe UI', 10)
$status.Location = New-Object Drawing.Point(22, 62)
$status.Size = New-Object Drawing.Size(470, 40)
$form.Controls.Add($status)

$bar = New-Object Windows.Forms.ProgressBar
$bar.Location = New-Object Drawing.Point(22, 108)
$bar.Size = New-Object Drawing.Size(470, 22)
$bar.Maximum = 1000
$form.Controls.Add($bar)

$play = New-Object Windows.Forms.Button
$play.Text = 'Play'
$play.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
$play.Location = New-Object Drawing.Point(372, 162)
$play.Size = New-Object Drawing.Size(120, 38)
$play.Enabled = $false
$play.FlatStyle = 'Flat'
$play.BackColor = [Drawing.Color]::FromArgb(230, 180, 60)
$play.ForeColor = [Drawing.Color]::Black
$form.Controls.Add($play)

$server = New-Object Windows.Forms.Label
$server.Text = ''
$server.Font = New-Object Drawing.Font('Segoe UI', 9)
$server.ForeColor = [Drawing.Color]::DarkGray
$server.Location = New-Object Drawing.Point(22, 136)
$server.Size = New-Object Drawing.Size(470, 20)
$form.Controls.Add($server)

$logButton = New-Object Windows.Forms.Button
$logButton.Text = 'Log'
$logButton.Font = New-Object Drawing.Font('Segoe UI', 9)
$logButton.Location = New-Object Drawing.Point(22, 168)
$logButton.Size = New-Object Drawing.Size(70, 28)
$logButton.FlatStyle = 'Flat'
$logButton.ForeColor = [Drawing.Color]::Gainsboro
$logButton.Add_Click({ if (Test-Path $logFile) { Start-Process notepad.exe "`"$logFile`"" } })
$form.Controls.Add($logButton)

function Log([string] $text) {
    try { Add-Content -Path $logFile -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $text) -Encoding UTF8 } catch { }
}
function Say([string] $text) { $status.Text = $text; [Windows.Forms.Application]::DoEvents() }
function Step([string] $text) { Log $text; Say $text }
function Progress([double] $fraction) {
    $bar.Style = 'Blocks'
    $bar.Value = [int] [Math]::Max([double] 0, [Math]::Min([double] 1000, [double] $fraction * 1000))
    [Windows.Forms.Application]::DoEvents()
}
function Busy { $bar.Style = 'Marquee'; [Windows.Forms.Application]::DoEvents() }
function Size([double] $bytes) {
    if ($bytes -ge 1GB) { return '{0:N1} GB' -f ($bytes / 1GB) }
    return '{0:N0} MB' -f ($bytes / 1MB)
}

# ------------------------------------------------------------------ web
# A plain-English reason for a failed download, for the window and the log.
function Explain($exception, [string] $url) {
    $host_ = $url
    if ($url -match '^https?://([^/:]+)') { $host_ = $Matches[1] }
    $web = $exception
    while ($web -and -not ($web -is [Net.WebException])) { $web = $web.InnerException }
    if ($web) {
        switch ($web.Status) {
            'NameResolutionFailure' { return "cannot find $host_ (no internet, or the address is wrong)" }
            'ConnectFailure' { return "cannot connect to $host_ (no internet, or a firewall is blocking it)" }
            'RequestCanceled' { return "$host_ did not answer within 20 seconds (slow connection, or James's server is down)" }
            'Timeout' { return "$host_ did not answer in time (slow connection, or James's server is busy)" }
            'TrustFailure' { return "the secure connection to $host_ failed (check the PC's date and time)" }
            'ProtocolError' {
                $code = [int] $web.Response.StatusCode
                if ($code -eq 404) { return "$host_ does not have that file (HTTP 404); tell James" }
                if ($code -ge 500) { return "James's site is down right now (HTTP $code); try again later or tell James" }
                return "$host_ refused the request (HTTP $code); tell James"
            }
        }
    }
    return $exception.Message
}

function Get-Json([string] $url) {
    $request = [Net.HttpWebRequest]::Create($url)
    foreach ($key in $headers.Keys) { $request.Headers.Add($key, $headers[$key]) }
    $request.Timeout = 20000
    $pending = $request.BeginGetResponse($null, $null)
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while (-not $pending.AsyncWaitHandle.WaitOne(100)) {
        [Windows.Forms.Application]::DoEvents()
        if ($clock.ElapsedMilliseconds -gt 20000) { $request.Abort() }
    }
    try { $response = $request.EndGetResponse($pending) }
    catch { throw (New-Object Exception((Explain $_.Exception $url), $_.Exception)) }
    try { return (New-Object IO.StreamReader($response.GetResponseStream())).ReadToEnd() | ConvertFrom-Json }
    finally { $response.Close() }
}

function Get-File([string] $url, [string] $path, [string] $label, [bool] $sendHeaders = $true) {
    $partial = "$path.part"
    $have = if (Test-Path $partial) { (Get-Item $partial).Length } else { 0 }
    $request = [Net.HttpWebRequest]::Create($url)
    if ($sendHeaders) { foreach ($key in $headers.Keys) { $request.Headers.Add($key, $headers[$key]) } }
    $request.Timeout = 30000
    $request.ReadWriteTimeout = 60000
    if ($have -gt 0) { Log "Resuming $label at $(Size $have)" }
    if ($have -gt 0) { $request.AddRange([long] $have) }
    try { $response = $request.GetResponse() }
    catch { Log "Download failed: $url ($($_.Exception.Message))"; throw (New-Object Exception((Explain $_.Exception $url), $_.Exception)) }
    try {
        if ($have -gt 0 -and [int] $response.StatusCode -ne 206) { $have = 0 }
        $total = $have + $response.ContentLength
        $mode = if ($have -gt 0) { [IO.FileMode]::Append } else { [IO.FileMode]::Create }
        $out = New-Object IO.FileStream($partial, $mode)
        $in = $response.GetResponseStream()
        $buffer = New-Object byte[] 1048576
        $done = $have
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $last = 0
        try {
            while (($read = $in.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $out.Write($buffer, 0, $read)
                $done += $read
                if ($clock.ElapsedMilliseconds - $last -ge 250) {
                    $last = $clock.ElapsedMilliseconds
                    $speed = ($done - $have) / [Math]::Max([double] 1, [double] $clock.Elapsed.TotalSeconds)
                    $left = if ($speed -gt 0 -and $total -gt 0) { [TimeSpan]::FromSeconds(($total - $done) / $speed) } else { [TimeSpan]::Zero }
                    Say ("{0}: {1} of {2}, {3}/s, about {4:hh\:mm\:ss} left" -f $label, (Size $done), (Size $total), (Size $speed), $left)
                    if ($total -gt 0) { Progress ($done / $total) }
                }
            }
        }
        finally { $out.Close(); $in.Close() }
    }
    finally { $response.Close() }
    if (Test-Path $path) { Remove-Item $path -Force }
    Move-Item $partial $path
}

# ------------------------------------------------------------------ files
# Reads in 4 MB pieces so the window keeps responding (and shows progress) on multi-GB files.
$script:checkedBytes = 0
$script:checkTotal = 0
function Get-Md5([string] $path) {
    $md5 = [Security.Cryptography.MD5]::Create()
    $stream = [IO.File]::OpenRead($path)
    $buffer = New-Object byte[] 4194304
    $name = Split-Path $path -Leaf
    try {
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $null = $md5.TransformBlock($buffer, 0, $read, $null, 0)
            $script:checkedBytes += $read
            if ($script:checkTotal -gt 0) {
                Say ("Checking your game files: {0} of {1} ({2})" -f (Size $script:checkedBytes), (Size $script:checkTotal), $name)
                Progress ($script:checkedBytes / $script:checkTotal)
            }
            else { [Windows.Forms.Application]::DoEvents() }
        }
        $null = $md5.TransformFinalBlock($buffer, 0, 0)
        return ([BitConverter]::ToString($md5.Hash)).Replace('-', '').ToLowerInvariant()
    }
    finally { $stream.Close(); $md5.Dispose() }
}

function Unix-Seconds([datetime] $utc) { ([DateTimeOffset] [datetime]::SpecifyKind($utc, 'Utc')).ToUnixTimeSeconds() }

function Read-State {
    $state = @{}
    if (Test-Path $stateFile) {
        try {
            (Get-Content $stateFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $state[$_.Name] = $_.Value }
        } catch { }
    }
    return $state
}

function Save-State($state) { $state | ConvertTo-Json -Depth 3 -Compress | Set-Content $stateFile -Encoding UTF8 }

# The MD5 of a local file, reusing the last result while its size and modified time are unchanged. A file with
# the manifest's size and modified time (to the second, as the archive and downloads keep them) is taken as its MD5.
function Local-Hash($state, [string] $relative, $expected = $null) {
    $path = Join-Path $clientDir $relative
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $item = Get-Item -LiteralPath $path
    $stamp = "$($item.Length)|$($item.LastWriteTimeUtc.Ticks)"
    $known = $state[$relative]
    if ($known -and $known.stamp -eq $stamp) { return $known.md5 }
    if ($expected -and $expected.mtime -and $item.Length -eq [long] $expected.size -and
        (Unix-Seconds $item.LastWriteTimeUtc) -eq [long] $expected.mtime) {
        $state[$relative] = [pscustomobject] @{ stamp = $stamp; md5 = $expected.md5 }
        return $expected.md5
    }
    $hash = Get-Md5 $path
    $state[$relative] = [pscustomobject] @{ stamp = $stamp; md5 = $hash }
    return $hash
}

function Set-Realm([string] $realm) {
    $wtf = Join-Path $clientDir 'WTF'
    New-Item -ItemType Directory -Force -Path $wtf | Out-Null
    $config = Join-Path $wtf 'Config.wtf'
    $lines = @()
    if (Test-Path $config) { $lines = @(Get-Content $config | Where-Object { $_ -notmatch '^\s*SET\s+realmList\s' }) }
    $lines += "SET realmList `"$realm`""
    Set-Content $config $lines -Encoding ASCII
    # The game reads Data\<locale>\realmlist.wtf over Config.wtf; set it in every locale folder (enUS, enGB, ...).
    $data = Join-Path $clientDir 'Data'
    $locales = @(Get-ChildItem $data -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -cmatch '^[a-z]{2}[A-Z]{2}$' })
    if (-not $locales.Count) { $locales = @(New-Item -ItemType Directory -Force -Path (Join-Path $data 'enUS')) }
    foreach ($locale in $locales) { Set-Content (Join-Path $locale.FullName 'realmlist.wtf') "set realmlist $realm" -Encoding ASCII }
}

# ------------------------------------------------------------------ steps
function Update-Self($info) {
    if (-not $info.launcherVersion -or [int] $info.launcherVersion -le $LauncherVersion) { return $false }
    Step "Updating the launcher to version $($info.launcherVersion)..."
    $new = Join-Path $here 'WildcardLauncher.ps1.new'
    Get-File "$site/WildcardLauncher.ps1" $new 'Launcher'
    Move-Item $new (Join-Path $here 'WildcardLauncher.ps1') -Force
    Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$(Join-Path $here 'WildcardLauncher.ps1')`"")
    return $true
}

function Install-Client($info) {
    if (Test-Path (Join-Path $clientDir 'Ascension.exe')) { return }
    $archive = Join-Path $here 'CoAClient.tar'
    $drive = (Get-Item $here).PSDrive
    $need = [long] $info.clientArchiveBytes * 2 + 5GB
    if (-not (Test-Path $archive) -and $drive.Free -lt $need) {
        throw ("The first install needs about {0} free on drive {1}: (the download plus the unpacked game); there is {2}." -f (Size $need), $drive.Name, (Size $drive.Free))
    }
    if (-not (Test-Path $archive)) {
        Log "Downloading the game archive ($(Size $info.clientArchiveBytes)) from the seedbox"
        Get-File $info.clientArchiveUrl $archive 'Downloading the game' $false
    }
    Step 'Unpacking the game (a few minutes)...'
    Busy
    $tar = Start-Process tar.exe -ArgumentList @('-xf', "`"$archive`"", '-C', "`"$here`"") -NoNewWindow -PassThru
    while (-not $tar.HasExited) { Start-Sleep -Milliseconds 200; [Windows.Forms.Application]::DoEvents() }
    if ($tar.ExitCode -ne 0) { throw "Unpacking the game failed (tar exit code $($tar.ExitCode)). Delete CoAClient.tar and start the launcher again." }
    Remove-Item $archive -Force
    Log 'Unpacked the game.'
}

function Sync-Client {
    Step "Checking for updates from $site..."
    $manifest = Get-Json "$site/manifest.json"
    $state = Read-State
    $files = @($manifest.files)
    Log "Manifest: $($files.Count) files, generated $($manifest.generated)"
    $script:checkTotal = [long] ($files | Measure-Object -Property size -Sum).Sum
    $script:checkedBytes = 0
    $stale = New-Object Collections.Generic.List[object]
    $index = 0
    $clock = [Diagnostics.Stopwatch]::StartNew()
    foreach ($file in $files) {
        $index++
        $before = $script:checkedBytes
        if ((Local-Hash $state $file.path $file) -ne $file.md5) { $stale.Add($file) }
        if ($script:checkedBytes -eq $before) { $script:checkedBytes += [long] $file.size }
        Say ("Checking your game files: {0} of {1} ({2} of {3} files)" -f (Size $script:checkedBytes), (Size $script:checkTotal), $index, $files.Count)
        Progress ([double] $script:checkedBytes / [Math]::Max([double] 1, [double] $script:checkTotal))
        if ($index % 20 -eq 0) { Save-State $state }
    }
    $script:checkTotal = 0
    Save-State $state
    Log ("Checked {0} files in {1:N0} s; {2} need downloading ({3})" -f $files.Count, $clock.Elapsed.TotalSeconds, $stale.Count,
        (Size (($stale | Measure-Object -Property size -Sum).Sum)))
    $total = ($stale | Measure-Object -Property size -Sum).Sum
    $done = 0
    $count = 0
    $failed = New-Object Collections.Generic.List[string]
    foreach ($file in $stale) {
        $count++
        if ($file.path -match '(^|[\\/])web\.config$') { continue }
        $target = Join-Path $clientDir $file.path
        New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
        $url = "$site/client/" + (($file.path -split '[\\/]' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
        Log "Downloading $($file.path) ($(Size $file.size))"
        try { Get-File $url $target ("Updating {0} ({1} of {2})" -f (Split-Path $file.path -Leaf), $count, $stale.Count) }
        catch {
            # One missing file should not stop the rest; it is reported at the end and retried next start.
            Log "Could not download $($file.path): $($_.Exception.Message)"
            $failed.Add($file.path)
            continue
        }
        if ($file.mtime) { (Get-Item -LiteralPath $target).LastWriteTimeUtc = [DateTimeOffset]::FromUnixTimeSeconds([long] $file.mtime).UtcDateTime }
        $done += $file.size
        if ($total -gt 0) { Progress ($done / $total) }
        $null = Local-Hash $state $file.path $file
    }
    foreach ($gone in @($manifest.remove)) {
        if (-not $gone) { continue }
        $path = Join-Path $clientDir $gone
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force; Log "Removed $gone" }
        $state.Remove($gone)
    }
    Save-State $state
    if ($failed.Count) {
        throw ("{0} file(s) could not be downloaded, first {1}: see the log; tell James" -f $failed.Count, $failed[0])
    }
    return $stale.Count
}

function Ready([string] $text) {
    Log $text
    Say $text
    Progress 1
    $play.Enabled = Test-Path (Join-Path $clientDir 'Ascension.exe')
}

# Whether the game's login server answers (port 3724), so "stuck at Connecting" can be told apart from a client problem.
function Check-Server([string] $realm) {
    if (-not $realm) { return }
    $server.Text = "Checking the game server ($realm)..."
    [Windows.Forms.Application]::DoEvents()
    $client = New-Object Net.Sockets.TcpClient
    try {
        $pending = $client.BeginConnect($realm, 3724, $null, $null)
        $clock = [Diagnostics.Stopwatch]::StartNew()
        while (-not $pending.AsyncWaitHandle.WaitOne(100) -and $clock.ElapsedMilliseconds -lt 5000) { [Windows.Forms.Application]::DoEvents() }
        if ($client.Connected) {
            $client.EndConnect($pending)
            $server.Text = "Game server: online ($realm)"
            $server.ForeColor = [Drawing.Color]::FromArgb(122, 217, 122)
        }
        else {
            $server.Text = "Game server: not answering ($realm). It may be restarting; try again in a few minutes."
            $server.ForeColor = [Drawing.Color]::FromArgb(255, 122, 107)
        }
    }
    catch {
        $server.Text = "Game server: cannot reach $realm ($($_.Exception.InnerException.Message))"
        $server.ForeColor = [Drawing.Color]::FromArgb(255, 122, 107)
    }
    finally { $client.Close() }
    Log $server.Text
}

$play.Add_Click({
    Start-Process -FilePath (Join-Path $clientDir 'Ascension.exe') -WorkingDirectory $clientDir
    $form.Close()
})

$form.Add_Shown({
    $info = $null
    Log "---- launcher $LauncherVersion started in $here"
    try {
        Step "Contacting $site..."
        $info = Get-Json "$site/launcher.json"
        if (Update-Self $info) { $form.Close(); return }
        Install-Client $info
        if (Test-Path (Join-Path $clientDir 'Ascension.exe')) { Set-Realm $info.realm }
        $changed = Sync-Client
        if ($changed) { Ready "Up to date ($changed file(s) updated). Have fun!" } else { Ready 'Up to date. Have fun!' }
    }
    catch {
        $message = $_.Exception.Message
        Log "Error: $message"
        if (Test-Path (Join-Path $clientDir 'Ascension.exe')) {
            Ready "Could not check for updates: $message. You can still play with what is installed."
        }
        else { Say "Something went wrong: $message. The Log button shows the details for James."; $bar.Value = 0 }
    }
    $realm = if ($info -and $info.realm) { $info.realm } else { 'wow.jtlab.cc' }
    # Point the game at the server even when the site or an update failed, so it never keeps an old address.
    if (Test-Path (Join-Path $clientDir 'Ascension.exe')) {
        try { Set-Realm $realm; Log "Game points at $realm" } catch { Log "Could not set the server address: $($_.Exception.Message)" }
    }
    Check-Server $realm
})

[void] $form.ShowDialog()
