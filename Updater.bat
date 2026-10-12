@ECHO OFF
TITLE prefs.js cleaner launcher
CD /D "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0prefsCleaner.ps1"
