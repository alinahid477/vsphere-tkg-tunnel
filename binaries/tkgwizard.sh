#!/bin/bash

function dotkgwizard() {

    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
    export KUBECTL_VSPHERE_PASSWORD=$TKG_VSPHERE_CLUSTER_PASSWORD

    local switchtosupervisor=$1
    local switchtoworkload=$2
    local clusterendpoint=$3
    local clustername=$4
    local getfromenvironmentvariables=$5

    local isexists=''
    local isok='n'

    if [[ $switchtosupervisor == 'y' ]]
    then
        unset TKG_VSPHERE_CLUSTER_ENDPOINT
        unset TKG_VSPHERE_CLUSTER_NAME
        isok='y'
        printf "\n\n--- Switching to supervisor $TKG_SUPERVISOR_ENDPOINT ---\n\n"
    elif [[ $switchtoworkload == 'y' && -n $clusterendpoint && -n $clustername ]]
    then
        export TKG_VSPHERE_CLUSTER_ENDPOINT=$(echo $clusterendpoint | xargs)
        export TKG_VSPHERE_CLUSTER_NAME=$(echo $clustername | xargs) 
        isok='y'
        printf "\n\n--- Switching to worker $clustername-->$clusterendpoint ---\n\n"
    elif [[ $getfromenvironmentvariables == 'y' ]]
    then
        isok='y'
        printf "\n\n--- Login based on env variables ---\n\n"
    fi


    if [[ $isok == 'y' ]]
    then
        isexists=$(netstat -ntlp | grep 6443)
        if [[ -n $isexists ]]
        then
            fuser -k 6443/tcp >> /dev/null
        fi
        isexists=$(netstat -ntlp | grep 443)
        if [[ -n $isexists ]]
        then
            fuser -k 443/tcp >> /dev/null
        fi
        if [[ -f $HOME/.kube/config ]]
        then
            rm $HOME/.kube/config
        fi
    else
        printf "\nplease provide appropriate parameters. merlin --help.\n"
        return
    fi

    isok=''

    printf "\n\n\n***********Starting connection...*************\n"

    if [[ -f $HOME/.kube/config ]]
    then
        EXISTING_JWT_EXP=$(awk '/users/{flag=1} flag && /'$TKG_VSPHERE_CLUSTER_ENDPOINT'/{flag2=1} flag2 && /token:/ {print $NF;exit}' $HOME/.kube/config | jq -R 'split(".") | .[1] | @base64d | fromjson | .exp')
    fi

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
            rm $HOME/.kube/config
            rm -R $HOME/.kube/cache
            if [ -z "$TKG_VSPHERE_CLUSTER_NAME" ]
            then
                printf "\n\n\n***********Login into Supervisor cluster...*************\n"
                kubectl vsphere login --insecure-skip-tls-verify --server $TKG_SUPERVISOR_ENDPOINT --vsphere-username $TKG_VSPHERE_CLUSTER_USERNAME
                kubectl config use-context $TKG_SUPERVISOR_ENDPOINT
            else
                printf "\n\n\n***********Login into Workload cluster...*************\n"            
                kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server $TKG_SUPERVISOR_ENDPOINT --insecure-skip-tls-verify -u $TKG_VSPHERE_CLUSTER_USERNAME
                kubectl config use-context $TKG_VSPHERE_CLUSTER_NAME
            fi
            
        else
            rm $HOME/.kube/config
            rm -R $HOME/.kube/cache
            if [ -z "$TKG_VSPHERE_CLUSTER_NAME" ]
            then
                printf "\n\n\n***********Creating Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST, K8s:$TKG_VSPHERE_CLUSTER_NAME...*************\n"
                ssh-keyscan $BASTION_HOST > $HOME/.ssh/known_hosts
                ssh -i $HOME/.ssh/id_rsa -4 -fNT -L 443:$TKG_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
                ssh -i $HOME/.ssh/id_rsa -4 -fNT -L 6443:$TKG_SUPERVISOR_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST

                printf "\n\n\n***********Login into Supervisor cluster...*************\n"
                kubectl vsphere login --insecure-skip-tls-verify --server kubernetes --vsphere-username administrator@vsphere.local && isok='yes'
                if [[ $isok == 'yes' ]]
                then
                    sed -i 's/kubernetes/'$TKG_SUPERVISOR_ENDPOINT'/g' ~/.kube/config
                    kubectl config use-context $TKG_SUPERVISOR_ENDPOINT
                    sed -i '0,/'$TKG_SUPERVISOR_ENDPOINT'/s//kubernetes/' ~/.kube/config
                fi
            else
                printf "\n\n\n***********Creating Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST K8s:$TKG_SUPERVISOR_ENDPOINT...*************\n"
                ssh-keyscan $BASTION_HOST > $HOME/.ssh/known_hosts
                ssh -i $HOME/.ssh/id_rsa -4 -fNT -L 443:$TKG_SUPERVISOR_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST


                printf "\n\n\n***********Authenticating to cluster $TKG_VSPHERE_CLUSTER_NAME-->IP:$TKG_VSPHERE_CLUSTER_ENDPOINT  ...*************\n"
                # echo "debug: kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server kubernetes --insecure-skip-tls-verify -u $TKG_VSPHERE_CLUSTER_USERNAME"
                kubectl vsphere login --tanzu-kubernetes-cluster-name $TKG_VSPHERE_CLUSTER_NAME --server kubernetes --insecure-skip-tls-verify -u $TKG_VSPHERE_CLUSTER_USERNAME && isok='yes'
                # echo $RESULT
                # cat < ~/.kube/config

                if [[ $isok == 'yes' ]]
                then
                    printf "\n\n\n***********Adjusting your kubeconfig...*************\n"

                    sed -i 's/kubernetes/'$TKG_SUPERVISOR_ENDPOINT'/g' ~/.kube/config
                    kubectl config use-context $TKG_VSPHERE_CLUSTER_NAME

                    sed -i '0,/'$TKG_VSPHERE_CLUSTER_ENDPOINT'/s//kubernetes/' ~/.kube/config
                    ssh -i $HOME/.ssh/id_rsa -4 -fNT -L 6443:$TKG_VSPHERE_CLUSTER_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST        
                fi
            fi
            
        fi
    else
        printf "\n\n\nNo kubeconfig exists yet OR Current kubeconfig has not expired..\n"
        if [ -n "$BASTION_HOST" ]
        then
            printf "\n\n\n***********Creating Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...*************\n"

            if [ -z "$TKG_VSPHERE_CLUSTER_NAME" ]
            then
                ssh -i $HOME/.ssh/id_rsa -4 -fNT -L 6443:$TKG_SUPERVISOR_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST
            else
                ssh -i $HOME/.ssh/id_rsa -4 -fNT -L 6443:$TKG_VSPHERE_CLUSTER_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST
            fi
        fi
    fi

    if [[ $isok == 'yes' ]]
    then
        sleep 2
        printf "\n\n\n***********Verifying...*************\n"
        kubectl get ns


        if [[ $SILENTMODE != 'y' ]]
        then
            while true; do
                read -p "Confirm if the above cluster is correct? [y/n] " yn
                case $yn in
                    [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                    [Nn]* ) printf "\n\nYou said no...Adjust via merlin command\n"; break;;
                    * ) echo "Please answer yes or no.";
                esac
            done
        fi
    else
        printf "\n\nERROR: failed to connect to server/k8s.\n\n"
    fi

    printf "\n\n\nDONE.\n\n"
}


# if [[ $@ == "--help"  && "${BASH_SOURCE[0]}" != "${0}" ]]
# then
#     # "${BASH_SOURCE[0]}" != "${0}" script is being sourced
#     # This condition is true ONLY when --help is passed in the init script.
#     # In this scenario we just want to print the help message and NOT exit.
#     source ~/binaries/readparams.sh --printhelp
#     return # We do not want to exit. We just dont want to continue the rest.
# fi

# printf "\n\n\nDBG\n\n\n"
# result=$(source ~/binaries/readparams.sh $@)
# # source ~/binaries/readparams.sh $@

# if [[ $result == *@("Error"|"help")* ]]
# then
#     printf "Error: $result\n"
#     printf "\nProvide valid params\n"
#     source ~/binaries/readparams.sh --printhelp
#     exit
# else
#     export $(echo $result | xargs)
# fi


