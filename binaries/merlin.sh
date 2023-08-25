#!/bin/bash
test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true


unset ishelp

# -- TKG Wizard -- #
unset switchtosupervisor
unset switchtoworkload
unset clusterendpoint
unset clustername
# -- END TKG Wizard -- #

# -- TKG Tanzu Wizard -- #
unset createcontext
unset onboardworkloadcluster
unset installpackage
# -- END TKG Tanzu Wizard -- #

# -- Create Cluster -- #
unset createclusterwizard
unset createclusterparam
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
# -- END Create Cluster -- #


source $HOME/binaries/tkgwizard.sh
source $HOME/binaries/tkgtanzu.sh
source $HOME/binaries/tkgcreatecluster.sh

function helpFunction()
{
    printf "\n\n"
    echo "Usage: merlin"
    echo -e "\t-s | --switch-to-supervisor no value needed. Signals this script to initiate login into TKG supervisor cluster"
    echo -e "\t-t | --switch-to-workload no value needed. Signals this script to initiate login into TKG workload cluster"
    echo -e "\t-e | --cluster-endpoint the endpoint of the workload cluster"
    echo -e "\t-n | --cluster-name name of the workload cluster"

    echo -e "\t-l | --create-context no value needed. Signals this script to initiate tanzu context for supervisor cluster"
    echo -e "\t-b | --onboard-workload-cluster no value needed. Signals this script to initiate onboarding a workload cluster. (optionally pass --cluster-endpoint and --cluster-name param)"
    echo -e "\t-i | --install-package name of the package (eg: cert-manager, prometheus etc)"


    echo -e "\t-w | --wizard no value needed. Signals this script to initiate wizard mode"
    echo -e "\t-y | --vsphere-namespace vsphere-namespace where this cluster will be created"
    echo -e "\t-v | --kubernetes-version k8s version"
    echo -e "\t-j | --control-plane-count number of control plane nodes"
    echo -e "\t-k | --control-plane-vm-class type of control plane nodes (default classes: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-7351EEFF-4EF0-468F-A19B-6CEA40983D3D.html)"
    echo -e "\t-m | --control-plane-storage name of the storage policy that will be attached to control plane nodes"
    echo -e "\t-o | --worker-node-count number of worker nodes"
    echo -e "\t-p | --worker-node-vm-class type of worker nodes (default classes: https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-7351EEFF-4EF0-468F-A19B-6CEA40983D3D.html)"
    echo -e "\t-q | --worker-node-storage name of the storage policy that will be attached to worker nodes"
    echo -e "\t-r | --services-cidr-blocks string value of service cidr block eg: \"10.96.0.0/12\",\"10.97.0.0/12\" etc"
    echo -e "\t-u | --pod-cidr-blocks string value of pod cidr block eg: \"192.168.0.0/16\" etc"
    echo -e "\t-x | --volume-mount-size size of the volume mounting to each worker node"
    echo -e "\t-z | --volume-mount-path path where the volume is mounting"
    echo -e "\t-a | --volume-mount-name name of the volume mount"

    echo -e "\t-h | --help"
    # exit 1 # Exit script after printing help
}




function executeCommand () {
    if [[ $switchtosupervisor == 'y' ]]
    then
        unset switchtosupervisor
        dotkgwizard 'y'
        return 1
    fi
    
    if [[ $switchtoworkload == 'y' ]]
    then
        unset switchtoworkload
        dotkgwizard 'n' 'y' $clusterendpoint $clustername
        unset clusterendpoint
        unset clustername
        return 1
    fi

    if [[ $createcontext == 'y' ]]
    then
        unset createcontext
        tkgtanzu 'y'
        return 1
    fi

    if [[ $onboardworkloadcluster == 'y' ]]
    then
        unset onboardworkloadcluster
        tkgtanzu 'n' 'y' $clusterendpoint $clustername
        return 1
    fi

    if [[ -n $installpackage ]]
    then       
        tkgtanzu 'n' 'n' 'n' 'n' $installpackage
        unset installpackage
        return 1
    fi






    if [[ $createclusterwizard == 'y' ]]
    then
        unset createclusterwizard
        doCreateCluster 'y' $defaultvalue_name $defaultvalue_vsphere_namespace  $defaultvalue_kubernetes_version $defaultvalue_control_plane_count $defaultvalue_control_plane_vm_class $defaultvalue_control_plane_storage $defaultvalue_worker_node_count $defaultvalue_worker_node_vm_class $defaultvalue_worker_node_storage $defaultvalue_volume_mount_name $defaultvalue_volume_mount_path $defaultvalue_volume_mount_size
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
        return 1
    fi

    if [[ $createclusterparam == 'y' ]]
    then
        unset createclusterparam
        doCreateCluster 'y' $defaultvalue_name $defaultvalue_vsphere_namespace  $defaultvalue_kubernetes_version $defaultvalue_control_plane_count $defaultvalue_control_plane_vm_class $defaultvalue_control_plane_storage $defaultvalue_worker_node_count $defaultvalue_worker_node_vm_class $defaultvalue_worker_node_storage $defaultvalue_volume_mount_name $defaultvalue_volume_mount_path $defaultvalue_volume_mount_size
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
        return 1
    fi

    printf "\nThis shouldn't have happened. Embarrasing.\n"
}





TEMP='getopt -o ste:n:lbi:wy:v:j:k:m:o:p:q:r:u:x:z:a:h'
TEMP+=' --long'

TEMP+=' switch-to-supervisor,switch-to-workload,cluster-endpoint:,cluster-name:,'

TEMP+='create-context,onboard-workload-cluster,install-package:,'

TEMP+='wizard,name:,vsphere-namespace:,control-plane-count:,control-plane-vm-class:,control-plane-storage:,'
TEMP+='worker-node-count:,worker-node-vm-class:,worker-node-storage:,'
TEMP+='services-cidr-blocks:,pod-cidr-blocks:,'
TEMP+='volume-mount-size:,volume-mount-path:,volume-mount-name:,'
TEMP+='kubernetes-version:,'

TEMP+='help'

TEMP=`$TEMP -n $0 -- "$@"`
eval set -- "$TEMP"
# echo $TEMP;
while true ; do
    # echo "here -- $1"
    case "$1" in
        -s | --switch-to-supervisor )
            case "$2" in
                "" ) switchtosupervisor='y'; shift 2 ;;
                * ) switchtosupervisor='y' ; shift 1 ;;
            esac ;;
        -t | --switch-to-workload )
            case "$2" in
                "" ) switchtoworkload='y'; shift 2 ;;
                * ) switchtoworkload='y' ; shift 1 ;;
            esac ;;
        -e | --cluster-endpoint )
            case "$2" in
                "" ) clusterendpoint='' ; shift 2 ;;
                * ) clusterendpoint=$2 ;  shift 2 ;;
            esac ;;
        -n | --cluster-name )
            case "$2" in
                "" ) clustername=''; shift 2 ;;
                * ) clustername=$2; shift 2 ;;
            esac ;;        
        -b | --onboard-workload-cluster )
            case "$2" in
                "" ) onboardworkloadcluster='y'; shift 2 ;;
                * ) onboardworkloadcluster='y' ; shift 1 ;;
            esac ;;
        -l | --create-context )
            case "$2" in
                "" ) createcontext='y'; shift 2 ;;
                * ) createcontext='y' ; shift 1 ;;
            esac ;;
        -i | --install-package )
            case "$2" in
                "" ) installpackage='Error' ; shift 2 ;;
                * ) installpackage=$2 ; shift 2 ;;
            esac ;;
        -w | --wizard )
            case "$2" in
                "" ) createclusterwizard='y' ; shift 2 ;;
                * )  createclusterwizard='y' ; shift 1 ;;
            esac ;; 
        -n | --cluster-name )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_name="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_name=$2 ; shift 2 ;;
            esac ;;
        -y | --vsphere-namespace )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_vsphere_namespace="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_vsphere_namespace=$2 ; shift 2 ;;
            esac ;;
        -v | --kubernetes-version )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_kubernetes_version= ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_kubernetes_version=$2; shift 2 ;;
            esac ;;
        -j | --control-plane-count )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_control_plane_count="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_control_plane_count=$2; shift 2 ;;
            esac ;;
        -k | --control-plane-vm-class )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_control_plane_vm_class="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_control_plane_vm_class=$2; shift 2 ;;
            esac ;;
        -m | --control-plane-storage )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_control_plane_storage="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_control_plane_storage=$2; shift 2 ;;
            esac ;;
        -o | --worker-node-count )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_worker_node_count="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_worker_node_count=$2; shift 2 ;;
            esac ;;
        -p | --worker-node-vm-class )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_worker_node_vm_class="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_worker_node_vm_class=$2 ; shift 2 ;;
            esac ;;
        -q | --worker-node-storage )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_worker_node_storage="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_worker_node_storage=$2 ; shift 2 ;;
            esac ;;
        -r | --services-cidr-blocks )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_services_cidr_blocks="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_services_cidr_blocks=$2 ; shift 2 ;;
            esac ;;
        -u | --pod-cidr-blocks )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_pod_cidr_blocks="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_pod_cidr_blocks=$2 ; shift 2 ;;
            esac ;;
        -z | --volume-mount-size )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_volume_mount_size="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_volume_mount_size=$2 ; shift 2 ;;
            esac ;;
        -x | --volume-mount-path )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_volume_mount_path="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_volume_mount_path=$2 ; shift 2 ;;
            esac ;;
        -a | --volume-mount-name )
            case "$2" in
                "" ) createclusterparam='y'; defaultvalue_volume_mount_name="" ; shift 2 ;;
                * ) createclusterparam='y'; defaultvalue_volume_mount_name=$2 ; shift 2 ;;
            esac ;;
        -h | --help ) ishelp='y'; helpFunction; break;; 
        -- ) shift; break;; 
        * ) break;;
    esac
done

if [[ $ishelp != 'y' ]]
then
    executeCommand
fi
unset ishelp