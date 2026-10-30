<#
Creates (or updates) the Windows scheduled task that runs patch night every week.
Default: Tuesday 11:00 pm. Change the day or time here and run Register-PatchNight.cmd again.
Remove-PatchNight is: Unregister-ScheduledTask -TaskName 'CoA Patch Night'
#>
param(
    [string] $Day = 'Tuesday',
    [string] $Time = '11:00pm'
)
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'PatchNight.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Unattended" `
    -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Day -At $Time
# Runs as you, while you are signed in on the VM (the manager runs in your session too).
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 3) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'CoA Patch Night' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host ''
Write-Host "Patch night is scheduled for every $Day at $Time." -ForegroundColor Green
Write-Host 'It shows in Task Scheduler as "CoA Patch Night". Results: patch-night.log and last-run.txt in this folder.'
Write-Host ''
Read-Host 'Press Enter to close' | Out-Null
