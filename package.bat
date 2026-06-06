@echo off
setlocal enabledelayedexpansion

REM package.bat — Package all .SKILL directories into zip files under resources/
REM
REM Usage: package.bat
REM
REM For each <name>.SKILL\ directory in the project root, creates
REM resources\<name>.zip, ready for import by cc-switch or similar tools.

set "ROOT_DIR=%~dp0"
set "RESOURCES_DIR=%ROOT_DIR%resources"

if exist "%RESOURCES_DIR%" rmdir /s /q "%RESOURCES_DIR%"
mkdir "%RESOURCES_DIR%"

set COUNT=0

for /d %%D in ("%ROOT_DIR%*.SKILL") do (
    set "DIR_NAME=%%~nxD"
    set "SKILL_NAME=%%~nD"

    REM Remove trailing .skill if double extension was captured
    REM Note: %%~nD already strips the last extension, so "kpi.SKILL" -> "kpi"
    REM This is the correct behavior out of the box.

    set "ZIP_FILE=%RESOURCES_DIR%\!SKILL_NAME!.zip"

    echo Packaging: !DIR_NAME! -^> !ZIP_FILE!

    REM PowerShell-based zip (built into Windows 7+)
    powershell -NoProfile -Command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%%D', '!ZIP_FILE!') }"

    set /a COUNT+=1
)

if !COUNT! equ 0 (
    echo No *.SKILL directories found in %ROOT_DIR%.
    rmdir "%RESOURCES_DIR%" 2>nul
    exit /b 0
)

echo.
echo Done. !COUNT! skill(s) packaged into: %RESOURCES_DIR%
for %%Z in ("%RESOURCES_DIR%*.zip") do (
    echo   %%~nZ.zip
)
