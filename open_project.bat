@echo off
rem Opens the I Will Get It project in the Godot editor.
set "GODOT=C:\Godot\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT%" (
    echo Godot not found at %GODOT%
    pause
    exit /b 1
)
start "" "%GODOT%" --path "%~dp0." -e
