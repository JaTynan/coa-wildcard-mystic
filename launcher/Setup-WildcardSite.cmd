@echo off
rem One-time: serves the friends' download site with IIS on port 8088 (asks for administrator rights).
powershell.exe -NoProfile -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File \"%~dp0Setup-WildcardSite.ps1\"'"
