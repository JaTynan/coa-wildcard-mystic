<#
Creates (or updates) the Windows scheduled task that runs patch night every night.
Default: starts 3:30 am and counts down 30 minutes in game chat (30, 15, 10, 5, 1), so the restart is at 4:00 am.
Change the time or warning here and run Register-PatchNight.cmd again.
Remove-PatchNight is: Unregister-ScheduledTask -TaskName 'CoA Patch Night'
#>
param(
    [string] $Time = '3:30am',
    [int] $WarnMinutes = 30
)
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'PatchNight.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Unattended -WarnMinutes $WarnMinutes" `
    -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -Daily -At $Time
# Runs as you, while you are signed in on the VM (the manager runs in your session too).
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 3) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'CoA Patch Night' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host ''
$restart = ([datetime] $Time).AddMinutes($WarnMinutes).ToString('h:mm tt')
Write-Host "Patch night runs every night at $Time, warns players for $WarnMinutes minutes, and restarts at $restart." -ForegroundColor Green
Write-Host 'It shows in Task Scheduler as "CoA Patch Night". Results: patch-night.log and last-run.txt in this folder.'
Write-Host ''
Read-Host 'Press Enter to close' | Out-Null
