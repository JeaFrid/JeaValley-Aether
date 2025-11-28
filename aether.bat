@echo off
REM JeaValley Aether Windows istemcisi (Python gerekmez). PowerShell 5+ gereklidir.
set SCRIPT_DIR=%~dp0
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%aether.ps1" %*
