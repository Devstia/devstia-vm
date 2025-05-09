#!/bin/bash

# Check if qemu is installed
qemu_path=$(which qemu-system-x86_64)
qemu_img_path=$(which qemu-img)
if [ -z "$qemu_path" ]; then
    echo "qemu is not installed. Please install qemu to run this script."
    exit 1
fi

# Create the build folder if it doesn't exist
if [ ! -d "build" ]; then
    echo "Creating build folder..."
    mkdir "build"
fi

# Check if debian-amd64.zip exists in the build folder
zip_file="build/debian-amd64.zip"
if [ ! -f "$zip_file" ]; then
    echo "debian-amd64.zip not found in the build folder. Downloading..."
    curl -L -o "$zip_file" "https://github.com/virtuosoft-dev/qemu-debian/releases/download/v12.10.0/debian-amd64.zip"
    echo "Download complete. Unzipping..."
    unzip -o "$zip_file" -d "build"
    echo "Unzipping complete."
else
    echo "debian-amd64.zip already exists in the build folder."
fi

# Check the overlay image exists and remove it
if [ -f "build/cp-local001.dev.pw.img" ]; then
    echo "Removing old overlay image..."
    rm -f "build/cp-local001.dev.pw.img"
fi

cd build
echo "Creating overlay image..."
qemu-img create -f qcow2 -o backing_file=./debian-amd64.img,backing_fmt=qcow2 cp-local001.dev.pw.img
echo "Overlay image created."

# Spawn the VM with the debian-amd64 base image asynchronously
echo "Booting our Debian Linux system..."
qemu-system-x86_64 \
    -machine q35,vmport=off -accel hvf \
    -cpu qemu64-v1 \
    -vga virtio \
    -smp cpus=4,sockets=1,cores=4,threads=1 \
    -m 4G \
    -bios bios.img \
    -display default,show-cursor=on \
    -net nic -net user,hostfwd=tcp::8022-:22,hostfwd=tcp::80-:80,hostfwd=tcp::443-:443,hostfwd=tcp::8083-:8083 \
    -drive if=virtio,format=qcow2,file=cp-local001.dev.pw.img \
    -device virtio-balloon-pci \
    -device virtio-serial-pci \
    -chardev socket,path=/tmp/qga.sock,server=on,wait=off,id=qga0 \
    -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
    -nographic
