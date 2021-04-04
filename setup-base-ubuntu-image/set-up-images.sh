#!/bin/bash

export SCRIPT_DIR=$(dirname "$0")
export UBUNTU_IMAGE_NAME="ubuntu-1804-bionic-lts"

govc import.ova --options=bionic-server-cloudimg-amd64.ova.json \
	--name="ubuntu-1804-bionic-lts" \
	https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.ova

# PACKER_LOG=1 packer build mongo-host-packer.json
