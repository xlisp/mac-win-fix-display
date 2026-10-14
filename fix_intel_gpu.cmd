@echo off
rem Admin check: fltmc works in Safe Mode too (net session does not - Server service is off there)
fltmc >nul 2>&1 && goto :run
rem Relaunch elevated only once; the --elevated marker prevents an endless relaunch loop
if /i "%~1"=="--elevated" (
    echo Still no admin rights. Right-click fix_intel_gpu.cmd and choose "Run as administrator".
    pause
    exit /b 1
)
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '--elevated %*' -Verb RunAs"
exit /b

:run
if /i "%~1"=="--elevated" shift
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix_intel_gpu.ps1" %1
