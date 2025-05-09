#!/bin/bash

# Check if qemu is installed
qemu_path=$(which qemu-system-x86_64)
qemu_img_path=$(which qemu-img)
if [ -z "$qemu_path" ]; then
    echo "qemu is not installed. Please install qemu to run this script."
    exit 1
fi

# Create the build folder if it doesn't exist
build_folder="build"
if [ ! -d "$build_folder" ]; then
    echo "Creating build folder..."
    mkdir "$build_folder"
fi

# Check if debian-amd64.zip exists in the build folder
zip_file="$build_folder/debian-amd64.zip"
if [ ! -f "$zip_file" ]; then
    echo "debian-amd64.zip not found in the build folder. Downloading..."
    curl -L -o "$zip_file" "https://github.com/virtuosoft-dev/qemu-debian/releases/download/v12.10.0/debian-amd64.zip"
    echo "Download complete. Unzipping..."
    unzip -o "$zip_file" -d "$build_folder"
    echo "Unzipping complete."
else
    echo "debian-amd64.zip already exists in the build folder."
fi

