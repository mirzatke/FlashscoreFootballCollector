@echo off
setlocal
cd /d "%~dp0"
WorldCupFlashscoreCollector.exe --collect-one
exit /b %errorlevel%
