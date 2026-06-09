@echo off
setlocal enabledelayedexpansion

REM package.bat — Package all skill directories into zip files under resources/
REM
REM Usage: package.bat
REM
REM For each directory in the project root that contains a SKILL.md file,
REM creates resources\<name>.zip, ready for import by cc-switch or similar tools.

set "ROOT_DIR=%~dp0"
set "RESOURCES_DIR=%ROOT_DIR%resources"

if exist "%RESOURCES_DIR%" rmdir /s /q "%RESOURCES_DIR%"
mkdir "%RESOURCES_DIR%"

set COUNT=0

for /d %%D in ("%ROOT_DIR%*") do (
    if exist "%%D\SKILL.md" (
        set "DIR_NAME=%%~nxD"
        set "ZIP_FILE=%RESOURCES_DIR%\!DIR_NAME!.zip"

        echo Packaging: !DIR_NAME! -^> !ZIP_FILE!

        REM PowerShell-based zip (built into Windows 7+)
        powershell -NoProfile -Command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%%D', '!ZIP_FILE!') }"

        set /a COUNT+=1
    )
)

if !COUNT! equ 0 (
    echo No skill directories (with SKILL.md) found in %ROOT_DIR%.
    rmdir "%RESOURCES_DIR%" 2>nul
    exit /b 0
)

echo.
echo Done. !COUNT! skill(s) packaged into: %RESOURCES_DIR%
for %%Z in ("%RESOURCES_DIR%*.zip") do (
    echo   %%~nZ.zip
)
