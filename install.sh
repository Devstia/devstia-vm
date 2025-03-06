#!/bin/bash
#
# Devstia VM Installation Script for Devstia Personal Web or Cloud Connect
# Project URI: https://github.com/devstia/devstia-vm
# Description: This script is used to kickstart installation of HestiaCP on a remote server
# Author: Virtuosoft/Stephen J. Carnam
# License AGPL-3.0, for other licensing options contact support@virtuosoft.com
#

# This script is used to install HestiaCP on a remote server
# Supply the connection details for the remote server and 
# the HestiaCP version to install
HESTIACP_VERSION="1.9.3"
DEVSTIA_DOMAIN="local.dev.pw" # Remote to Devstia Personal Web or Cloud Connect domain
remote_user="debian"
remote_password="personalweb"
remote_port="8022"

# Local script file to transfer
local_script_file="remote.sh"

# Remote script file destination
remote_script_file="/tmp/remote.sh"

# Warn user
clear
echo "!!! This script will take a LONG time to run. !!!"
echo "Please be patient and do not interrupt the process."
echo ""

# SSH connection and script transfer
sshpass -p "$remote_password" scp -o StrictHostKeyChecking=no -P "$remote_port" "$local_script_file" $remote_user@$DEVSTIA_DOMAIN:$remote_script_file

# SSH connection and script execution with sudo
sshpass -p "$remote_password" ssh -o StrictHostKeyChecking=no -p "$remote_port" $remote_user@$DEVSTIA_DOMAIN "echo '$remote_password' | sudo -S bash $remote_script_file --hestiacp-version $HESTIACP_VERSION --devstia-domain $DEVSTIA_DOMAIN"
echo "HestiaCP installation, plugins, and configurations are complete."

