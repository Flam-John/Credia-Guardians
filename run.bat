@echo off
rem Launch Credia Guardians (double-click me, or run from a terminal)
rem The trailing dot matters: %~dp0 ends with a backslash, which would
rem otherwise escape the closing quote.
"%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe" --path "%~dp0."
c