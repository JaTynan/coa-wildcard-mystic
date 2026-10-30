@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-ServerSettings.ps1" -Capture
