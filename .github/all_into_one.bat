@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "OUT=ALL_IN_ONE.txt"
if exist "%OUT%" del "%OUT%"

set "first=1"

rem Only concatenate *.md files in the current directory
for %%F in (*.*) do (
  rem Skip this script itself and the output file (in case OUT has .md)
  if /I not "%%~nxF"=="%~nx0" if /I not "%%~nxF"=="%OUT%" (

    rem Add 3 blank lines between files (not before the first)
    if !first! EQU 0 (
      for /L %%S in (1,1,3) do >> "%OUT%" echo(
    )

    rem Write filename header, then the file content
    >> "%OUT%" echo %%~nxF
    >> "%OUT%" echo(
    type "%%F" >> "%OUT%"

    set "first=0"
  )
)

if !first! EQU 1 (
  echo No .md files found in "%cd%".
  exit /b 1
) else (
  echo Built "%OUT%".
)
