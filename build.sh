#!/bin/bash
#
# This script is used to build our Devstia VM using QEMU on macOS.
#

# Install/build options
HESTIACP_VERSION="1.9.3"
DEVSTIA_DOMAIN="cp-local.dev.pw"

# Check if qemu is installed
if [ "$(uname -m)" == "aarch64" ]; then
    qemu_path=$(which qemu-system-aarch64)
else
    qemu_path=$(which qemu-system-x86_64)
fi
if [ -z "$qemu_path" ]; then
    echo "qemu is not installed. Please install qemu to run this script."
    exit 1
fi

# Check if sshpass is installed
if ! brew list --formula | grep -q '^sshpass$'; then
    echo "sshpass is not installed. Installing..."
    brew install --force hudochenkov/sshpass/sshpass
else
    echo "sshpass is already installed."
fi

# Create the build folder if it doesn't exist
if [ ! -d "build" ]; then
    echo "Creating build folder..."
    mkdir "build"
fi

# Check if debian exists in the build folder
if [ "$(uname -m)" == "aarch64" ]; then
    zip_file="debian-arm64.zip"
else
    zip_file="debian-amd64.zip"
fi
if [ ! -f "build/$zip_file" ]; then
    echo "debian not found in the build folder. Downloading..."
    curl -L -o "build/$zip_file" "https://github.com/virtuosoft-dev/qemu-debian/releases/download/v12.11.0/${zip_file}"
    echo "Download complete. Unzipping..."
    unzip -o "build/$zip_file" -d "build"
    echo "Unzipping complete."
else
    echo "debian already exists in the build folder."
fi

# Check the overlay image exists and remove it
if [ -f "build/$DEVSTIA_DOMAIN.img" ]; then
    echo "Removing old overlay image..."
    rm -f "build/$DEVSTIA_DOMAIN.img"
fi

cd build
echo "Creating overlay image..."
if [ "$(uname -m)" == "aarch64" ]; then
    qemu-img create -f qcow2 -o backing_file=./debian-arm64.img,backing_fmt=qcow2 $DEVSTIA_DOMAIN.img
else
    qemu-img create -f qcow2 -o backing_file=./debian-amd64.img,backing_fmt=qcow2 $DEVSTIA_DOMAIN.img
fi
echo "Overlay image created."

# Spawn the VM with the debian-amd64 base image asynchronously
echo "Booting our Debian Linux system..."
if [ "$(uname -m)" == "aarch64" ]; then
    qemu-system-aarch64 \
        -machine virt -accel hvf \
        -cpu host \
        -vga none \
        -smp cpus=4,sockets=1,cores=4,threads=1 \
        -m 4G \
        -drive if=pflash,format=raw,file=efi.img,file.locking=off,readonly=on \
        -drive if=pflash,format=raw,file=efi_vars.img \
        -device virtio-blk-pci,drive=drivedevstia-arm64,bootindex=0 \
        -drive if=none,media=disk,id=drivedevstia-arm64,file=$DEVSTIA_DOMAIN,discard=unmap,detect-zeroes=unmap \
        -device virtio-balloon-pci \
        -device virtio-serial-pci \
        -chardev socket,path=/tmp/qga.sock,server=on,wait=off,id=qga0 \
        -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
        -net nic -net user,hostfwd=tcp::8022-:22,hostfwd=tcp::80-:80,hostfwd=tcp::443-:443,hostfwd=tcp::8083-:8083 \
        -nographic
else
    qemu-system-x86_64 \
        -machine q35,vmport=off -accel hvf \
        -cpu qemu64-v1 \
        -vga virtio \
        -smp cpus=4,sockets=1,cores=4,threads=1 \
        -m 4G \
        -bios bios.img \
        -display default,show-cursor=on \
        -net nic -net user,hostfwd=tcp::8022-:22,hostfwd=tcp::80-:80,hostfwd=tcp::443-:443,hostfwd=tcp::8083-:8083 \
        -drive if=virtio,format=qcow2,file=$DEVSTIA_DOMAIN.img \
        -device virtio-balloon-pci \
        -device virtio-serial-pci \
        -chardev socket,path=/tmp/qga.sock,server=on,wait=off,id=qga0 \
        -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
        -nographic &
fi

# Capture the PID of the QEMU process
qemu_pid=$!
sleep 10
clear
echo "QEMU is running with PID $qemu_pid"

cd ..

# Wait for the VM to boot and respond to qemu-guest-exec
echo "Waiting for the VM to boot..."
for i in {1..60}; do
    sleep 1
    response=$(./qemu-guest-exec whoami | tr -d '\r\n') # Trim the response
    echo $response
    if [[ "$response" == "root" ]]; then
        echo "VM is up and running."
        break
    fi
done

if [[ "$response" != "root" ]]; then
    echo "VM did not respond as expected. Exiting."
    exit 1
fi

# Copy remote.sh file to the VM for installation
sshpass -p 'debian' scp -P 8022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ./remote.sh debian@localhost:/tmp/

# Execute the remote.sh script
echo "Executing remote.sh script on the VM..."
sshpass -p 'debian' ssh -tt -p 8022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null debian@localhost "echo 'debian' | sudo -S /tmp/remote.sh"

# Wait for qemu_pid to finish
wait $qemu_pid
echo "QEMU process $qemu_pid has finished."

# Generate date tag in YYMMDD format
DATE_TAG=$(date +%y%m%d)
if [ "$(uname -m)" == "aarch64" ]; then
    DEVSTIA_RUNTIME=cp-local${DATE_TAG}-arm64
else
    DEVSTIA_RUNTIME=cp-local${DATE_TAG}-amd64
fi

# Combine the overlay image with the base image
cd build
echo "Combining the overlay image with the base image into runtime image..."
qemu-img convert -O qcow2 -o compat6,force_size=on $DEVSTIA_DOMAIN.img ./$DEVSTIA_RUNTIME.img

# Compress the image into a tar.xz file
echo "Compressing runtime image into a tar.xz file..."
tar -cJf "$DEVSTIA_RUNTIME.tar.xz" "$DEVSTIA_RUNTIME.img"
echo "Compression complete."

# Check if the tar.xz is larger than 2000M, if so, split it into 2000M chunks
filesize=$(stat -f%z "$DEVSTIA_RUNTIME.tar.xz")
if [ "$filesize" -gt $((2000 * 1000 * 1000)) ]; then
    echo "Splitting the tar.xz file into 2000M chunks..."
    split -b 2000M "$DEVSTIA_RUNTIME.tar.xz" "$DEVSTIA_RUNTIME.part"
    echo "Splitting complete."
else
    echo "The tar.xz file is less than 2000M. No need to split."
fi
cd ..
