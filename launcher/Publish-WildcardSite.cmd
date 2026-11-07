@echo off
rem Refreshes the friends' download site now (patch night also does this after every start).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Publish-WildcardSite.ps1"
pause
