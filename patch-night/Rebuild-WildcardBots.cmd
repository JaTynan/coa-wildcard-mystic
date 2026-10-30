@echo off
rem One-off: removes the Wildcard realm's bots that are not Heroes, then starts the server so SQUID creates Hero bots.
rem Only characters on SQUID's bot accounts, in the Wildcard characters database. Make a backup in the manager first.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PatchNight.ps1" -RebuildWildcardBots
