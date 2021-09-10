#!/bin/bash
export $(cat /root/.env | xargs)
export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)
chmod 600 /root/.ssh/id_rsa
printf "\n\nsetting executable permssion to all binaries sh\n\n"
ls -l /root/binaries/*.sh | awk '{print $9}' | xargs chmod +x

source ~/binaries/tunnel.sh

printf "\nAvailable wizards are:\n"
source ~/binaries/tunnel.sh --help
printf "\n=========================================================\n"
source ~/binaries/create-cluster.sh --help

cd ~

/bin/bash