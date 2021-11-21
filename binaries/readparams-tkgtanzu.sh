#!/bin/bash

helpFunction1()
{
    printf "\n\n"
    echo "Usage: ~/baniries/tkgtanzu.sh"
    echo -e "\t-l | --create-context no value needed. Signals this script to initiate tanzu context for supervisor cluster"
    echo -e "\t-b | --onboard-workload-cluster no value needed. Signals this script to initiate onboarding a workload cluster. (optionally pass --cluster-endpoint and --cluster-name param)"
    echo -e "\t-c | --cluster-endpoint the endpoint of the workload cluster to onboard"
    echo -e "\t-n | --cluster-name name of the workload cluster"
    echo -e "\t-i | --install-package name of the package (eg: cert-manager, prometheus etc)"
    echo -e "\t-h | --help"
    # exit 1 # Exit script after printing help
}


output=""

# read the options
TEMP=`getopt -o blc:n:i:hp --long onboard-workload-cluster,create-context,cluster-endpoint:,cluster-name:,install-package:,help,printhelp -n $0 -- "$@"`
eval set -- "$TEMP"
# echo $TEMP;
while true ; do
    # echo "here -- $1"
    case "$1" in
        -b | --onboard-workload-cluster )
            case "$2" in
                "" ) onboardworkloadcluster='y'; output=$(printf "$output\nonboardworkloadcluster=y") ; shift 2 ;;
                * ) onboardworkloadcluster='y' ; output=$(printf "$output\nonboardworkloadcluster=y") ; shift 1 ;;
            esac ;;
        -l | --create-context )
            case "$2" in
                "" ) createcontext='y'; output=$(printf "$output\ncreatecontext=y") ; shift 2 ;;
                * ) createcontext='y' ; output=$(printf "$output\ncreatecontext=y") ; shift 2 ;;
            esac ;;
        -c | --cluster-endpoint )
            case "$2" in
                "" ) clusterendpoint='' ; shift 2 ;;
                * ) clusterendpoint=$2 ; output=$(printf "$output\nclusterendpoint=$clusterendpoint"); shift 2 ;;
            esac ;;
        -n | --cluster-name )
            case "$2" in
                "" ) clustername=''; shift 2 ;;
                * ) clustername=$2; output=$(printf "$output\nclustername=$clustername"); shift 2 ;;
            esac ;;
        -i | --install-package )
            case "$2" in
                "" ) installpackage='Error' ; shift 2 ;;
                * ) installpackage=$2 ; output=$(printf "$output\ninstallpackage=$installpackage"); shift 2 ;;
            esac ;;
        -h | --help ) printf "help"; break;; 
        -p | --printhelp ) helpFunction1; break;; 
        -- ) shift; break;; 
        * ) break;;
    esac
done


iserror=""

if [[ -n $createcontext && -n $onboardworkloadcluster ]]
then
    iserror="y"
    printf "\nError: Please specify either onboard-workload-cluster OR create-context.\n"
fi

if [[ -n $createcontext && -n $clusterendpoint && -n $clustername ]]
then
    iserror="y"
    printf "\nError: Please specify either create-context OR combo of cluster-endpoint and cluster-name with onboard-workload-cluster.\nThese 3 parameters are invalid input.\n"
fi

if [[ -z $createcontext && -n $onboardworkloadcluster && -z $clusterendpoint && -n $clustername ]]
then
    iserror="y"
    printf "\nError: Please specify both cluster-endpoint and cluster-name.\n"
fi

if [[ -z $createcontext && -n $onboardworkloadcluster && -z $clustername && -n $clusterendpoint ]]
then
    iserror="y"
    printf "\nError: Please specify both cluster-endpoint and cluster-name.\n"
fi

if [[ -n $installpackage && $installpackage == 'Error' ]]
then
    iserror="y"
    printf "\nError: Please specify a package name.\n"
fi

if [[ -z $iserror ]]
then
    printf "$output"
fi