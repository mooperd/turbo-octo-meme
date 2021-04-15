#!/bin/bash

set -euo pipefail

cd $(dirname "$0") && pwd

#Clean up ssh host idents
> /home/ubuntu/.ssh/known_hosts

export B64_TIMESTAMP=$(date '+%N' | base64)
export VAPP_PUBLIC_KEYS=$(cat ~/.ssh/id_rsa.pub)
export SCRIPT_DIR=$(dirname "$0")
export IMAGE_NAME="ubuntu-1804-bionic-lts-${VAPP_PUBLIC_KEYS:40:5}"
export VAPP_PUBLIC_KEYS=$(cat ~/.ssh/id_rsa.pub)
export VAPP_TEMPLATE="true"
export GOVC_BINARY_URL="https://github.com/vmware/govmomi/releases/download/v0.24.0/govc_linux_amd64.gz"
export GOVC_FILESYSTEM_LOCATION="bin/govc"
export ENV_SOURCE_FILESYSTEM_LOCATION="govc_env"
export UBUNTU_SOURCE_URL="https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.ova"
export VAPP_PASSWORD=""
# Get positional command line arguments
export CLUSTER_NAME=$1
export CLUSTER_SIZE=$2
export CLUSTER_TYPE=$3

# Test if govc is installed. Install it if not.
if test -f "$GOVC_FILESYSTEM_LOCATION"; then
    echo "$GOVC_FILESYSTEM_LOCATION exists."
else
    echo "$GOVC_FILESYSTEM_LOCATION does not exist. I will try and install it....."
    #Install govc 
    curl -L $GOVC_BINARY_URL | gunzip > $GOVC_FILESYSTEM_LOCATION && chmod +x $GOVC_FILESYSTEM_LOCATION
fi

# Test if I can source env vars
if test -f "$ENV_SOURCE_FILESYSTEM_LOCATION"; then
    echo "$ENV_SOURCE_FILESYSTEM_LOCATION exists. Sourcing it..."
    source $ENV_SOURCE_FILESYSTEM_LOCATION
else
    echo "$ENV_SOURCE_FILESYSTEM_LOCATION is not available. exiting."
    exit 1
fi

# Bit of a dirty hack
# See if there is already an vm template available. If not, then upload it!
if $(bin/govc find /*/vm | grep -w -q $IMAGE_NAME) 
    then
        echo "image \"$IMAGE_NAME\" is already available."
    else
        cat lib/vapp-properties-template.json | envsubst > tmp/$B64_TIMESTAMP.json
        bin/govc import.ova --options=tmp/$B64_TIMESTAMP.json --name="$IMAGE_NAME" $UBUNTU_SOURCE_URL
fi

# Create virtual machines

list_of_nodes=""
for i in $(seq 1 $CLUSTER_SIZE)
    do
        nodename=$CLUSTER_NAME-$i
	bin/govc vm.clone -vm $IMAGE_NAME -folder=databases -link=true -c=1 -m=1024 -on=false $nodename
        # bin/govc vm.disk.change -vm $nodename -size 3G
	# bin/govc tags.category.create -d "Cluster Name" cluster-name
	# bin/govc tags.attach -c cluster-name $CLUSTER_NAME /$GOVC_DATACENTER/vm/databases/$nodename

        list_of_nodes="$list_of_nodes $nodename"
    done

# Turn on new nodes
bin/govc vm.power -on $list_of_nodes

# wait for ip-addresses
list_of_ips=""
for i in $(seq 1 $CLUSTER_SIZE)
    do
        nodename=$CLUSTER_NAME-$i
        echo "getting IP address for node \"$nodename\". This might take a while."
	ip=$(bin/govc vm.ip -v4 -wait 5m $nodename)
	ssh $ip "sudo -S sysctl -w net.ipv6.conf.all.disable_ipv6=1; sudo -S sysctl -w net.ipv6.conf.default.disable_ipv6=1; sudo -S sysctl -w net.ipv6.conf.lo.disable_ipv6=1" 
	ssh $ip "sudo -S apt-get update; sudo -S apt-get upgrade -y"
        ssh $ip "echo 'Acquire::http::Proxy \"http://10.141.0.50:3142\";' | sudo tee -a /etc/apt/apt.conf.d/00aptproxy"
	list_of_ips="$list_of_ips,$ip"
    done

echo "$list_of_ips"

s9s cluster --create --cluster-type=postgresql --vendor=postgres --provider-version=11 --nodes="$list_of_ips" --db-admin="ubuntu" --db-admin-passwd="ubuntu" --os-user=ubuntu --cluster-name="$CLUSTER_NAME" --os-key-file="/home/ubuntu/.ssh/id_rsa" --wait
