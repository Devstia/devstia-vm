#!/bin/bash
#
# Virtuosoft build script for Devstia Personal Web (a localhost development server)
# on macOS Apple Silicon M1 64-bit compatible systems.
#

# Check if the CPU architecture indicates an ARM-based Mac
cpu_arch=$(sysctl -n machdep.cpu.brand_string)
if [[ $cpu_arch == *"Apple M"* ]]; then
    echo "This is an Apple Silicon M-processor based Mac."
else
    echo "This script is only compatible with Apple Silicon (M-processor based) Macs. Exiting..."
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcode-select &> /dev/null; then
    echo "Xcode is not installed. Installing..."
    xcode-select --install
else
    echo "Xcode is already installed."
fi

# macOS goof; just need to invoke sudo once prior, yet NOT for brew install
sudo whoami

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Installing..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew is already installed."
fi

# Check if sshpass is installed
if ! brew list --formula | grep -q '^sshpass$'; then
    echo "sshpass is not installed. Installing..."
    brew install --force hudochenkov/sshpass/sshpass
else
    echo "sshpass is already installed."
fi

# Check if QEMU is installed
if ! brew list --formula | grep -q '^qemu$'; then
    echo "QEMU is not installed. Installing..."
    brew install --force qemu
else
    echo "QEMU is already installed."
fi

# Check if build folder exists
if [ ! -d "build" ]; then
    echo "Creating the build folder..."
    mkdir "build"
    echo "Build folder created!"
else
    echo "Build folder already exists."
fi

# Check if EFI file already exists
if [ ! -f "build/efi_arm.img" ]; then
    echo "Copying EFI files..."
    cp /opt/homebrew/share/qemu/edk2-aarch64-code.fd build/efi_arm64.img
    dd if=/dev/zero of=build/efi_arm64_vars.img bs=1M count=64
else
    echo "EFI files already copied."
fi

# Check if ISO file already exists
DEBIAN_VERSION="12.9.0"
ISO_FILENAME="debian-$DEBIAN_VERSION-arm64-netinst.iso"
ISO_URL="https://mirrors.ocf.berkeley.edu/debian-cd/$DEBIAN_VERSION/arm64/iso-cd/$ISO_FILENAME"
if [ ! -f "build/$ISO_FILENAME" ]; then
    echo "Downloading Debian ISO..."
    curl -L -o "build/$ISO_FILENAME" "$ISO_URL"
    echo "Download complete."
else
    echo "Debian ISO already downloaded."
fi

## Create the virtual disk images with max ability at 2TB
if [ ! -f "build/devstia-arm64.img" ]; then
    qemu-img create -f qcow2 build/devstia-arm64.img 2000G
    echo "Virtual disk image created!"
else
    echo "Virtual disk image already exists. May not be clean; exiting."
    # Display a message
    echo "Press any key to continue..."

    # Pause the script until a key is pressed
    read -n 1 -s -r
    exit 1
fi


# Run QEMU with the following options to start the debian installation process
echo "Booting Debian Linux installer..."
cd build || exit
qemu-system-aarch64 \
        -machine virt -accel hvf \
        -cpu host \
        -vga none \
        -smp cpus=4,sockets=1,cores=4,threads=1 \
        -m 4G \
        -drive if=pflash,format=raw,file=efi_arm64.img,file.locking=off,readonly=on \
        -drive if=pflash,format=raw,file=efi_arm64_vars.img \
        -device nec-usb-xhci,id=usb-bus \
        -device usb-storage,drive=cdrom01,removable=true,bootindex=1,bus=usb-bus.0 -drive if=none,media=cdrom,id=cdrom01,file=$ISO_FILENAME,readonly=on \
        -device virtio-blk-pci,drive=drivedevstia-arm64,bootindex=0 \
        -drive if=none,media=disk,id=drivedevstia-arm64,file=devstia-arm64.img,discard=unmap,detect-zeroes=unmap \
        -device virtio-balloon-pci \
        -net nic -net user,hostfwd=tcp::8022-:22,hostfwd=tcp::80-:80,hostfwd=tcp::443-:443,hostfwd=tcp::8083-:8083 \
        -nographic
cd ..
