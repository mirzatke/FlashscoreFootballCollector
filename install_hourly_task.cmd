@echo off
setlocal
cd /d "%~dp0"

set TASK_NAME=World Cup Flashscore Collector
set EXE=%~dp0WorldCupFlashscoreCollector.exe

schtasks /Create /F /SC MINUTE /MO 1 /TN "%TASK_NAME%" /TR "\"%EXE%\" -collect-one"
if errorlevel 1 (
  echo Failed to create task. Run this file as Administrator if required.
  pause
  exit /b 1
)

echo Task created: %TASK_NAME%
pause
