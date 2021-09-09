#!/bin/bash
export $(cat /root/.env | xargs) > /dev/null
export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)

result=$(source ~/binaries/readparams-createtkgscluster.sh $@)
if [[ $result == *@("error"|"help")* ]]
then
    source ~/binaries/readparams-createtkgscluster.sh --printhelp
    exit
else
    export $(echo $result | xargs)
fi

if [[ -z $wizardmode ]]
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
    printf "\n\nWhich kubernetes version would you like to use for this k8s cluster?"
    printf "\nHint:"
    echo -e "\tMust be an existing version from kubectl get tkr"
    while true; do
        read -p "Kubernetes Version: " inp
        if [[ -z $inp ]]
        then
            printf "\nThis is a required field. You must provide a value.\n"
        else
            isexist=$(kubectl get tkr | grep $inp)
            if [[ -z $isexist ]]
            then
                printf "\nKubernetes version does not exist. You must provide a valid value.\n"
            else
                KUBERNETES_VERSION=$inp
                break
            fi
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
    echo -e "\tYou must provide a number ranging between 1-5"
    echo -e "\tDEFAULT: 1"
    while true; do
        read -p "Control Plane Count: " inp
        if [[ -z $inp ]]
        then
            CONTROL_PLANE_COUNT=1
            break
        else
            if [[ ! $inp =~ ^[1-5]+$  && $inp < 5 ]]
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
    echo -e "\tDEFAULT: best-effort-small"
    while true; do
        read -p "Control Plane VM Type: " inp
        if [[ -z $inp ]]
        then
            CONTROL_PLANE_VM_CLASS=best-effort-small
        else
            CONTROL_PLANE_VM_CLASS=$inp
            break
        fi
    done
else
    CONTROL_PLANE_VM_CLASS=$defaultvalue_control_plane_vm_class
fi

unset CONTROL_PLANE_STORAGE
if [[ -z $defaultvalue_control_plane_storage ]]
then
    printf "\n\nWhat is the name of storage policy would you like to attach to this control plane.."
    printf "\nHint:"
    echo -e "\tYou must provide a valid value"
    echo -e "\tDEFAULT: k8s-policy"
    while true; do
        read -p "Control Plane Storage Policy: " inp
        if [[ -z $inp ]]
        then
            CONTROL_PLANE_STORAGE=k8s-policy
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
    echo -e "\tDEFAULT: 1"
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
    echo -e "\tDEFAULT: best-effort-small"
    while true; do
        read -p "Worker Node VM Type: " inp
        if [[ -z $inp ]]
        then
            WORKER_NODE_VM_CLASS=best-effort-small
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
    echo -e "\tDEFAULT: k8s-policy"
    while true; do
        read -p "Worker Storage Policy: " inp
        if [[ -z $inp ]]
        then
            WORKER_NODE_STORAGE=k8s-policy
        else
            WORKER_NODE_STORAGE=$inp
            break
        fi
    done
else
    WORKER_NODE_STORAGE=$defaultvalue_worker_node_storage
fi


sed -i 's/CLUSTER_NAME/'$CLUSTER_NAME'/g' /tmp/$CLUSTER_NAME.yaml
sed -i 's/VSPHERE_NAMESPACE/'$VSPHERE_NAMESPACE'/g' /tmp/$CLUSTER_NAME.yaml
sed -i 's/KUBERNETES_VERSION/'$KUBERNETES_VERSION'/g' /tmp/$CLUSTER_NAME.yaml
sed -i 's/CONTROL_PLANE_COUNT/'$CONTROL_PLANE_COUNT'/g' /tmp/$CLUSTER_NAME.yaml
sed -i 's/CONTROL_PLANE_VM_CLASS/'$CONTROL_PLANE_VM_CLASS'/g' /tmp/$CLUSTER_NAME.yaml
sed -i 's/CONTROL_PLANE_STORAGE_CLASS/'$CONTROL_PLANE_STORAGE_CLASS'/g' /tmp/$CLUSTER_NAME.yaml
sed -i 's/WORKER_NODE_COUNT/'$WORKER_NODE_COUNT'/g' /tmp/$CLUSTER_NAME.yaml
sed -i 's/WORKER_NODE_VM_CLASS/'$WORKER_NODE_VM_CLASS'/g' /tmp/$CLUSTER_NAME.yaml
sed -i 's/WORKER_NODE_STORAGE_CLASS/'$WORKER_NODE_STORAGE_CLASS'/g' /tmp/$CLUSTER_NAME.yaml

if [[ -d "/root/tanzu-clusters" ]]
then
    cp /tmp/$CLUSTER_NAME.yaml /root/tanzu-clusters/
fi