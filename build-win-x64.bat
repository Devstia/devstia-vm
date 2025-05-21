:: This script is intended to be run in a Windows environment.
:: Work in progress... the build for mac-x64 is suitable for windows-x64

@echo off
setlocal enabledelayedexpansion

:: Check for qemu pre-requisite
if not exist "C:\Program Files\qemu\qemu-system-x86_64.exe" (
    echo QEMU is not installed. Exiting...
    exit /b 1
) else (
    echo QEMU is already installed.
)

:: Check if build folder exists
if not exist build\win_x64 (
    mkdir build\win_x64
)

:: Check and download base files
if not exist build\win_x64\debian-amd64.zip (
    echo Downloading debian-amd64.zip...
    set "DOWNLOAD_URL=https://github.com/virtuosoft-dev/qemu-debian/releases/download/v12.10.0/debian-amd64.zip"
    set "ZIP_FILE_PATH=build\win_x64\debian-amd64.zip"
    set "EXTRACT_PATH=build\win_x64"

    powershell -Command "$ProgressPreference = 'SilentlyContinue'; try { $webClient = New-Object System.Net.WebClient; $webClient.DownloadFile('!DOWNLOAD_URL!', '!ZIP_FILE_PATH!'); Write-Host 'debian-amd64.zip downloaded successfully.' } catch { Write-Error ('Exception during download: ' + $_.Exception.Message); if (Test-Path '!ZIP_FILE_PATH!') { Remove-Item '!ZIP_FILE_PATH!' }; exit 1 }"
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to download debian-amd64.zip.
        exit /b 1
    )

    echo Unzipping debian-amd64.zip...
    powershell -Command "Expand-Archive -Path '!ZIP_FILE_PATH!' -DestinationPath '!EXTRACT_PATH!' -Force"
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to unzip debian-amd64.zip.
        exit /b 1
    )
    echo debian-amd64.zip unzipped successfully.
) else (
    echo debian-amd64.zip already exists. Skipping download and unzip.
)

endlocal