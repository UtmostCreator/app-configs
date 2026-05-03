@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT=%CD%"
set "OUT=%ROOT%\ALL_IN_ONE.txt"

if exist "%OUT%" del "%OUT%"

set "first=1"

rem Concatenate *.md files from current directory and all subfolders
for /R "%ROOT%" %%F in (*.md) do (
  set "FILE=%%~fF"

  rem Skip this script itself and the output file
  if /I not "!FILE!"=="%~f0" if /I not "!FILE!"=="%OUT%" (

    rem Add 3 blank lines between files, not before the first
    if !first! EQU 0 (
      for /L %%S in (1,1,3) do >> "%OUT%" echo(
    )

    rem Relative path header
    set "REL=!FILE:%ROOT%\=!"

    >> "%OUT%" echo !REL!
    >> "%OUT%" echo(
    type "%%F" >> "%OUT%"

    set "first=0"
  )
)

if !first! EQU 1 (
  echo No .md files found in "%ROOT%" or its subfolders.
  exit /b 1
) else (
  echo Built "%OUT%".
)