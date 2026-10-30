@echo off
rem Applies your server-settings and starts the server the way patch night does.
rem Use this instead of the manager's Start button: the manager turns the bots off on Wildcard.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PatchNight.ps1" -StartOnly
