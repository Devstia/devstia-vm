# devstia-vm
Scripts to create platform and architecture specific virtual machines for the Devstia Personal Web application.

> :warning: !!! Note: this repo is in progress; when completed, a release will appear in the release tab.

## Building
Building a specific virtual machine for a given host requires running under the host operating system for the given script.

> :triangular_flag_on_post: Devstia Personal Web is distributed under GNU **Affero** General Public License v3.0. *Any modified version, including use as a service over a network, requires that the complete source code of the modified version must be made available*.

#### 1) Start by cloning this repo [via git](https://git-scm.com) to a local folder, followed by changing directories to that folder:
```
git clone https://github.com/virtuosoft-dev/devstia-vm devstia-vm
cd devstia-vm
```

#### 2) Next, execute the given shell script on your operating system's CLI/terminal:

* macOS x64
```
source ./build-vm-mac-amd64.sh
```
* macOS M1
```
source ./build-vm-mac-arm64.sh
```
* Windows x64
```
./build-devstia-vm-amd64.bat
```
<!--
* Linux x64
```
./build-vm-lnx-amd64.sh
```
* Linux aarch64
```
./build-vm-lnx-arm64.sh
```
-->
#### 3) Follow the instructions for **[Install Debian Linux](install-debian-linux.md)**

#### 4) Follow the instructions for **[Install HestiaCP](install-hestiacp.md)**

#### 5) Follow the instructions for **[Install HCPP](install-hcpp.md)**

## Support the creator
You can help this author's open source development endeavors by donating any amount to Stephen J. Carnam @ Virtuosoft. Your donation, no matter how large or small helps pay for essential time and resources to create MIT and GPL licensed projects that you and the world can benefit from. Click the link below to donate today :)
<div>
         

[<kbd> <br> Donate to this Project <br> </kbd>][KBD]


</div>


<!---------------------------------------------------------------------------->

[KBD]: https://virtuosoft.com/donate

https://virtuosoft.com/donate
