@echo off
echo Cleaning previous build...
call flutter clean
echo Building Flutter app for Windows...
call flutter build windows
if %errorlevel% neq 0 (
    echo Build failed.
    exit /b 1
)
echo Build successful. Executable located at build\windows\x64\runner\Release\BibleIO Viewer.exe
