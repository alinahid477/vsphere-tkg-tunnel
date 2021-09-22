#!/bin/bash
export $(cat /root/.env | xargs)
export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)
chmod 600 /root/.ssh/id_rsa
printf "\n\nsetting executable permssion to all binaries sh\n\n"
ls -l /root/binaries/*.sh | awk '{print $9}' | xargs chmod +x


IS_KUBECTL_VSPHERE_EXISTS=$(kubectl vsphere)
if [ -z "$IS_KUBECTL_VSPHERE_EXISTS" ]
then 
    printf "\n\nkubectl vsphere not installed.\nChecking for binaries...\n"
    IS_KUBECTL_VSPHERE_BINARY_EXISTS=$(ls ~/binaries/ | grep kubectl-vsphere)
    if [ -z "$IS_KUBECTL_VSPHERE_BINARY_EXISTS" ]
    then            
        printf "\n\nDid not find kubectl-vsphere binary in ~/binaries/.\nDownloding in ~/binaries/ directory..."
        if [[ -n $BASTION_HOST ]]
        then
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
            curl -kL https://localhost/wcp/plugin/linux-amd64/vsphere-plugin.zip -o ~/binaries/vsphere-plugin.zip
            sleep 1
            fuser -k 443/tcp
        else 
            curl -kL https://$TKG_SUPERVISOR_ENDPOINT/wcp/plugin/linux-amd64/vsphere-plugin.zip -o ~/binaries/vsphere-plugin.zip
        fi            
        unzip ~/binaries/vsphere-plugin.zip -d ~/binaries/vsphere-plugin/
        mv ~/binaries/vsphere-plugin/bin/kubectl-vsphere ~/binaries/
        rm -R ~/binaries/vsphere-plugin/
        rm ~/binaries/vsphere-plugin.zip
        printf "\n\nkubectl-vsphere is now downloaded in ~/binaries/...\n"
    fi
    printf "\n\nAdjusting the dockerfile to incluse kubectl-binaries...\n"
    sed -i '/COPY binaries\/kubectl-vsphere \/usr\/local\/bin\//s/^# //' ~/Dockerfile
    sed -i '/RUN chmod +x \/usr\/local\/bin\/kubectl-vsphere/s/^# //' ~/Dockerfile

    printf "\n\nDockerfile is now adjusted with kubectl-vsphre.\n\n"
    printf "\n\nPlease rebuild the docker image and run again.\n\n"
    exit 1
fi


source ~/binaries/tunnel.sh

printf "\nAvailable wizards are:\n"
source ~/binaries/tunnel.sh --help
printf "\n=========================================================\n"
source ~/binaries/create-cluster.sh --help

cd ~

/bin/bash