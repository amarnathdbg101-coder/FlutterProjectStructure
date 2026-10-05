@echo off
title StudySilo.in Flutter App Runner
cd /d "%~dp0"
cls
echo ========================================================
echo             StudySilo.in Flutter App Runner
echo ========================================================
echo.
echo Hot Reload (r) and Hot Restart (R) work in Debug Mode!
echo.
echo Select target device:
echo   [1] Android Phone (V2338 / USB Debugging)
echo   [2] Windows Desktop Application
echo   [3] Chrome Web Browser
echo   [4] Auto-select
echo.
set /p target="Enter choice (1, 2, 3, or 4) [Default: 1]: "

if "%target%"=="2" (
    echo Starting on Windows Desktop in Debug mode...
    flutter run -d windows
) else if "%target%"=="3" (
    echo Starting on Chrome Web Browser in Debug mode...
    flutter run -d chrome
) else if "%target%"=="4" (
    echo Starting with Flutter device selection...
    flutter run
) else (
    echo Starting on Android Phone (V2338) in Debug mode...
    flutter run -d android
)

pause
