@echo off
rem One-time: starts the friends' sign-up page now and at every sign-in (asks for administrator rights for the firewall rule).
powershell.exe -NoProfile -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Register-WildcardSignup.ps1\"'"
