## Install HestiaCP
Next, you will want to install the Hestia Control Panel project. At this point the QEMU virtual machine instance should still be running and at the login prompt; leave this running. In another terminal window, we will run the install.sh script; it will connect to the VM instance and execute the commands needed to configure our VM and install HestiaCP and Virtuosoft's Devstia extensions.

* Start your OS' shell (i.e. Terminal.app in macOS) and `cd` into this project's folder, then enter the command:

```
./install.sh
```
Please be patient while this process will take quite a bit of time to download, install, and configure HestiaCP.

After the script completes, the VM should automatically shutdown. 

If this is for Devstia Personal Web edition; the main script will continue with compressing the resulting devstia-amd64.img (or devstia-arm64.img for ARM processors), along with their required EFI images into a compact, redistributable archive for use with the Devstia Personal Web application; [devstia-app](https://github.com/virtuosoft-dev/devstia-app). The resulting filename will be either devstia-amd64.tar.xz and/or devstia-arm64.tar.xz.

&nbsp;

-----
&nbsp;

Return to the **[README.md](README.md)** for additional instructions and up-to-date information.
