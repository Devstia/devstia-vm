@echo off
::
:: Virtuosoft build script for Devstia Personal Web (a localhost development server)
:: on Windows x86 64-bit compatible systems.
::

:: Check if QEMU is installed
if not exist "C:\Program Files\qemu\qemu-system-x86_64.exe" (
    echo QEMU is not installed. Downloading and installing...
    curl -o qemu-w64-setup-20230424.exe https://qemu.weilnetz.de/w64/2023/qemu-w64-setup-20230822.exe
    qemu-w64-setup-20230424.exe /S
    del qemu-w64-setup-20230424.exe
    echo QEMU installation completed.
) else (
    echo QEMU is already installed.
)
set PATH=%PATH%;"C:\Program Files\qemu"

:: Check if build folder exists
if not exist build (
    echo Creating build folder...
    mkdir build
    echo Build folder created.
) else (
    echo Build folder already exists.
)

:: Check if BIOS file already exists
if not exist "build\bios.img" (
    echo Copying BIOS file...
    copy "C:\Program Files\qemu\share\bios.bin" "build\bios.img"
) else (
    echo BIOS file already copied.
)

:: Check if ISO file already exists
set DEBIAN_VERSION="12.9.0"
set ISO_FILENAME="debian-%DEBIAN_VERSION%-amd64-netinst.iso"
set ISO_URL="https://cdimage.debian.org/cdimage/archive/%DEBIAN_VERSION%/amd64/iso-cd/%ISO_FILENAME%"
if not exist "build\%ISO_FILENAME%" (
    echo Downloading Debian ISO...
    curl -L -o "build\%ISO_FILENAME%" "%ISO_URL%"
    echo Download complete.
) else (
    echo Debian ISO already downloaded.
)

:: Create the virtual disk images with the max abilitiy of 2TB
if not exist "build\devstia-amd64.img" (
    qemu-img create -f qcow2 build\devstia-amd64.img 2000G
    echo Virtual disk image created!
) else (
    echo Virtual disk image already created.
    REM exit
)

:: Run QEMU with the following options to start the debian installation process
echo Booting Debian Linux installer...
cd /d build || exit /b
qemu-system-x86_64 ^
        -machine q35,vmport=off -accel whpx,kernel-irqchip=off ^
        -cpu qemu64-v1 ^
        -vga virtio ^
        -smp cpus=4,sockets=1,cores=4,threads=1 ^
        -m 4G ^
        -bios bios.img ^
        -cdrom %ISO_FILENAME% ^
        -display default,show-cursor=on ^
        -net nic -net user,hostfwd=tcp::8022-:22,hostfwd=tcp::80-:80,hostfwd=tcp::443-:443,hostfwd=tcp::8023-:8023 ^
        -drive if=virtio,format=qcow2,file=devstia-amd64.img ^
        -device virtio-balloon-pci
cd ..
