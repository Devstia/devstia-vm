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
export DEBIAN_FRONTEND=noninteractive

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --hestiacp-version) HESTIACP_VERSION="$2"; shift ;;
        --devstia-domain) DEVSTIA_DOMAIN="$2"; shift ;;
        --remote-user) REMOTE_USER="$2"; shift ;;
        --remote-password) REMOTE_PASSWORD="$2"; shift ;;
        --remote-port) REMOTE_PORT="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Default values if not provided
HESTIACP_VERSION="${HESTIACP_VERSION:-1.9.3}"
DEVSTIA_DOMAIN="${DEVSTIA_DOMAIN:-local.dev.pw}" # Remote to Devstia Personal Web or Cloud Connect domain
REMOTE_USER="${REMOTE_USER:-debian}"
REMOTE_PASSWORD="${REMOTE_PASSWORD:-personalweb}"

# Conditional default for REMOTE_PORT
if [ -z "$REMOTE_PORT" ]; then
    if [ "$DEVSTIA_DOMAIN" == "local.dev.pw" ]; then
        REMOTE_PORT=8022
    else
        REMOTE_PORT=22
    fi
fi

# Local script file to transfer
LOCAL_SCRIPT_FILE="remote.sh"

# Remote script file destination
REMOTE_SCRIPT_FILE="/tmp/remote.sh"

# Warn user
clear
echo "!!! This script will take a LONG time to run. !!!"
echo "Please be patient and do not interrupt the process."
echo ""

# SSH connection and script transfer
sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -P "$REMOTE_PORT" "$LOCAL_SCRIPT_FILE" $REMOTE_USER@$DEVSTIA_DOMAIN:$REMOTE_SCRIPT_FILE

# SSH connection and script execution with sudo
sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$REMOTE_PORT" $REMOTE_USER@$DEVSTIA_DOMAIN "echo '$REMOTE_PASSWORD' | sudo -S bash $REMOTE_SCRIPT_FILE --hestiacp-version $HESTIACP_VERSION --devstia-domain $DEVSTIA_DOMAIN"
echo "HestiaCP installation, plugins, and configurations are complete."