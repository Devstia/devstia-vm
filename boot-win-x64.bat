:: Boot the VM asynchronously with QEMU Guest Agent communication enabled
start "" qemu-system-x86_64 ^
        -machine q35,vmport=off -accel whpx,kernel-irqchip=off ^
        -cpu qemu64-v1 ^
        -vga virtio ^
        -smp cpus=4,sockets=1,cores=4,threads=1 ^
        -m 4G ^
        -bios bios.img ^
        -display default,show-cursor=on ^
        -net nic -net user,hostfwd=tcp::8022-:22,hostfwd=tcp::80-:80,hostfwd=tcp::443-:443,hostfwd=tcp::8023-:8023 ^
        -drive if=virtio,format=qcow2,file=devstia-amd64.img ^
        -device virtio-balloon-pci ^
        -device virtio-serial-pci ^
        -chardev socket,path=\\.\pipe\qga,server=on,wait=off,id=qga0 ^
        -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 ^
        -nographic

