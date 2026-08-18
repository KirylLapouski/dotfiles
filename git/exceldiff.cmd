@echo off
setlocal EnableExtensions

rem Git external diff: path old-file old-hex old-mode new-file new-hex new-mode
rem Prefer excel_cmp next to this script, then PATH.
set "CMP=%~dp0excel_cmp.bat"
if not exist "%CMP%" set "CMP=excel_cmp.bat"

set "OLD=%~2"
set "NEW=%~5"
if /I "%OLD%"=="/dev/null" set "OLD=\\.\NUL"
if /I "%NEW%"=="/dev/null" set "NEW=\\.\NUL"
if /I "%OLD%"=="nul" set "OLD=\\.\NUL"
if /I "%NEW%"=="nul" set "NEW=\\.\NUL"

call "%CMP%" --diff_format=unified "%OLD%" "%NEW%"
exit /b 0
