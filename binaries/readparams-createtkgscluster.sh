#!/bin/bash

unset defaultvalue_name 
unset defaultvalue_vsphere_namespace 
unset defaultvalue_kubernetes_version
unset defaultvalue_control_plane_count 
unset defaultvalue_control_plane_vm_class 
unset defaultvalue_control_plane_storage 
unset defaultvalue_worker_node_count 
unset defaultvalue_worker_node_vm_class 
unset defaultvalue_worker_node_storage
unset defaultvalue_volume_mount_name
unset defaultvalue_volume_mount_path
unset defaultvalue_volume_mount_size

helpFunction()
{
    printf "\n\n"
    echo "Usage: ~/baniries/create-cluster.sh"
    echo -e "\t-w | --wizard no value needed. Signals this script to initiate wizard mode"
    echo -e "\t-n | --name name of the cluster"
    echo -e "\t-s | --vsphere-namespace vsphere-namespace where this cluster will be created"
    echo -e "\t-k | --kubernetes-version k8s version"
    echo -e "\t-c | --control-plane-count number of control plane nodes"
    echo -e "\t-m | --control-plane-vm-class type of control plane nodes (default classes: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-7351EEFF-4EF0-468F-A19B-6CEA40983D3D.html)"
    echo -e "\t-d | --control-plane-storage name of the storage policy that will be attached to control plane nodes"
    echo -e "\t-w | --worker-node-count number of worker nodes"
    echo -e "\t-o | --worker-node-vm-class type of worker nodes (default classes: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-7351EEFF-4EF0-468F-A19B-6CEA40983D3D.html)"
    echo -e "\t-e | --worker-node-storage name of the storage policy that will be attached to worker nodes"
    echo -e "\t-f | --services-cidr-blocks string value of service cidr block eg: \"10.96.0.0/12\",\"10.97.0.0/12\" etc"
    echo -e "\t-g | --pod-cidr-blocks string value of pod cidr block eg: \"192.168.0.0/16\" etc"
    echo -e "\t-v | --volume-mount-size size of the volume mounting to each worker node"
    echo -e "\t-x | --volume-mount-path path where the volume is mounting"
    echo -e "\t-u | --volume-mount-name name of the volume mount"
    echo -e "\t-h | --help"
    
    printf "\nNot all values are exposed here.\nFor more settings/config value please create a config yaml file and use kubectl apply.\nCheckout the details on Configuration Parameters for Tanzu Kubernetes Clusters documentation.\nLink: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-4E68C7F2-C948-489A-A909-C7A1F3DC545F.html\n\n"
    # exit 1 # Exit script after printing help
}


output=""

# read the options
TEMP='getopt -o wn:s:c:m:d:w:o:e:f:g:k:v:x:u:hp --long wizard,name:,vsphere-namespace:,'
TEMP+='control-plane-count:,control-plane-vm-class:,control-plane-storage:,'
TEMP+='worker-node-count:,worker-node-vm-class:,worker-node-storage:,'
TEMP+='services-cidr-blocks:,pod-cidr-blocks:,'
TEMP+='volume-mount-size:,volume-mount-path:,volume-mount-name:,'
TEMP+='kubernetes-version:,'
TEMP+='help,printhelp -n'
TEMP=`$TEMP $0 -- "$@"`
eval set -- "$TEMP"
# echo $TEMP;
while true ; do
    # echo "here -- $1"
    case "$1" in
        -w | --wizard )
            case "$2" in
                "" ) output=$(printf "$output\nwizardmode=y") ; shift 2 ;;
                * ) output=$(printf "$output\nwizardmode=y") ; shift 2 ;;
            esac ;; 
        -n | --name )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_name=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_name=$2") ; shift 2 ;;
            esac ;;
        -s | --vsphere-namespace )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_vsphere_namespace=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_vsphere_namespace=$2") ; shift 2 ;;
            esac ;;
        -k | --kubernetes-version )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_kubernetes_version=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_kubernetes_version=$2"); shift 2 ;;
            esac ;;
        -c | --control-plane-count )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_control_plane_count=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_control_plane_count=$2"); shift 2 ;;
            esac ;;
        -m | --control-plane-vm-class )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_control_plane_vm_class=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_control_plane_vm_class=$2"); shift 2 ;;
            esac ;;
        -d | --control-plane-storage )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_control_plane_storage=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_control_plane_storage=$2"); shift 2 ;;
            esac ;;
        -w | --worker-node-count )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_worker_node_count=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_worker_node_count=$2"); shift 2 ;;
            esac ;;
        -o | --worker-node-vm-class )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_worker_node_vm_class=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_worker_node_vm_class=$2"); shift 2 ;;
            esac ;;
        -e | --worker-node-storage )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_worker_node_storage=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_worker_node_storage=$2"); shift 2 ;;
            esac ;;
        -f | --services-cidr-blocks )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_services_cidr_blocks=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_services_cidr_blocks=$2"); shift 2 ;;
            esac ;;
        -g | --pod-cidr-blocks )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_pod_cidr_blocks=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_pod_cidr_blocks=$2"); shift 2 ;;
            esac ;;
        -v | --volume-mount-size )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_volume_mount_size=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_volume_mount_size=$2"); shift 2 ;;
            esac ;;
        -x | --volume-mount-path )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_volume_mount_path=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_volume_mount_path=$2"); shift 2 ;;
            esac ;;
        -u | --volume-mount-name )
            case "$2" in
                "" ) output=$(printf "$output\ndefaultvalue_volume_mount_name=") ; shift 2 ;;
                * ) output=$(printf "$output\ndefaultvalue_volume_mount_name=$2"); shift 2 ;;
            esac ;;
        -h | --help ) printf "help"; break;; 
        -p | --printhelp ) helpFunction; break;; 
        -- ) shift; break;; 
        * ) break;;
    esac
done

printf "$output"