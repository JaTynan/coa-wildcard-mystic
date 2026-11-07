<#
Creates (or updates) the two Windows scheduled tasks that run patch night:
  CoA Patch Night       weekly, Tuesday 11:00 pm: everything, including installing a new patched server build.
  CoA Nightly Restart   every night, starts 3:30 am: the merged fixes, settings, addon and site, no new build.
Both count down in game chat first (30, 15, 10, 5, 1 minutes), so the nightly restart happens at 4:00 am.
Change the times or warning here and run Register-PatchNight.cmd again.
Remove: Unregister-ScheduledTask -TaskName 'CoA Patch Night' (or 'CoA Nightly Restart')
#>
param(
    [string] $Day = 'Tuesday',
    [string] $Time = '11:00pm',
    [string] $NightlyTime = '3:30am',
    [int] $WarnMinutes = 30
)
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'PatchNight.ps1'
# Runs as you, while you are signed in on the VM (the manager runs in your session too).
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 3) -MultipleInstances IgnoreNew

function Register-Run([string] $name, $trigger, [string] $extra) {
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Unattended -WarnMinutes $WarnMinutes$extra" `
        -WorkingDirectory $PSScriptRoot
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
}
Register-Run 'CoA Patch Night' (New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Day -At $Time) ''
Register-Run 'CoA Nightly Restart' (New-ScheduledTaskTrigger -Daily -At $NightlyTime) ' -NoInstall'

$restart = ([datetime] $NightlyTime).AddMinutes($WarnMinutes).ToString('h:mm tt')
Write-Host ''
Write-Host "Patch night (with new builds): every $Day at $Time, after a $WarnMinutes-minute countdown." -ForegroundColor Green
Write-Host "Nightly restart (fixes and settings only): countdown from $NightlyTime, restart at $restart." -ForegroundColor Green
Write-Host 'They show in Task Scheduler as "CoA Patch Night" and "CoA Nightly Restart". Results: patch-night.log and last-run.txt here.'
Write-Host ''
Read-Host 'Press Enter to close' | Out-Null
