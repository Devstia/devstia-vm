#!/bin/bash

#
# Remote script to install and configure our HCPP (Hestia Control Panel Plugins).
# This script is run on the remote server with sudo permissions from the /tmp directory; it
# is invoked by the install-hcpp.sh script.
#

echo ""
echo "Starting automated HCPP installation"
echo "This will take a long while, please be patient..."
sleep 1

# Install HestiaCP Pluginable project
cd /tmp
git clone --depth 1 --branch "v1.0.0-beta.1" https://github.com/virtuosoft-dev/hestiacp-pluginable.git 2>/dev/null
mv hestiacp-pluginable/hooks /etc/hestiacp
rm -rf hestiacp-pluginable-main
/etc/hestiacp/hooks/post_install.sh
service hestia restart

# Install HCPP NodeApp
cd /usr/local/hestia/plugins
git clone --depth 1 --branch "v1.0.0" https://github.com/virtuosoft-dev/hcpp-nodeapp.git nodeapp 2>/dev/null
cd /usr/local/hestia/plugins/nodeapp
./install
touch "/usr/local/hestia/data/hcpp/installed/nodeapp"

# Install HCPP NodeRED
cd /usr/local/hestia/plugins
git clone --depth 1 --branch "v1.0.0" https://github.com/virtuosoft-dev/hcpp-nodered.git nodered 2>/dev/null
cd /usr/local/hestia/plugins/nodered
./install
touch "/usr/local/hestia/data/hcpp/installed/nodered"

# Install HCPP MailCatcher
cd /usr/local/hestia/plugins
git clone --depth 1 --branch "v1.0.0" https://github.com/virtuosoft-dev/hcpp-mailcatcher.git mailcatcher 2>/dev/null
cd /usr/local/hestia/plugins/mailcatcher
./install
touch "/usr/local/hestia/data/hcpp/installed/mailcatcher"

## TODO: install each component one-at-a-time...
##
# * [HestiaCP-NodeRED](https://github.com/virtuosoft-dev/hcpp-nodered)
# * [HestiaCP-MailCatcher](https://github.com/virtuosoft-dev/hcpp-mailcatcher)
# * [HestiaCP-VSCode](https://github.com/virtuosoft-dev/hcpp-vscode)
# * [HestiaCP-NodeBB](https://github.com/virtuosoft-dev/hcpp-nodebb)
# * [HestiaCP-Ghost](https://github.com/virtuosoft-dev/hcpp-ghost)

# Shutdown the server
echo "Shutting down the server."
shutdown now


