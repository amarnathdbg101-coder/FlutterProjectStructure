@echo off
if "%~1"=="" (
    echo Usage: .\scripts\generate-feature.bat FeatureName
    echo Example: .\scripts\generate-feature.bat Product
    exit /b 1
)
powershell -ExecutionPolicy Bypass -File "%~dp0generate-feature.ps1" %1
