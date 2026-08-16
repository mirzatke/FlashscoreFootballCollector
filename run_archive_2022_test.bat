@echo off
cd /d "%~dp0"
WorldCupFlashscoreCollector.exe -archive-2022
set EXIT_CODE=%ERRORLEVEL%
echo Archive 2022 batch exit code: %EXIT_CODE%
exit /b %EXIT_CODE%
