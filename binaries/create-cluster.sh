#!/bin/bash
export $(cat /root/.env | xargs)
export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)
quotify()
{
    qx=$1
    firstCharacter=${qx:0:1}
    lastCharacter=${qx: -1}
    if [[ ! $firstCharacter =~ [\"] ]]
    then
        qx=\"$qx 
    fi
    if [[ ! $lastCharacter =~ [\"] ]]
    then
        qx=$qx\" 
    fi
    block=$qx
}

process_cidr_blocks()
{
    CIDR_BLOCKS=""
    bx=$1
    if [[ $bx =~ [,] ]]
    then
        for block in $(echo $bx | tr ',' '\n')
        do
            quotify $block
            CIDR_BLOCKS=$CIDR_BLOCKS$block,
            printf "\n#$CIDR_BLOCKS"
        done
        CIDR_BLOCKS=${CIDR_BLOCKS::-1}
    else
        quotify $bx
        CIDR_BLOCKS=$block
    fi
}

if [[ $@ == "--help"  && "${BASH_SOURCE[0]}" != "${0}" ]]
then
    # "${BASH_SOURCE[0]}" != "${0}" script is being sourced
    # This condition is true ONLY when --help is passed in the init script.
    # In this scenario we just want to print the help message and NOT exit.
    source ~/binaries/readparams-createtkgscluster.sh --printhelp
    return # We do not want to exit. We just dont want to continue the rest.
fi

result=$(source ~/binaries/readparams-createtkgscluster.sh $@)
if [[ $result == *@("error"|"help")* ]]
then
    printf "\nProvide valid params\n\n"
    source ~/binaries/readparams-createtkgscluster.sh --printhelp
    exit
else
    export $(echo $result | xargs)
fi

if [[ -z $wizardmode || $SILENTMODE == 'y' ]]
then
    if [[ -z $defaultvalue_name || -z $defaultvalue_vsphere_namespace || -z $defaultvalue_kubernetes_version ||
        -z $defaultvalue_control_plane_count || -z $defaultvalue_control_plane_vm_class || -z $defaultvalue_control_plane_storage ||
        -z $defaultvalue_worker_node_count || -z $defaultvalue_worker_node_vm_class || -z $defaultvalue_worker_node_storage ]]
    then
        printf "\n\nOne or more required value missing. Validation failed.\nconsider running in wizard mode using -w flag\n"
        source ~/binaries/readparams-createtkgscluster.sh --printhelp
        printf "\n\nexit..\n\n"
        exit
    fi

    ## volume config is optional, so either all has value OR all are empty.
    ## volume config is either all has value === meaning user is giving volume config
    ## OR all volume config are empty === meaning user is not inputing volume config

    ## First check if any of them has value
    if [[ -n $defaultvalue_volume_mount_name || -n $defaultvalue_volume_mount_path || -n $defaultvalue_volume_mount_size ]]
    then
        ## Then check if any of them is empty
        if [[ -z $defaultvalue_volume_mount_name || -z $defaultvalue_volume_mount_path || -z $defaultvalue_volume_mount_size ]]
        then
            # at least one has value BUT at least one is empty as well (it has to be all or nothing)

            printf "\n\nOne or more required value for volume config missing. Validation failed.\nconsider running in wizard mode using -w flag\n"
            source ~/binaries/readparams-createtkgscluster.sh --printhelp
            printf "\n\nexit..\n\n"
            exit
        fi    
    fi
    
fi




printf "\n\n\n**********Starting TKGs Wizard...**************\n"
unset CLUSTER_NAME
if [[ -z $defaultvalue_name ]]
then
    printf "\n\nWhat would you like to call this cluster.."
    printf "\nHint:"
    echo -e "\tThe name can contain the these characters only '-','_',[A-Z][a-z][0-9]."
    while true; do
        read -p "k8s Cluster Name: " inp
        if [[ -z $inp ]]
        then
            printf "\nThis is a required field. You must provide a value.\n"
        else
            if [[ ! $inp =~ ^[A-Za-z0-9_\-]+$ ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                CLUSTER_NAME=$inp
                break
            fi
        fi
    done
else
    CLUSTER_NAME=$defaultvalue_name
fi

unset VSPHERE_NAMESPACE
if [[ -z $defaultvalue_vsphere_namespace ]]
then
    printf "\n\nIn which vsphere namespace would you like to create this k8s cluster?"
    printf "\nHint:"
    echo -e "\tMust be an existing vsphere namespace"
    while true; do
        read -p "vSphere Namespace Name: " inp
        if [[ -z $inp ]]
        then
            printf "\nThis is a required field. You must provide a value.\n"
        else
            printf "checking...\n"
            isexist=$(kubectl get ns | grep -w $inp)
            if [[ -z $isexist ]]
            then
                printf "\nvSphere namespace does not exist. You must provide a valid value.\n"
            else
                VSPHERE_NAMESPACE=$inp
                break
            fi
        fi
    done
else
    VSPHERE_NAMESPACE=$defaultvalue_vsphere_namespace
fi

unset KUBERNETES_VERSION
if [[ -z $defaultvalue_kubernetes_version ]]
then
    # for v1alpha2 (which is also the default in case it is missinh in the .env) we want the full tkr reference (eg: v1.21.2---vmware.1-tkg.1.ee25d55)
    latestversion=$(kubectl get tkr --sort-by=.metadata.name -o jsonpath='{.items[-1:].metadata.name}' | awk 'NR==1{print $1}')
    if [[ $DEFAULT_TKG_API == 'v1alpha1' ]]
    then
        # for v1alpha1 we want sort reference (eg: 1.21.2)
        latestversion=$(kubectl get tkr --sort-by=.metadata.name -o jsonpath='{.items[-1:].metadata.name}' | grep -Po '(?<=v)[^-]+' | awk 'NR==1{print $1}')
    fi
    printf "\n\n Getting tanzu kubernetes releases that are  compatible"
    kubectl get tkr
    printf "\n\nWhich kubernetes version would you like to use for this k8s cluster?"
    printf "\nHint:"
    echo -e "\tMust be an existing version from kubectl get tkr"
    echo -e "\tDEFAULT: $latestversion (hit enter to accept)"
    while true; do
        read -p "Kubernetes Version: " inp
        if [[ -z $inp && -n $latestversion ]]
        then
            KUBERNETES_VERSION=$latestversion
        else
            if [[ -n $inp ]]
            then
                isexist=$(kubectl get tkr | grep $inp)
                if [[ -z $isexist ]]
                then
                    printf "\nKubernetes version does not exist."
                else
                    KUBERNETES_VERSION=$inp
                fi
            fi
        fi
        if [[ -n $KUBERNETES_VERSION ]]
        then
            break
        else
            printf "\nYou must provide a valid value.\n"
        fi
    done
else
    KUBERNETES_VERSION=$defaultvalue_kubernetes_version
fi

unset CONTROL_PLANE_COUNT
if [[ -z $defaultvalue_control_plane_count ]]
then
    printf "\n\nHow many control plane would you like in this cluster.."
    printf "\nHint:"
    echo -e "\tYou must provide a number 1 or 3"
    echo -e "\tDEFAULT: 1 (hit enter to accept)"
    while true; do
        read -p "Control Plane Count: " inp
        if [[ -z $inp ]]
        then
            CONTROL_PLANE_COUNT=1
            break
        else
            if [[ ! $inp =~ ^[1,3]+$ ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                CONTROL_PLANE_COUNT=$inp
                break
            fi
        fi
    done
else
    CONTROL_PLANE_COUNT=$defaultvalue_control_plane_count
fi

unset CONTROL_PLANE_VM_CLASS
if [[ -z $defaultvalue_control_plane_vm_class ]]
then
    printf "\n\nWhat type of vm type would you like in this cluster.."
    printf "\nHint:"
    echo -e "\tYou must provide a valid value from here: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-7351EEFF-4EF0-468F-A19B-6CEA40983D3D.html"
    [[ -n $DEFAULT_CONTROL_PLANE_VM_CLASS ]] && echo -e "\tDEFAULT: $DEFAULT_CONTROL_PLANE_VM_CLASS (hit enter to accept)"
    while true; do
        read -p "Control Plane VM Type: " inp
        if [[ -z $inp && -n $DEFAULT_CONTROL_PLANE_VM_CLASS ]]
        then
            CONTROL_PLANE_VM_CLASS=$DEFAULT_CONTROL_PLANE_VM_CLASS
            break
        else
            CONTROL_PLANE_VM_CLASS=$inp
            break
        fi
    done
else
    CONTROL_PLANE_VM_CLASS=$defaultvalue_control_plane_vm_class
fi

DEFAULT_STORAGE_CLASS=$(kubectl get storageclass -o jsonpath='{.items[-1:].metadata.name}')
unset CONTROL_PLANE_STORAGE
if [[ -z $defaultvalue_control_plane_storage ]]
then
    printf "\n\nWhat is the name of storage policy would you like to attach to this control plane.."
    printf "\nHint:"
    echo -e "\tYou must provide a valid value"
    [[ -n $DEFAULT_STORAGE_CLASS ]] && echo -e "\tDEFAULT: $DEFAULT_STORAGE_CLASS (hit enter to accept)"
    while true; do
        read -p "Control Plane Storage Policy: " inp
        if [[ -z $inp && -n $DEFAULT_STORAGE_CLASS ]]
        then
            CONTROL_PLANE_STORAGE=$DEFAULT_STORAGE_CLASS
            break
        else
            CONTROL_PLANE_STORAGE=$inp
            break
        fi
    done
else
    CONTROL_PLANE_STORAGE=$defaultvalue_control_plane_storage
fi


unset WORKER_NODE_COUNT
if [[ -z $defaultvalue_worker_node_count ]]
then
    printf "\n\nHow many worker node would you like in this cluster.."
    printf "\nHint:"
    echo -e "\tYou must provide a number ranging between 1-100"
    echo -e "\tDEFAULT: 1 (hit enter to accept)"
    while true; do
        read -p "Worker Node Count: " inp
        if [[ -z $inp ]]
        then
            WORKER_NODE_COUNT=1
            break
        else
            if [[ ! $inp =~ ^[1-9]+$ ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                WORKER_NODE_COUNT=$inp
                break
            fi
        fi
    done
else
    WORKER_NODE_COUNT=$defaultvalue_worker_node_count
fi

unset WORKER_NODE_VM_CLASS
if [[ -z $defaultvalue_worker_node_vm_class ]]
then
    printf "\n\nWhat type of vm type would you like in this cluster.."
    printf "\nHint:"
    echo -e "\tYou must provide a valid value from here: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-7351EEFF-4EF0-468F-A19B-6CEA40983D3D.html"
    [[ -n $DEFAULT_WORKER_NODE_VM_CLASS ]] && echo -e "\tDEFAULT: $DEFAULT_WORKER_NODE_VM_CLASS (hit enter to accept)"
    while true; do
        read -p "Worker Node VM Type: " inp
        if [[ -z $inp && -n $DEFAULT_WORKER_NODE_VM_CLASS ]]
        then
            WORKER_NODE_VM_CLASS=$DEFAULT_WORKER_NODE_VM_CLASS
            break
        else
            WORKER_NODE_VM_CLASS=$inp
            break
        fi
    done
else
    WORKER_NODE_VM_CLASS=$defaultvalue_worker_node_vm_class
fi

unset WORKER_NODE_STORAGE
if [[ -z $defaultvalue_worker_node_storage ]]
then
    printf "\n\nWhat is the name of storage policy would you like to attach to the worker.."
    printf "\nHint:"
    echo -e "\tYou must provide a valid value"
    [[ -n $DEFAULT_STORAGE_CLASS ]] && echo -e "\tDEFAULT: $DEFAULT_STORAGE_CLASS (hit enter to accept)"
    while true; do
        read -p "Worker Storage Policy: " inp
        if [[ -z $inp && -n $DEFAULT_STORAGE_CLASS ]]
        then
            WORKER_NODE_STORAGE=$DEFAULT_STORAGE_CLASS
            break
        else
            WORKER_NODE_STORAGE=$inp
            break
        fi
    done
else
    WORKER_NODE_STORAGE=$defaultvalue_worker_node_storage
fi

unset SERVICES_CIDR_BLOCKS
if [[ -z $defaultvalue_services_cidr_blocks ]]
then
    printf "\n\nWhat are the services cidr blocks.."
    printf "\nHint:"
    echo -e "\tcomma separated string values in cids format"
    echo -e "\tYou must provide a valid value"
    [[ -n $DEFAULT_SERVICES_CIDR_BLOCKS ]] && echo -e "\tDEFAULT: $DEFAULT_SERVICES_CIDR_BLOCKS (hit enter to accept)"
    while true; do
        read -p "services cidr blocks: " inp
        if [[ -z $inp && -n $DEFAULT_SERVICES_CIDR_BLOCKS ]]
        then
            SERVICES_CIDR_BLOCKS=$DEFAULT_SERVICES_CIDR_BLOCKS
            break
        else
            SERVICES_CIDR_BLOCKS=$inp
            break
        fi
    done
else
    SERVICES_CIDR_BLOCKS=$defaultvalue_services_cidr_blocks
fi

process_cidr_blocks $SERVICES_CIDR_BLOCKS
SERVICES_CIDR_BLOCKS=$CIDR_BLOCKS

unset POD_CIDR_BLOCKS
if [[ -z $defaultvalue_pod_cidr_blocks ]]
then
    printf "\n\nWhat are the pod cidr blocks.."
    printf "\nHint:"
    echo -e "\tcomma separated string values in cids format"
    echo -e "\tYou must provide a valid value"
    [[ -n $DEFAULT_POD_CIDR_BLOCKS ]] && echo -e "\tDEFAULT: $DEFAULT_POD_CIDR_BLOCKS (hit enter to accept)"
    while true; do
        read -p "pod cidr blocks: " inp
        if [[ -z $inp && -n $DEFAULT_POD_CIDR_BLOCKS ]]
        then
            POD_CIDR_BLOCKS=$DEFAULT_POD_CIDR_BLOCKS
            break
        else
            POD_CIDR_BLOCKS=$inp
            break
        fi
    done
else
    POD_CIDR_BLOCKS=$defaultvalue_pod_cidr_blocks
fi

process_cidr_blocks $POD_CIDR_BLOCKS
POD_CIDR_BLOCKS=$CIDR_BLOCKS





unset VOLUME_MOUNT_NAME
unset VOLUME_MOUNT_PATH
unset VOLUME_MOUNT_SIZE
unset IS_PRESENT_VOLUME_MOUNT
unset VOLUME_CONFIG
if [[ -z $defaultvalue_volume_mount_name || -z $defaultvalue_volume_mount_path || -z $defaultvalue_volume_mount_size ]] 
then
    while true; do
        read -p "Confirm if you would like to configure volume mount? [y/n] " yn
        case $yn in
            [Yy]* ) IS_PRESENT_VOLUME_MOUNT='y'; printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) IS_PRESENT_VOLUME_MOUNT='n'; printf "\n\nYou said no.\n"; break;;
            * ) echo "Please answer yes or no.";
        esac
    done
else
    IS_PRESENT_VOLUME_MOUNT='y'
fi

if [[ $IS_PRESENT_VOLUME_MOUNT == 'y' ]]
then
    printf "\n\nNOTE: Volume mount configuration is for each worker node.\n\n"
    
    if [[ -z $defaultvalue_volume_mount_name ]]
    then
        printf "\n\nWhat is the name of the volume mount.."
        echo -e "\tDEFAULT: containerd (hit enter to accept)"
        printf "\n"
        while true; do
            read -p "volume mount name: " inp
            if [[ -z $inp ]]
            then
                VOLUME_MOUNT_NAME='containerd'
                break
            else
                VOLUME_MOUNT_NAME=$inp
                break
            fi
        done
    else
        VOLUME_MOUNT_NAME=$defaultvalue_volume_mount_name
    fi

    if [[ -z $defaultvalue_volume_mount_path ]]
    then
        printf "\n\nWhat is the volume mount path.."
        echo -e "\tDEFAULT: /var/lib/containerd (hit enter to accept)"
        printf "\n"
        while true; do
            read -p "volume mount path: " inp
            if [[ -z $inp ]]
            then
                VOLUME_MOUNT_PATH='/var/lib/containerd'
                break
            else
                VOLUME_MOUNT_PATH=$inp
                break
            fi
        done
    else
        VOLUME_MOUNT_PATH=$defaultvalue_volume_mount_path
    fi

    if [[ -z $defaultvalue_volume_mount_size ]]
    then
        
        while true; do
            read -p "volume mount size in gb (eg: 20): " inp
            if [[ -z $inp || ! $inp =~ ^[0-9]+$ || $inp != '0' ]]
            then
                printf "You must provide a valid value\n"
            else
                VOLUME_MOUNT_SIZE=$inp
                break
            fi
        done
    else
        VOLUME_MOUNT_SIZE=$defaultvalue_volume_mount_size
    fi

    VOLUME_CONFIG=$(sed 's/VOLUME_MOUNT_NAME/'$VOLUME_MOUNT_NAME'/g' /usr/local/tanzu-cluster.volumeconfig.template)
    VOLUME_CONFIG=$(printf "$VOLUME_CONFIG" | sed 's#VOLUME_MOUNT_PATH#'$VOLUME_MOUNT_PATH'#g')
    VOLUME_CONFIG=$(printf "$VOLUME_CONFIG" | sed 's#VOLUME_MOUNT_SIZE#'$VOLUME_MOUNT_SIZE'Gi#g')
fi

if [[ -z $DEFAULT_TKG_API ]]
then
    DEFAULT_TKG_API=v1alpha2
fi

printf "\nCreating definition file /tmp/$CLUSTER_NAME.yaml\n"
cp /usr/local/tanzu-cluster.$DEFAULT_TKG_API.template /tmp/$CLUSTER_NAME.tmp
sleep 1

sed -i 's/CLUSTER_NAME/'$CLUSTER_NAME'/g' /tmp/$CLUSTER_NAME.tmp
sed -i 's/VSPHERE_NAMESPACE/'$VSPHERE_NAMESPACE'/g' /tmp/$CLUSTER_NAME.tmp
sed -i 's/KUBERNETES_VERSION/'$KUBERNETES_VERSION'/g' /tmp/$CLUSTER_NAME.tmp
sed -i 's/CONTROL_PLANE_COUNT/'$CONTROL_PLANE_COUNT'/g' /tmp/$CLUSTER_NAME.tmp
sed -i 's/CONTROL_PLANE_VM_CLASS/'$CONTROL_PLANE_VM_CLASS'/g' /tmp/$CLUSTER_NAME.tmp
sed -i 's/CONTROL_PLANE_STORAGE_CLASS/'$CONTROL_PLANE_STORAGE'/g' /tmp/$CLUSTER_NAME.tmp
sed -i 's/WORKER_NODE_COUNT/'$WORKER_NODE_COUNT'/g' /tmp/$CLUSTER_NAME.tmp
sed -i 's/WORKER_NODE_VM_CLASS/'$WORKER_NODE_VM_CLASS'/g' /tmp/$CLUSTER_NAME.tmp
sed -i 's/WORKER_NODE_STORAGE_CLASS/'$WORKER_NODE_STORAGE'/g' /tmp/$CLUSTER_NAME.tmp
sed -i 's#POD_CIDR_BLOCKS#'$POD_CIDR_BLOCKS'#g' /tmp/$CLUSTER_NAME.tmp
sed -i 's#SERVICES_CIDR_BLOCKS#'$SERVICES_CIDR_BLOCKS'#g' /tmp/$CLUSTER_NAME.tmp

awk -v old="WORKER_VOLUME_BLOCK" -v new="$VOLUME_CONFIG" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/$CLUSTER_NAME.tmp > /tmp/$CLUSTER_NAME.yaml

if [[ -d "/root/tanzu-clusters" ]]
then
    printf "\nGenerating Tanzu Cluster File..."
    cp /tmp/$CLUSTER_NAME.yaml /root/tanzu-clusters/
    sleep 1
    chmod 777 /root/tanzu-clusters/$CLUSTER_NAME.yaml
    printf "\nDone.\n\n"
    if [[ $SILENTMODE == 'y' ]]
    then
        approved='y'
    else
        while true; do
            read -p "Review generated file ~/tanzu-clusters/$CLUSTER_NAME.yaml and confirm or modify and confirm to proceed further? [y/n] " yn
            case $yn in
                [Yy]* ) approved="y"; printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
    if [[ $approved == 'y' ]]
    then
        printf "\nApplying file ~/tanzu-clusters/$CLUSTER_NAME.yaml\n";
        kubectl apply -f /root/tanzu-clusters/$CLUSTER_NAME.yaml
    fi
else
    printf "\nApplying file ~/tmp/$CLUSTER_NAME.yaml\n";
    kubectl apply -f /tmp/$CLUSTER_NAME.yaml
fi

sleep 1
printf "\n\nCluster creation in progress.\nIt will take some time.\nGrab a cuppa in the meant time.\n\n"
sleep 1
printf "\n\nWizard's job is done\nExiting wizard...\n\n"
exit
