<#
Gameplay tests after patch night (proposed 25 Nov 2026).

Runs this repository's gameplay scenarios (tests\gameplay\scenarios) in a separate, throwaway world server, using
the CoA core's own test harness (src\server\coa\CoAGameplayTest.cpp, runner apps\coa-gameplay-test). PatchNight.ps1
calls it on the scheduled run only, after tonight's SQL fixes and before the live world starts, while no players
are on (James: none expected from 3:30 to 5:30 am).

What it touches:
  - Reads the live world, auth and characters databases, and copies them into new coa_test_<id>_* databases,
    which the harness drops at the end. Leftovers from an interrupted run (same name pattern only) are dropped
    at the start and end of each run.
  - Starts Core\worldserver.exe with a config the harness writes (local address only, its own port, test
    databases). SQUID's bots and the AI chat are switched off in that copy. The live configs are never changed.
  - Downloads the six runner files from the CoA core repository at the revision of the installed world server,
    once per revision, into gameplay-tests\runner\<commit>.
  - Writes results to gameplay-tests\results\<date_time> (the newest 14 kept) and a summary to latest.txt.

It never decides anything: it prints lines for patch-night.log and always exits 0. A time limit (default 40
minutes, and never past 04:50) stops the test server; clean-up after it takes a few minutes more, and PatchNight.ps1
stops everything at 45 minutes, so the live start is delayed by 45 minutes at most.
#>
param(
    [string] $Server = 'C:\Games\CoA Server',
    [Parameter(Mandatory = $true)] [string] $Scenarios,
    [int] $BudgetMinutes = 40,
    [string] $NotAfter = '04:50',
    [string] $CoreRepo = 'Corfirean/azerothcore-wotlk-coa'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$core = Join-Path $Server 'Core'
$exe = Join-Path $core 'worldserver.exe'
$config = Join-Path $core 'configs\worldserver.conf'
$modules = Join-Path $core 'configs\modules'
$python = Join-Path $Server 'Runtime\python\python.exe'
$mysql = Join-Path $Server 'mysql\bin\mysql.exe'
$dump = Join-Path $Server 'mysql\bin\mysqldump.exe'
$ini = Join-Path $Server 'mysql\admin-client.ini'
$root = Join-Path $Server 'gameplay-tests'
$headers = @{ 'User-Agent' = 'coa-patch-night' }
# The runner and what it imports (run -> world_cache; batch -> catalog, run, verification; workflow is imported by
# nothing here but kept so the folder matches the core's). Checkers and the core's 4,700 scenarios are not needed:
# our own checks.json (no checkers) and clock_policy.json (no exclusive scenarios) go next to them.
$runnerFiles = 'batch.py', 'run.py', 'world_cache.py', 'catalog.py', 'verification.py', 'workflow.py'
$testSchema = '^coa_test_[0-9a-f]{12}_(auth|characters|world)$'

function Say([string] $message) { Write-Output "Gameplay tests: $message" }

function Sql([string] $query) {
    $ErrorActionPreference = 'Continue'   # mysql writes warnings to stderr; only its exit code counts
    $output = $query | & $mysql "--defaults-file=$ini" --batch --skip-column-names 2>&1
    if ($LASTEXITCODE) { throw "mysql failed: $(($output | Out-String).Trim())" }
    return @($output | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
}

function DropLeftoverSchemas {
    # Only names the harness itself makes (coa_test_ + 12 hex digits + role); nothing else is ever dropped.
    $names = Sql "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME LIKE 'coa\_test\_%';"
    foreach ($name in $names) {
        if ($name -notmatch $testSchema) { continue }
        $null = Sql "DROP DATABASE ``$name``;"
        Say "dropped the leftover test database $name."
    }
}

function StopTestQueries {
    # Killing the runner kills its mysql.exe clients, but MySQL carries on with their copy statements (and a DROP
    # would wait behind them). Stops every query on a coa_test_ database or naming one, except this connection.
    $ids = Sql ("SELECT ID FROM information_schema.PROCESSLIST WHERE ID <> CONNECTION_ID() AND " +
                "(DB LIKE 'coa\_test\_%' OR INFO LIKE '%coa\_test\_%');")
    foreach ($id in $ids) {
        if ($id -notmatch '^\d+$') { continue }
        try { $null = Sql "KILL $id;"; Say "stopped test database query $id." } catch { }
    }
}

function StopTestServers {
    # A test world server always runs from a config the harness writes in a coa-gameplay-batch-* temporary folder;
    # the live one never does.
    $procs = @(Get-CimInstance Win32_Process -Filter "Name = 'worldserver.exe'" |
               Where-Object { $_.CommandLine -and $_.CommandLine.Contains('coa-gameplay-batch-') })
    foreach ($proc in $procs) {
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
        Say "stopped test world server $($proc.ProcessId)."
    }
}

function RemoveCredentials([string] $folder) {
    # The harness writes connection files (passwords) and deletes them itself; after a forced stop they would stay.
    Get-ChildItem $folder -Recurse -File -Include '*.cnf', '*.conf' -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem $env:TEMP -Directory -Filter 'coa-gameplay-batch-*' -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

function Prune([string] $folder, [int] $keep) {
    Get-ChildItem $folder -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $keep | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

function Runner([string] $short) {
    # The runner must match the harness compiled into the world server, so it comes from the same core commit.
    $commit = (Invoke-RestMethod -Uri "https://api.github.com/repos/$CoreRepo/commits/$short" -Headers $headers -TimeoutSec 60).sha
    if ($commit -notmatch '^[0-9a-f]{40}$') { throw "cannot resolve core revision $short" }
    $folder = Join-Path $root "runner\$commit"
    $app = Join-Path $folder 'apps\coa-gameplay-test'
    if (-not (Test-Path (Join-Path $app 'ready.txt'))) {
        if (Test-Path $folder) { Remove-Item $folder -Recurse -Force }
        New-Item -ItemType Directory -Force -Path (Join-Path $app 'scenarios') | Out-Null
        foreach ($name in $runnerFiles) {
            $target = Join-Path $app $name
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$CoreRepo/$commit/apps/coa-gameplay-test/$name" `
                -OutFile $target -Headers $headers -UseBasicParsing -TimeoutSec 60
            if ((Get-Item $target).Length -lt 100) { throw "downloaded $name is empty" }
        }
        Set-Content -Path (Join-Path $app 'checks.json') -Value '{"schema": 1, "checks": []}' -Encoding ascii
        Set-Content -Path (Join-Path $app 'clock_policy.json') -Value '{"schema": 1, "exclusive": {}}' -Encoding ascii
        # The embedded Python ignores the script's own folder (its ._pth file), so this puts it on the path.
        Set-Content -Path (Join-Path $folder 'launch.py') -Encoding ascii -Value @(
            'import runpy, sys',
            'from pathlib import Path',
            'script = Path(sys.argv[1]).resolve()',
            'sys.path.insert(0, str(script.parent))',
            'sys.argv = [str(script)] + sys.argv[2:]',
            "runpy.run_path(str(script), run_name='__main__')")
        Set-Content -Path (Join-Path $app 'ready.txt') -Value $commit -Encoding ascii
        $script:downloaded = $commit.Substring(0, 12)   # said by the caller: output here would join the return value
    }
    return $folder
}

function TestModules([string] $target) {
    # The live module configs, with SQUID's bots and the AI chat off: the tests need neither, and 750 bots would
    # only slow the test server and load the live bot database.
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    foreach ($file in Get-ChildItem $modules -Filter *.conf -File) {
        $text = [IO.File]::ReadAllText($file.FullName)
        $text = $text -replace '(?m)^(\s*AiPlayerbot\.Enabled\s*=\s*)\d+', '${1}0'
        $text = $text -replace '(?m)^(\s*OllamaChat\.Enable\s*=\s*)\d+', '${1}0'
        [IO.File]::WriteAllText((Join-Path $target $file.Name), $text)
    }
}

function HasClientKeys {
    # The harness can use the admin client file only if it has a [client] section naming host, port, user and
    # password. Only those names are looked at; nothing from the file is printed or copied. Otherwise it uses the
    # world server's own login.
    $text = Get-Content $ini -Raw
    if ($text -notmatch '(?m)^\s*\[client\]') { return $false }
    foreach ($key in 'host', 'port', 'user', 'password') { if ($text -notmatch "(?m)^\s*$key\s*=") { return $false } }
    return $true
}

try {
    $start = Get-Date
    $limit = [datetime]::ParseExact($NotAfter, 'HH:mm', $null)
    if ($limit -lt $start) { Say "skipped: it is past $NotAfter."; exit 0 }
    $deadline = @($start.AddMinutes($BudgetMinutes), $limit) | Sort-Object | Select-Object -First 1
    if (($deadline - $start).TotalMinutes -lt 15) { Say "skipped: less than 15 minutes left before $NotAfter."; exit 0 }
    $files = @(Get-ChildItem $Scenarios -Filter *.json -File -ErrorAction SilentlyContinue | Sort-Object Name)
    if (-not $files.Count) { Say "skipped: no scenarios in $Scenarios."; exit 0 }
    foreach ($needed in $exe, $config, $python, $mysql, $dump, $ini) {
        if (-not (Test-Path $needed)) { Say "skipped: missing $needed."; exit 0 }
    }
    if (Get-Process worldserver -ErrorAction SilentlyContinue) { Say 'skipped: a world server is running.'; exit 0 }
    $freeGb = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1)
    if ($freeGb -lt 6) { Say "skipped: only $freeGb GB of memory free (6 needed)."; exit 0 }
    $drive = Get-PSDrive ((Resolve-Path $Server).Drive.Name)
    $diskGb = [math]::Round($drive.Free / 1GB, 1)
    if ($diskGb -lt 10) { Say "skipped: only $diskGb GB free on drive $($drive.Name) (10 needed)."; exit 0 }

    $ErrorActionPreference = 'Continue'
    $version = (& $exe --version 2>&1 | Out-String)
    $ErrorActionPreference = 'Stop'
    if ($version -notmatch 'rev\.\s+([0-9a-f]{7,40})') { Say 'skipped: cannot read the world server revision.'; exit 0 }
    $revision = $Matches[1]
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'results') | Out-Null
    $runner = Runner $revision
    if ($script:downloaded) { Say "downloaded the test runner for core $script:downloaded." }
    Prune (Join-Path $root 'runner') 3
    Prune (Join-Path $root 'results') 13

    $out = Join-Path $root ('results\' + $start.ToString('yyyy-MM-dd_HHmm'))
    if (Test-Path $out) { Remove-Item $out -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    TestModules (Join-Path $out 'module-source')
    DropLeftoverSchemas

    # Simulated clock: one test server runs the scenarios side by side, with one copy of the world. Fresh
    # databases: tonight's SQL changed the world, so a world kept from an earlier night would be stale.
    # External migrations: the live config has Updates.EnableDatabases = 0, so the harness keeps it at 0.
    $batch = Join-Path $runner 'apps\coa-gameplay-test\batch.py'
    $arguments = @('-B', "`"$(Join-Path $runner 'launch.py')`"", "`"$batch`"",
                   '--worldserver', "`"$exe`"", '--config', "`"$config`"", '--mysql', "`"$mysql`"", '--mysqldump', "`"$dump`"",
                   '--modules-config-dir', "`"$(Join-Path $out 'module-source')`"", '--output', "`"$(Join-Path $out 'batch')`"",
                   '--clock', 'simulated', '--jobs', '1', '--fresh-databases', '--external-db-migrations', '--scenario')
    $arguments += @($files | ForEach-Object { "`"$($_.FullName)`"" })
    if (HasClientKeys) { $arguments += @('--database-client-config', "`"$ini`"") }

    Say "running $($files.Count) scenario(s) on core $revision until $($deadline.ToString('HH:mm')) at the latest..."
    $stdout = Join-Path $out 'batch-output.txt'
    $proc = Start-Process -FilePath $python -ArgumentList $arguments -WorkingDirectory $out -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError (Join-Path $out 'batch-errors.txt')
    $null = $proc.Handle
    $waitMs = [math]::Max(0, [int] ($deadline - (Get-Date)).TotalMilliseconds)
    $finished = $proc.WaitForExit($waitMs)
    if (-not $finished) {
        & taskkill.exe /PID $proc.Id /T /F 2>&1 | Out-Null
        Say "stopped at the time limit ($([int] ((Get-Date) - $start).TotalMinutes) minutes); results are incomplete."
    }
    StopTestServers
    StopTestQueries
    RemoveCredentials $out
    Remove-Item (Join-Path $out 'module-source') -Recurse -Force -ErrorAction SilentlyContinue
    DropLeftoverSchemas

    $lines = @(Get-Content $stdout -ErrorAction SilentlyContinue)
    $cases = @($lines | Where-Object { $_ -match '^(PASS|FAIL)\s' })
    $verdict = @($lines | Where-Object { $_ -match '^GAMEPLAY\s' } | Select-Object -Last 1)
    $minutes = [math]::Round(((Get-Date) - $start).TotalMinutes, 1)
    $summary = if ($verdict.Count) { $verdict[0] } elseif ($finished) { "the runner ended with code $($proc.ExitCode) and no verdict; see batch-errors.txt" } else { 'no verdict (time limit)' }
    foreach ($case in $cases) { Say "  $case" }
    Say "$summary ($minutes min; $out)."
    @("$(Get-Date -Format 'yyyy-MM-dd HH:mm')  $summary ($minutes min)") + $cases + @("Folder: $out") |
        Set-Content -Path (Join-Path $root 'latest.txt') -Encoding utf8
} catch {
    Say "could not run: $($_.Exception.Message)"
    try { StopTestServers; StopTestQueries; if ($out) { RemoveCredentials $out } } catch { }
    try { DropLeftoverSchemas } catch { }
}
exit 0
