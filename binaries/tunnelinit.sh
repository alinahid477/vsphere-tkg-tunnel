#!/bin/bash
export $(cat /root/.env | xargs)
export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)
chmod 600 /root/.ssh/id_rsa
printf "\n\n\n***********Starting tunnel...*************\n"



IS_KUBECTL_VSPHERE_EXISTS=$(kubectl vsphere)
if [ -z "$IS_KUBECTL_VSPHERE_EXISTS" ]
then 
    printf "\n\nkubectl vsphere not installed.\nChecking for binaries...\n"
    IS_KUBECTL_VSPHERE_BINARY_EXISTS=$(ls ~/binaries/ | grep kubectl-vsphere)
    if [ -z "$IS_KUBECTL_VSPHERE_BINARY_EXISTS" ]
    then            
        printf "\n\nDid not find kubectl-vsphere binary in ~/binaries/.\nDownloding in ~/binaries/ directory..."
        ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
        curl -kL https://localhost/wcp/plugin/linux-amd64/vsphere-plugin.zip -o ~/binaries/vsphere-plugin.zip
        unzip ~/binaries/vsphere-plugin.zip -d ~/binaries/vsphere-plugin/
        mv ~/binaries/vsphere-plugin/bin/kubectl-vsphere ~/binaries/
        rm -R ~/binaries/vsphere-plugin/
        rm ~/binaries/vsphere-plugin.zip
        fuser -k 443/tcp
        printf "\n\nkubectl-vsphere is now downloaded in ~/binaries/...\n"
    fi
    printf "\n\nAdjusting the dockerfile to incluse kubectl-binaries...\n"
    sed -i '/COPY binaries\/kubectl-vsphere \/usr\/local\/bin\//s/^# //' ~/Dockerfile
    sed -i '/RUN chmod +x \/usr\/local\/bin\/kubectl-vsphere/s/^# //' ~/Dockerfile

    printf "\n\nDockerfile is now adjusted with kubectl-vsphre.\n\n"
    printf "\n\nPlease rebuild the docker image and run again.\n\n"
    exit 1
fi


EXISTING_JWT_EXP=$(awk '/users/{flag=1} flag && /'$TKG_VSPHERE_CLUSTER_ENDPOINT'/{flag2=1} flag2 && /token:/ {print $NF;exit}' /root/.kube/config | jq -R 'split(".") | .[1] | @base64d | fromjson | .exp')

if [ -z "$EXISTING_JWT_EXP" ]
then
    EXISTING_JWT_EXP=$(date  --date="yesterday" +%s)
fi
CURRENT_DATE=$(date +%s)


if [ "$CURRENT_DATE" -gt "$EXISTING_JWT_EXP" ]
then
    printf "\n\n\n**********vSphere Cluster login...*************\n"

    if [ -z "$BASTION_HOST" ]
    then
        rm /root/.kube/config
        rm -R /root/.kube/cache
        if [ -z "$TKG_VSPHERE_CLUSTER_NAME" ]
        then
            printf "\n\n\n***********Login into Supervisor cluster...*************\n"
            kubectl vsphere login --insecure-skip-tls-verify --server $TKG_SUPERVISOR_ENDPOINT --vsphere-username $TKG_VSPHERE_CLUSTER_USERNAME
            kubectl config use-context $TKG_SUPERVISOR_ENDPOINT
        else
            printf "\n\n\n***********Login into Workload cluster...*************\n"            
            kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server kubernetes --insecure-skip-tls-verify -u $TKG_VSPHERE_CLUSTER_USERNAME
            kubectl config use-context $TKG_VSPHERE_CLUSTER_NAME
        fi
        
    else
        rm /root/.kube/config
        rm -R /root/.kube/cache
        if [ -z "$TKG_VSPHERE_CLUSTER_NAME" ]
        then
            printf "\n\n\n***********Creating Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"
            ssh-keyscan $BASTION_HOST > /root/.ssh/known_hosts
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$TKG_SUPERVISOR_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST

            printf "\n\n\n***********Login into Supervisor cluster...*************\n"
            kubectl vsphere login --insecure-skip-tls-verify --server kubernetes --vsphere-username administrator@vsphere.local
            sed -i 's/kubernetes/'$TKG_SUPERVISOR_ENDPOINT'/g' ~/.kube/config
            kubectl config use-context $TKG_SUPERVISOR_ENDPOINT
            sed -i '0,/'$TKG_SUPERVISOR_ENDPOINT'/s//kubernetes/' ~/.kube/config
        else
            printf "\n\n\n***********Creating Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"
            ssh-keyscan $BASTION_HOST > /root/.ssh/known_hosts
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$TKG_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST


            printf "\n\n\n***********Authenticating to cluster $TKG_VSPHERE_CLUSTER_NAME-->IP:$TKG_VSPHERE_CLUSTER_ENDPOINT  ...*************\n"
            # echo "debug: kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server kubernetes --insecure-skip-tls-verify -u $TKG_VSPHERE_CLUSTER_USERNAME"
            kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server kubernetes --insecure-skip-tls-verify -u $TKG_VSPHERE_CLUSTER_USERNAME
            # echo $RESULT
            # cat < ~/.kube/config

            printf "\n\n\n***********Adjusting your kubeconfig...*************\n"

            sed -i 's/kubernetes/'$TKG_SUPERVISOR_ENDPOINT'/g' ~/.kube/config
            kubectl config use-context $TKG_VSPHERE_CLUSTER_NAME

            sed -i '0,/'$TKG_VSPHERE_CLUSTER_ENDPOINT'/s//kubernetes/' ~/.kube/config
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$TKG_VSPHERE_CLUSTER_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST        
        fi
        
    fi
else
    printf "\n\n\nCuurent kubeconfig has not expired. Using the existing one found at .kube/config\n"
    if [ -n "$BASTION_HOST" ]
    then
        printf "\n\n\n***********Creating Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"

        if [ -z "$TKG_VSPHERE_CLUSTER_NAME" ]
        then
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$TKG_SUPERVISOR_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST
        else
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$TKG_VSPHERE_CLUSTER_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST
        fi
    fi
fi


printf "\n\n\n***********Verifying...*************\n"
kubectl get ns

while true; do
    read -p "Confirm if the above cluster is correct? [y/n] " yn
    case $yn in
        [Yy]* ) printf "\nyou confirmed yes\n"; break;;
        [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

printf "\n\n\nGoing into shell access.\n"

/bin/bash