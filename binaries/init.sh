#!/bin/bash

printf "\n\n//// EXECUTING INIT SCRIPT ////\n\n"
printf "copying shared/.env file..."
if [[ -f /home/shared/.env ]]
then
  cp /home/shared/.env $HOME/.env && printf "DONE\n"
else
  printf "NOT FOUND\n"  
fi
sleep 1
printf "copying contents in shared/.ssh ..."
cp /home/shared/.ssh/* $HOME/.ssh/ && printf "DONE\n" || printf "ERROR\n"
sleep 1

printf "\n\nLoading environment variables from .env file..."
test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)
test -f $HOME/.env && printf "DONE\n" || printf "ERROR\n"
sleep 1
if [[ -n $BASTION_HOST ]]
then
    printf "\n\nBastion / Jump host detected (value in .env file). Making adjustment if id_rsa file..."
    if [[ -f $HOME/.ssh/id_rsa ]]
    then
        chmod 600 $HOME/.ssh/id_rsa && printf "DONE\n"
    else
        printf "ERROR: FILE_NOT_FOUND\n"
    fi
fi


# merlin files cache location
if [[ ! -d  "/home/shared/scripts" ]]
then
    mkdir -p /home/shared/scripts
fi

if [[ ! -d  "$HOME/binaries/scripts" ]]
then
    mkdir -p $HOME/binaries/scripts
fi

if [[ ! -f /home/shared/scripts/download-common-scripts.sh ]]
then
    printf "\n\nDownloading Merlin files...\n"
    curl -L https://raw.githubusercontent.com/alinahid477/common-merlin-scripts/main/scripts/download-common-scripts.sh -o $HOME/binaries/scripts/download-common-scripts.sh
    sleep 1
    chmod +x $HOME/binaries/scripts/download-common-scripts.sh
    sleep 1
else
    cp /home/shared/scripts/download-common-scripts.sh $HOME/binaries/scripts/download-common-scripts.sh
    chmod +x $HOME/binaries/scripts/download-common-scripts.sh
fi

if [[ ! -f /home/shared/scripts/returnOrexit.sh ]]
then
    if [[ ! -d  "$HOME/binaries/scripts" ]]
    then
        mkdir -p $HOME/binaries/scripts
    fi
    printf "\n...."
    $HOME/binaries/scripts/download-common-scripts.sh tanzucli scripts
    sleep 1
    printf "\n...."
    $HOME/binaries/scripts/download-common-scripts.sh minimum scripts
    sleep 1
    if [[ -n $BASTION_HOST ]]
    then
        printf "\n...."
        $HOME/binaries/scripts/download-common-scripts.sh bastion scripts/bastion
        sleep 1
    fi

    # Below block is to prevent merlin files download everytime the container starts.
    #    we want to download files only first run. 
    #    so we need to cache it in shared dir.
    cp -r $HOME/binaries/scripts/* /home/shared/scripts/

    printf "\nMerlin's files download ... DONE\n\n"
else 
    printf "\n\nCopying Merlin files from cache location /home/shared/scripts..."
    cp -r /home/shared/scripts/* $HOME/binaries/scripts/ && printf "DONE\n\n" || printf "ERR\n\n"
fi


printf "\nSetting executable permssion to all binaries sh...\n"
ls -l $HOME/binaries/*.sh | awk '{print $9}' | xargs chmod +x
ls -l $HOME/binaries/tanzuwizard/*.sh | awk '{print $9}' | xargs chmod +x
printf "File permission set...DONE\n"
sleep 1

IS_KUBECTL_VSPHERE_EXISTS=$(kubectl vsphere)
if [ -z "$IS_KUBECTL_VSPHERE_EXISTS" ]
then 
    printf "\n\nkubectl vsphere not installed.\nChecking for binaries...\n"
    IS_KUBECTL_VSPHERE_BINARY_EXISTS=$(ls ~/binaries/ | grep kubectl-vsphere)
    if [ -z "$IS_KUBECTL_VSPHERE_BINARY_EXISTS" ]
    then            
        printf "\n\nDid not find kubectl-vsphere binary in ~/binaries/.\nDownloding in ~/binaries/ directory..."
        if [[ -n $BASTION_HOST && -f $HOME/.ssh/id_rsa ]]
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
if [[ -n $BASTION_HOST && -f $HOME/.ssh/id_rsa ]]
then
    printf "\nCreating docker remote context called bastion...\n"
cat > ~/.ssh/config <<-EOF
Host $BASTION_HOST
    HostName $BASTION_HOST
    User $BASTION_USERNAME
    IdentityFile ~/.ssh/id_rsa
EOF
    docker context create bastion --docker "host=ssh://$BASTION_USERNAME@$BASTION_HOST"
fi

if [[ -n $TKG_SUPERVISOR_ENDPOINT ]]
then
    printf "\n\nConnecting to TKG (supervisor or workload) as per .env...\n"
    source ~/binaries/tkgwizard.sh
    dotkgwizard 'n' 'n' 'n' 'n' 'y'
fi

printf "\n\n"
printf "\n=========================================================\n"
printf "\nSee options:\n"
printf "merlin --help"
printf "\n=========================================================\n"
printf "\n\n"
cd ~
/bin/bash