@echo off
rem Runs patch night now, with this window open, instead of waiting for Tuesday.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PatchNight.ps1"
