<#
Wildcard launcher: keeps a friend's copy of the client up to date with James's server, then starts the game.

  1. Reads launcher.json from the server's site (the site address is in launcher-site.txt next to this file).
  2. Updates itself if the site has a newer launcher.
  3. First run: downloads the whole client (one archive, from the seedbox), resuming if interrupted, and unpacks it.
  4. Every run: compares the client with the site's manifest and downloads only the files that differ.
  5. Points the game at the server (realmList in WTF\Config.wtf), then the Play button starts it.

If the site cannot be reached, the game can still be started with whatever is installed.
#>
$LauncherVersion = 1
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$here = $PSScriptRoot
$clientDir = Join-Path $here 'CoAClient'
$stateFile = Join-Path $here 'launcher-state.json'
$siteFile = Join-Path $here 'launcher-site.txt'
$secretFile = Join-Path $here 'launcher-secret.json'
$site = if (Test-Path $siteFile) { (Get-Content $siteFile -Raw).Trim().TrimEnd('/') } else { 'https://wildcard.jtlab.cc' }
$headers = @{}
if (Test-Path $secretFile) {
    $secret = Get-Content $secretFile -Raw | ConvertFrom-Json
    if ($secret.id) { $headers['CF-Access-Client-Id'] = $secret.id; $headers['CF-Access-Client-Secret'] = $secret.secret }
}

# ------------------------------------------------------------------ window
$form = New-Object Windows.Forms.Form
$form.Text = 'Wildcard'
$form.Size = New-Object Drawing.Size(520, 230)
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
$play.Location = New-Object Drawing.Point(372, 142)
$play.Size = New-Object Drawing.Size(120, 38)
$play.Enabled = $false
$play.FlatStyle = 'Flat'
$play.BackColor = [Drawing.Color]::FromArgb(230, 180, 60)
$play.ForeColor = [Drawing.Color]::Black
$form.Controls.Add($play)

function Say([string] $text) { $status.Text = $text; [Windows.Forms.Application]::DoEvents() }
function Progress([double] $fraction) {
    $bar.Style = 'Blocks'
    $bar.Value = [int] [Math]::Max(0, [Math]::Min(1000, $fraction * 1000))
    [Windows.Forms.Application]::DoEvents()
}
function Busy { $bar.Style = 'Marquee'; [Windows.Forms.Application]::DoEvents() }
function Size([double] $bytes) {
    if ($bytes -ge 1GB) { return '{0:N1} GB' -f ($bytes / 1GB) }
    return '{0:N0} MB' -f ($bytes / 1MB)
}

# ------------------------------------------------------------------ web
function Get-Json([string] $url) {
    $request = [Net.HttpWebRequest]::Create($url)
    foreach ($key in $headers.Keys) { $request.Headers.Add($key, $headers[$key]) }
    $request.Timeout = 20000
    $response = $request.GetResponse()
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
    if ($have -gt 0) { $request.AddRange([long] $have) }
    $response = $request.GetResponse()
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
                    $speed = ($done - $have) / [Math]::Max(1, $clock.Elapsed.TotalSeconds)
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
function Get-Md5([string] $path) {
    $md5 = [Security.Cryptography.MD5]::Create()
    $stream = [IO.File]::OpenRead($path)
    try { return ([BitConverter]::ToString($md5.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Close(); $md5.Dispose() }
}

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

# The MD5 of a local file, reusing the last result while its size and modified time are unchanged.
function Local-Hash($state, [string] $relative) {
    $path = Join-Path $clientDir $relative
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $item = Get-Item -LiteralPath $path
    $stamp = "$($item.Length)|$($item.LastWriteTimeUtc.Ticks)"
    $known = $state[$relative]
    if ($known -and $known.stamp -eq $stamp) { return $known.md5 }
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
}

# ------------------------------------------------------------------ steps
function Update-Self($info) {
    if (-not $info.launcherVersion -or [int] $info.launcherVersion -le $LauncherVersion) { return $false }
    Say 'Updating the launcher...'
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
    if (-not (Test-Path $archive)) { Get-File $info.clientArchiveUrl $archive 'Downloading the game' $false }
    Say 'Unpacking the game (a few minutes)...'
    Busy
    $tar = Start-Process tar.exe -ArgumentList @('-xf', "`"$archive`"", '-C', "`"$here`"") -NoNewWindow -PassThru
    while (-not $tar.HasExited) { Start-Sleep -Milliseconds 200; [Windows.Forms.Application]::DoEvents() }
    if ($tar.ExitCode -ne 0) { throw "Unpacking the game failed (tar exit code $($tar.ExitCode)). Delete CoAClient.tar and start the launcher again." }
    Remove-Item $archive -Force
}

function Sync-Client {
    Say 'Checking for updates...'
    $manifest = Get-Json "$site/manifest.json"
    $state = Read-State
    $files = @($manifest.files)
    $stale = New-Object Collections.Generic.List[object]
    $index = 0
    foreach ($file in $files) {
        $index++
        if ($index % 200 -eq 0) { Say "Checking your game files ($index of $($files.Count))..."; Progress ($index / $files.Count) }
        if ((Local-Hash $state $file.path) -ne $file.md5) { $stale.Add($file) }
    }
    Save-State $state
    $total = ($stale | Measure-Object -Property size -Sum).Sum
    $done = 0
    $count = 0
    foreach ($file in $stale) {
        $count++
        $target = Join-Path $clientDir $file.path
        New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
        $url = "$site/client/" + (($file.path -split '[\\/]' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
        Get-File $url $target ("Updating ({0} of {1})" -f $count, $stale.Count)
        $done += $file.size
        if ($total -gt 0) { Progress ($done / $total) }
        $null = Local-Hash $state $file.path
    }
    foreach ($gone in @($manifest.remove)) {
        if (-not $gone) { continue }
        $path = Join-Path $clientDir $gone
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
        $state.Remove($gone)
    }
    Save-State $state
    return $stale.Count
}

function Ready([string] $text) {
    Say $text
    Progress 1
    $play.Enabled = Test-Path (Join-Path $clientDir 'Ascension.exe')
}

$play.Add_Click({
    Start-Process -FilePath (Join-Path $clientDir 'Ascension.exe') -WorkingDirectory $clientDir
    $form.Close()
})

$form.Add_Shown({
    try {
        $info = Get-Json "$site/launcher.json"
        if (Update-Self $info) { $form.Close(); return }
        Install-Client $info
        $changed = Sync-Client
        Set-Realm $info.realm
        if ($changed) { Ready "Up to date ($changed file(s) updated). Have fun!" } else { Ready 'Up to date. Have fun!' }
    }
    catch {
        $message = $_.Exception.Message
        if (Test-Path (Join-Path $clientDir 'Ascension.exe')) {
            Ready "Could not check for updates ($message). You can still play with what is installed."
        }
        else { Say "Something went wrong: $message"; $bar.Value = 0 }
    }
})

[void] $form.ShowDialog()
