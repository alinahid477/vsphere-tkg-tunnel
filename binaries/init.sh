#!/bin/bash

test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)

if [[ -f $HOME/.ssh/id_rsa ]]
then
    chmod 600 $HOME/.ssh/id_rsa
fi


if [[ ! -f $HOME/binaries/scripts/download-common-scripts.sh ]]
then
    if [[ ! -d  "$HOME/binaries/scripts" ]]
    then
        mkdir -p $HOME/binaries/scripts
    fi
    printf "\n\n************Downloading Merlin file Getter**************\n\n"
    curl -L https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts/download-common-scripts.sh -o $HOME/binaries/scripts/download-common-scripts.sh
    sleep 1
    chmod +x $HOME/binaries/scripts/download-common-scripts.sh
    sleep 1
    printf "\n\n\n///////////// COMPLETED //////////////////\n\n\n"
    printf "\n\n"
fi


if [[ ! -f $HOME/binaries/scripts/returnOrexit.sh ]]
then
    if [[ ! -d  "$HOME/binaries/scripts" ]]
    then
        mkdir -p $HOME/binaries/scripts
    fi
    printf "\n\n************Downloading Common Scripts**************\n\n"
    $HOME/binaries/scripts/download-common-scripts.sh tanzucli scripts
    sleep 1
    if [[ -n $BASTION_HOST ]]
    then
        $HOME/binaries/scripts/download-common-scripts.sh bastion scripts/bastion
        sleep 1
    fi
    printf "\n\n\n///////////// COMPLETED //////////////////\n\n\n"
    printf "\n\n"
fi


printf "\n\nsetting executable permssion to all binaries sh\n\n"
ls -l $HOME/binaries/*.sh | awk '{print $9}' | xargs chmod +x
ls -l $HOME/binaries/tanzuwizard/*.sh | awk '{print $9}' | xargs chmod +x


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
            ssh -i $HOME/.ssh/id_rsa -4 -fNT -L 443:$TKG_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
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

#echo dev | sudo -S chmod 666 /var/run/docker.sock
cat > ~/.ssh/config <<-EOF
Host $BASTION_HOST
     HostName $BASTION_HOST
     User $BASTION_USERNAME
     IdentityFile ~/.ssh/id_rsa
EOF
docker context create bastion --docker "host=ssh://$BASTION_USERNAME@$BASTION_HOST"

source ~/binaries/tkgwizard.sh
dotkgwizard 'n' 'n' 'n' 'n' 'y'

printf "\n\n"
printf "\n=========================================================\n"
printf "\nSee options:\n"
printf "merlin --help"
printf "\n=========================================================\n"
printf "\n\n"
cd ~
/bin/bash