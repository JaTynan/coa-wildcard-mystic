@echo off
rem Starts the Wildcard launcher (checks for updates, then the Play button starts the game).
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0WildcardLauncher.ps1"
