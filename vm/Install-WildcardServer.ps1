<#
Swaps the manager's world server for the patched build in this folder, or puts the official one back.

  Install.cmd          installs the patched world server, the config line and the addon
  Restore-Official.cmd puts the manager's own world server back

Stop the server in the manager first. Nothing is deleted: the official program is kept as
Core\worldserver.official.exe. Use at your own risk.
#>
param(
    [switch] $Restore,
    [switch] $Force,
    [string] $Server = 'C:\Games\CoA Server',
    [string] $Client = 'F:\CoAClient'
)
$ErrorActionPreference = 'Stop'

function Done([string] $message, [int] $code = 0) {
    Write-Host ''
    if ($code) { Write-Host $message -ForegroundColor Red } else { Write-Host $message -ForegroundColor Green }
    Write-Host ''
    Read-Host 'Press Enter to close'
    exit $code
}

function Revision([string] $exe) {
    # "AzerothCore rev. a76415e00eba+ 2026-10-28 ..." -> a76415e00eba
    # Windows PowerShell turns a program's stderr into errors; don't let that stop the script.
    $ErrorActionPreference = 'Continue'
    $text = (& $exe --version 2>&1 | Out-String)
    if ($LASTEXITCODE) { return $null }
    if ($text -match 'rev\.\s+([0-9a-f]{7,40})') { return $Matches[1] }
    return 'unknown'
}

$core = Join-Path $Server 'Core'
$live = Join-Path $core 'worldserver.exe'
$official = Join-Path $core 'worldserver.official.exe'
$marker = Join-Path $core 'worldserver.patched.txt'
$here = $PSScriptRoot

if (-not (Test-Path $live)) { Done "No world server found at $live." 1 }
if (Get-Process worldserver -ErrorAction SilentlyContinue) {
    Done 'The world server is running. Stop the server in the manager first, then run this again.' 1
}

Push-Location $core
try {
    if ($Restore) {
        if (-not (Test-Path $official)) { Done 'No official copy saved; the world server was never swapped.' 1 }
        Copy-Item $official $live -Force
        Remove-Item $marker -ErrorAction SilentlyContinue
        Done 'The official world server is back. Start the server in the manager.'
    }

    $new = Join-Path $here 'server\worldserver.exe'
    if (-not (Test-Path $new)) { Done "This folder has no server\worldserver.exe. Extract the whole zip first." 1 }
    $built = (Get-Content (Join-Path $here 'server\core-revision.txt') -Raw).Trim()
    $newHash = (Get-FileHash $new).Hash

    # Keep the manager's own program. If the live one is not a build of ours, it is the
    # official one (perhaps a newer one from a manager update), so save it.
    $liveHash = (Get-FileHash $live).Hash
    $ours = (Test-Path $marker) -and ((Get-Content $marker -Raw).Trim() -eq $liveHash)
    if (-not $ours) {
        Copy-Item $live $official -Force
        Write-Host 'Saved the official world server as worldserver.official.exe'
    }

    # The patched build must come from the same core as the manager's install, or the
    # databases the manager set up will not match it.
    $installed = Revision $official
    if ($installed -and $installed -ne 'unknown' -and -not $built.StartsWith($installed) -and -not $Force) {
        Done ("This build is for core $($built.Substring(0,12)), but the manager installed core $installed.`n" +
              'The manager has probably updated. Run the GitHub build again for the new release.') 1
    }

    Copy-Item $new $live -Force
    if (-not (Revision $live)) {
        Copy-Item $official $live -Force
        Done 'The patched world server would not start here, so the official one was put back.' 1
    }
    $newHash | Set-Content $marker -Encoding ascii
    Write-Host "Installed the patched world server (core $($built.Substring(0,12)))."

    # Turn the feature on. The option only affects Wildcard characters.
    $conf = Join-Path $core 'configs\modules\coa.conf'
    if (Test-Path $conf) {
        $lines = @(Get-Content $conf)
        $key = '^\s*CoA\.MysticEnchants\.AllowWildcard\s*='
        if ($lines -match $key) {
            $lines = $lines -replace "$key.*", 'CoA.MysticEnchants.AllowWildcard = 1'
        } else {
            $lines += '', '# Wildcard Mystic Enchants (patched world server)', 'CoA.MysticEnchants.AllowWildcard = 1'
        }
        # No byte-order mark: the server's config reader does not expect one.
        [IO.File]::WriteAllLines($conf, [string[]] $lines)
        Write-Host 'Set CoA.MysticEnchants.AllowWildcard = 1 in coa.conf'
    } else {
        Write-Host "No coa.conf at $conf; add CoA.MysticEnchants.AllowWildcard = 1 by hand." -ForegroundColor Yellow
    }

    # The client addon, so every synced client gets it.
    $addons = Join-Path $Client 'Interface\AddOns'
    if (Test-Path $addons) {
        Copy-Item (Join-Path $here 'addon\WildcardEnchants') $addons -Recurse -Force
        Write-Host "Copied the WildcardEnchants addon to $addons"
    } else {
        Write-Host "No client found at $Client; copy addon\WildcardEnchants into Interface\AddOns by hand." -ForegroundColor Yellow
    }
} finally {
    Pop-Location
}
Done 'All done. Start the server in the manager.'
