<#
One-time setup on the VM (run as administrator through Register-WildcardSignup.cmd): starts the friends' sign-up page
(WildcardSignup.py) now and at every sign-in, and lets only the Servers network (where the Cloudflare tunnel runs)
reach its port. Creates signup-settings.json next to the patch-night scripts the first time and opens it to fill in.
Remove: Unregister-ScheduledTask -TaskName 'Wildcard Sign-up'; Remove-NetFirewallRule -DisplayName 'Wildcard sign-up'
#>
param(
    [string] $Server = 'C:\Games\CoA Server',
    [int] $Port = 8089,
    [string] $TunnelHost = '10.59.20.0/24',
    [string] $UserId = ''
)
$ErrorActionPreference = 'Stop'
$patchNight = Split-Path $PSScriptRoot -Parent
$python = Join-Path $Server 'Runtime\python\python.exe'
$script = Join-Path $PSScriptRoot 'WildcardSignup.py'
if (-not (Test-Path $python)) { throw "No manager Python at $python." }

$settings = Join-Path $patchNight 'signup-settings.json'
if (-not (Test-Path $settings)) {
    [pscustomobject] @{
        turnstileSiteKey = 'PASTE-SITE-KEY'
        turnstileSecret = 'PASTE-SECRET-KEY'
        inviteCodes = @('CHANGE-ME')
        perAddressPerDay = 3
        perDay = 20
        failuresPerAddressPerDay = 10
    } | ConvertTo-Json | Set-Content $settings -Encoding UTF8
}

Get-NetFirewallRule -DisplayName 'Wildcard sign-up' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName 'Wildcard sign-up' -Direction Inbound -Protocol TCP -LocalPort $Port -RemoteAddress $TunnelHost -Action Allow | Out-Null

if (-not $UserId) { $UserId = [Security.Principal.WindowsIdentity]::GetCurrent().Name }
$action = New-ScheduledTaskAction -Execute $python -Argument "-B `"$script`" --server `"$Server`" --port $Port" -WorkingDirectory $patchNight
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $UserId
# Runs as you, like patch night and the manager (the account command goes through the manager's scripts).
$principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType Interactive -RunLevel Limited
$taskSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew `
    -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName 'Wildcard Sign-up' -Action $action -Trigger $trigger -Principal $principal -Settings $taskSettings -Force | Out-Null
Stop-ScheduledTask -TaskName 'Wildcard Sign-up' -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName 'Wildcard Sign-up'

Write-Host ''
Write-Host "The sign-up page runs on port $Port (task 'Wildcard Sign-up'; log: signup.log in the patch-night folder)." -ForegroundColor Green
Write-Host "Fill in $settings (it opens now): the two Turnstile keys and your invite code(s). Changes apply straight away."
Start-Process notepad.exe $settings
Write-Host ''
Read-Host 'Press Enter to close' | Out-Null
