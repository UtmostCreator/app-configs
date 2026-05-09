@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "OUT=ALL_IN_ONE.txt"
set "TYPES=*"
set "DEPTH=1"
set "ROOT=%CD%"
set "FIRST=1"
set "COUNT=0"

rem Usage:
rem   scan.bat
rem   scan.bat --types md,txt,php --depth 2
rem   scan.bat --types * --depth 0 --out ALL_IN_ONE.txt
rem
rem Depth:
rem   --depth 1 = current directory only
rem   --depth 2 = current directory + one nested level
rem   --depth 0 = unlimited recursive depth

:parse
if "%~1"=="" goto after_parse

set "ARG=%~1"

if /I "!ARG!"=="--help" goto usage

if /I "!ARG!"=="--out" (
  if "%~2"=="" goto usage
  set "OUT=%~2"
  shift
  shift
  goto parse
)

if /I "!ARG:~0,6!"=="--out=" (
  set "OUT=!ARG:~6!"
  shift
  goto parse
)

if /I "!ARG!"=="--types" (
  if "%~2"=="" goto usage
  set "TYPES=%~2"
  shift
  shift
  goto parse
)

if /I "!ARG:~0,8!"=="--types=" (
  set "TYPES=!ARG:~8!"
  shift
  goto parse
)

if /I "!ARG!"=="--depth" (
  if "%~2"=="" goto usage
  set "DEPTH=%~2"
  shift
  shift
  goto parse
)

if /I "!ARG:~0,8!"=="--depth=" (
  set "DEPTH=!ARG:~8!"
  shift
  goto parse
)

echo Unknown argument: %~1
exit /b 1

:after_parse
echo(%DEPTH%| findstr /R "^[0-9][0-9]*$" >nul
if errorlevel 1 (
  echo Invalid --depth value: "%DEPTH%".
  exit /b 1
)

for %%O in ("%OUT%") do set "OUT_ABS=%%~fO"
set "SCRIPT_ABS=%~f0"

if exist "%OUT_ABS%" del "%OUT_ABS%"

set "TYPE_LIST=%TYPES:,= %"
set "TYPE_LIST=%TYPE_LIST:;= %"

call :scan_dir "%ROOT%" 1

if !COUNT! EQU 0 (
  echo No matching files found in "%ROOT%".
  exit /b 1
)

echo Built "%OUT_ABS%" from !COUNT! file(s).
exit /b 0

:scan_dir
set "DIR=%~1"
set "LEVEL=%~2"

for %%F in ("%DIR%\*") do (
  if not exist "%%~fF\" (
    call :maybe_append "%%~fF"
  )
)

set /a NEXT_LEVEL=LEVEL + 1

if "%DEPTH%"=="0" (
  for /D %%D in ("%DIR%\*") do (
    call :scan_dir "%%~fD" !NEXT_LEVEL!
  )
) else (
  if %LEVEL% LSS %DEPTH% (
    for /D %%D in ("%DIR%\*") do (
      call :scan_dir "%%~fD" !NEXT_LEVEL!
    )
  )
)

exit /b 0

:maybe_append
set "FILE=%~1"

if /I "%FILE%"=="%SCRIPT_ABS%" exit /b 0
if /I "%FILE%"=="%OUT_ABS%" exit /b 0

set "MATCH=0"

if "%TYPES%"=="*" (
  set "MATCH=1"
) else (
  set "EXT=%~x1"
  set "EXT=!EXT:~1!"

  for %%T in (%TYPE_LIST%) do (
    set "T=%%~T"
    set "T=!T:*.=!"
    if "!T:~0,1!"=="." set "T=!T:~1!"

    if /I "!T!"=="!EXT!" set "MATCH=1"
  )
)

if "!MATCH!" NEQ "1" exit /b 0

set "REL=%FILE%"
set "REL=!REL:%ROOT%\=!"

if !FIRST! EQU 0 (
  for /L %%S in (1,1,3) do >> "%OUT_ABS%" echo(
)

>> "%OUT_ABS%" echo !REL!
>> "%OUT_ABS%" echo(
type "%FILE%" >> "%OUT_ABS%"

set "FIRST=0"
set /a COUNT+=1

exit /b 0

:usage
echo Usage:
echo   %~nx0
echo   %~nx0 --types md,txt,php --depth 2
echo   %~nx0 --types * --depth 0 --out ALL_IN_ONE.txt
echo.
echo Options:
echo   --types   File extensions to include. Example: md,txt,php,js
echo             Use * for all file types.
echo   --depth   1 = current directory only, 2 = one nested level, 0 = unlimited.
echo   --out     Output file path.
exit /b 1