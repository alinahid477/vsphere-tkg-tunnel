#!/bin/bash

export $(cat /root/.env | xargs)

clusterendpoint=$1
clustername=$2


printf "\nChecking tanzu context...\n"
connectedtanzucontext=$(tanzu config server list -o json | jq '.[].context' | xargs)
if [[ -z $connectedtanzucontext || $connectedtanzucontext != $TKG_SUPERVISOR_ENDPOINT ]]
then
    printf "\nTanzu context not found matching with $TKG_SUPERVISOR_ENDPOINT"
    printf "\nRUN: ~/binaries/tkgtanzu.sh --create-context"
    printf "\n\n"
    exit 1    
fi

printf "\nfound tanzu context: $connectedtanzucontext\n"
sleep 2

if [[ $SILENTMODE != 'y' ]]
then
    while true; do
        read -p "confirm to continue with connected supervisor endpoint: $connectedtanzucontext to tanzu? [y/n] " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
            * ) echo "Please answer yes or no.";
        esac
    done
fi

printf "\nSwitching to workload cluster context\n"
if [[ $SILENTMODE != 'y' && -z $clusterendpoint && -z $clustername ]]
then

    printf "\nEnter the IP address of vsphere with tanzu workload cluster's endpoint"
    if [[ -z $TKG_VSPHERE_CLUSTER_ENDPOINT ]]
    then
        printf "\nHit enter to accept default: $TKG_VSPHERE_CLUSTER_ENDPOINT"
    fi
    printf "\n"
    while true; do
        read -p "workload cluster's endpoint: " inp
        if [[ -z $inp && -n $TKG_VSPHERE_CLUSTER_ENDPOINT ]]
        then
            inp=$TKG_VSPHERE_CLUSTER_ENDPOINT
        fi
        if [[ -z $inp || ! $inp =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
        then
            printf "\nYou must provide a valid value.\n"
        else
            break
        fi
    done
    clusterendpoint=$inp
    printf "\n\n"

    printf "\nEnter the name of vsphere with tanzu workload cluster"
    if [[ -z $TKG_VSPHERE_CLUSTER_NAME ]]
    then
        printf "\nHit enter to accept default: $TKG_VSPHERE_CLUSTER_NAME"
    fi
    printf "\n"
    while true; do
        read -p "workload cluster's name: " inp
        if [[ -z $inp && -n $TKG_VSPHERE_CLUSTER_NAME ]]
        then
            inp=$TKG_VSPHERE_CLUSTER_NAME
        fi
        if [[ -z $inp || ! $inp =~ ^[a-zA-z_-]+$ ]]
        then
            printf "\nYou must provide a valid value.\n"
        else
            break
        fi
    done
    clustername=$inp      
fi
if [[ -n $clusterendpoint && -n $clustername ]]
then
    printf "\nPROVIDED workload cluster endpoint:name=$clusterendpoint:$clustername\n"
    source ~/binaries/tkgwizard.sh --switch-to-workload --cluster-endpoint $clusterendpoint --cluster-name $clustername
else 
    printf "\nDEFAULT workload cluster endpoint:name=$TKG_VSPHERE_CLUSTER_ENDPOINT:$TKG_VSPHERE_CLUSTER_NAME\n"
    source ~/binaries/tkgwizard.sh --switch-to-workload
fi
printf "\nworkload cluster context==SWITCHED.\n"
sleep 1

printf "\nRunnig package listing to look for repository tanzupackages...\n\n\n"
sleep 1
tanzu package repository list -A
tanzupackagerepository=$(tanzu package repository list -A | grep tanzupackages)
if [[ -n $tanzupackagerepository ]]
then
    printf "\n\nTanzu package repository already exists."
    printf "\n\nThis cluster is already onboarded.\n"
    exit 1
else
    printf "\n\nTanzu package repository not found on this cluster."
    printf "\nProceeding to install package repository..."
    printf "\n\n"
fi


printf "\nChecking storage class...."
printf "\nExtracting storage class.."
kubectl get storageclass
printf "\n"
isexist=$(kubectl get storageclass --no-headers --output custom-columns=":metadata.name" | head -n 1)
if [[ -z $isexist ]]
then
    printf "\nNo storage class found."
    printf "\nYou must assign a storage class to this cluster in order to install tanzu packages."
    printf "\nAssign storage class from vsphere UI."
    printf "\nOR"
    printf "\nperforming: kubectl patch storageclass wcpglobalstorageprofile -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'."
    exit 1
fi


if [[ $SILENTMODE != 'y' ]]
then
    while true; do
        read -p "confirm to continue? [y/n] " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
            * ) echo "Please answer yes or no.";
        esac
    done
fi

kappcontrollerpodstatus=''
printf "\nChecking kapp controller..."
isexist=$(kubectl get pods -n tkg-system | grep kapp-controller)
if [[ -z $isexist ]]
then
    printf "\nkapp controller not found. Installing...\n"
    sleep 1
    printf "\nThis require associating with psp...\n"
    sleep 1
    printf "\nChecking existing POD security policy:\n"
    unset kappcontrollerpsp
    isvmwarepsp=$(kubectl get psp | grep -w vmware-system-privileged)
    if [[ -n $isvmwarepsp ]]
    then
        printf "found existing psp: vmware-system-privileged\n"
        kappcontrollerpsp=vmware-system-privileged        
    else
        istmcpsp=$(kubectl get psp | grep -w vmware-system-tmc-privileged)
        if [[ -n $istmcpsp ]]
        then
            printf "found existing psp: vmware-system-tmc-privileged\n"
            kappcontrollerpsp=vmware-system-tmc-privileged
        fi
    fi
    sleep 2
    if [[ -z $SILENTMODE || $SILENTMODE == 'n' ]]
    then
        unset pspprompter
        printf "\nList of available Pod Security Policies:\n"
        kubectl get psp
        if [[ -n $kappcontrollerpsp ]]
        then
            printf "\nSelected existing pod security policy: $kappcontrollerpsp"
            printf "\nPress/Hit enter to accept $kappcontrollerpsp"
            pspprompter=" (selected $kappcontrollerpsp)"  
        else 
            printf "\nHit enter to create a new one"
        fi
        printf "\nOR\nType a name from the available list\n"
        while true; do
            read -p "pod security policy$pspprompter: " inp
            if [[ -z $inp ]]
            then
                if [[ -z $kappcontrollerpsp ]]
                then 
                    printf "\nERROR: A vsphere with tanzu cluster should contain a psp.\n"
                    exit 1
                else
                    printf "\nAccepted psp: $kappcontrollerpsp"
                    break
                fi
            else
                isvalidvalue=$(kubectl get psp | grep -w $inp)
                if [[ -z $isvalidvalue ]]
                then
                    printf "\nYou must provide a valid input.\n"
                else 
                    kappcontrollerpsp=$inp
                    printf "\nAccepted psp: $kappcontrollerpsp"
                    break
                fi
            fi
        done
    fi
    printf "\n"
    printf "\nApplying kapp-controller in the workload cluster....\n"
    kubectl apply -f ~/binaries/tanzuwizard/kapp-controller-namespace.yaml
    kubectl apply -f ~/binaries/tanzuwizard/kapp-controller-sa.yaml
    if [[ -n $kappcontrollerpsp ]]
    then
        printf "\n\nusing psp $kappcontrollerpsp to create ClusterRole and ClusterRoleBinding for kapp-controller-sa\n"
        awk -v old="POD_SECURITY_POLICY_NAME" -v new="$kappcontrollerpsp" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/binaries/tanzuwizard/kapp-controller-psp.template > /tmp/kapp-controller-psp.yaml
        kubectl apply -f /tmp/kapp-controller-psp.yaml
        printf "Done.\n"
    fi    
    kubectl apply -f ~/binaries/tanzuwizard/kapp-controller.yaml
    printf "\nwaiting 10s before checking the status of kapp-controller...\n"
    sleep 10
    kappcontrollerpodstatus=$(kubectl get pods -n tkg-system | grep kapp-controller | awk '{print $3}')
    count=1
    kappcontrollerpodstatus=$(echo ${kappcontrollerpodstatus,,} | xargs)
    while [[ $kappcontrollerpodstatus != 'running' && $count -lt 10 ]]; do
        printf "\nkapp-controller pod status (in tkg-system namespace) is: $kappcontrollerpodstatus"
        printf "\nRetrying (#$count of #10) in 30s to check status...\n"
        sleep 30
        kappcontrollerpodstatus=$(kubectl get pods -n tkg-system | grep kapp-controller | awk '{print $3}')
        kappcontrollerpodstatus=$(echo ${kappcontrollerpodstatus,,} | xargs) ## turn into lower-case
        ((count=count+1))
    done
    printf "\nkapp-controller pod status (in tkg-system namespace) is: $kappcontrollerpodstatus\n"    
else
    kappcontrollerpodstatus='running'
    printf "\nKapp controller already installed on this cluster...."
fi

if [[ $kappcontrollerpodstatus != 'running' ]]
then
    printf "\nERROR: kapp-controller status is not Running"
    printf "\nERROR: This wizard is unable to install tanzupackages on this cluster.."
    exit 1
fi

printf "\nApply tanzu repository named 'tanzupackages' to this workload cluster..."
tanzu package repository add tanzupackages --url projects.registry.vmware.com/tkg/packages/standard/repo:v1.4.0
sleep 5

printf "\nTanzu repository named 'tanzupackages' ADDED. Checking availabled packages...\n"
isexist=$(tanzu package available list -A | grep -w cert-manager)
count=1
while [[ -z $isexist && $count -lt 10 ]]; do
    printf "\nnot available yet. waiting 30 before retrying (retry count #$count of #10)..."
    sleep 30
    isexist=$(tanzu package available list -A | grep -w cert-manager)
    ((count=count+1))
done

tanzu package available list -A

printf "\n\n\nCluster onboard COMPLETE.\n\n\n"