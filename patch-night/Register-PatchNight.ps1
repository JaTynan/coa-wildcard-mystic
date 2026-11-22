<#
Creates (or updates) the Windows scheduled task that runs patch night, every night:
  CoA Patch Night   daily, starts 3:30 am: the merged fixes, settings, addons and site, and a new patched server
                    build when GitHub has one for the installed core.
It counts down in game chat first (30, 15, 10, 5, 1 minutes), so the restart happens at 4:00 am.
Daily since 23 November 2026 (James): until then a new build was only installed on Tuesday nights and the nightly run
skipped it. The old second task, "CoA Nightly Restart", is removed when this runs.
Change the time or warning here and run Register-PatchNight.cmd again.
Remove: Unregister-ScheduledTask -TaskName 'CoA Patch Night'
#>
param(
    [string] $Time = '3:30am',
    [int] $WarnMinutes = 30
)
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'PatchNight.ps1'
# Runs as you, while you are signed in on the VM (the manager runs in your session too).
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 3) -MultipleInstances IgnoreNew

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Unattended -WarnMinutes $WarnMinutes" `
    -WorkingDirectory $PSScriptRoot
Register-ScheduledTask -TaskName 'CoA Patch Night' -Action $action -Trigger (New-ScheduledTaskTrigger -Daily -At $Time) -Principal $principal -Settings $settings -Force | Out-Null

# The nightly restart without builds is now the same run as patch night: one task, not two restarts on one night.
$old = Get-ScheduledTask -TaskName 'CoA Nightly Restart' -ErrorAction SilentlyContinue
if ($old) {
    Unregister-ScheduledTask -TaskName 'CoA Nightly Restart' -Confirm:$false
    Write-Host 'Removed the old "CoA Nightly Restart" task (patch night now runs every night instead).'
}

$restart = ([datetime] $Time).AddMinutes($WarnMinutes).ToString('h:mm tt')
Write-Host ''
Write-Host "Patch night (fixes, settings and new builds): every night, countdown from $Time, restart at $restart." -ForegroundColor Green
Write-Host 'It shows in Task Scheduler as "CoA Patch Night". Results: patch-night.log and last-run.txt here.'
Write-Host ''
Read-Host 'Press Enter to close' | Out-Null
