#!/bin/bash

helpFunction1()
{
    printf "\n\n"
    echo "Usage: ~/baniries/tanzu.sh"
    echo -e "\t-b | --onboard-workload-cluster no value needed. Signals this script to initiate onboarding a workload cluster. (optionally pass --cluster-endpoint and --cluster-name param)"
    echo -e "\t-l | --login no value needed. Signals this script to initiate tanzu login for supervisor cluster"
    echo -e "\t-c | --cluster-endpoint the endpoint of the workload cluster to onboard"
    echo -e "\t-n | --cluster-name name of the workload cluster"
    echo -e "\t-h | --help"
    # exit 1 # Exit script after printing help
}


output=""

# read the options
TEMP=`getopt -o blc:n:hp --long onboard-workload-cluster,login,cluster-endpoint:,cluster-name:,help,printhelp -n $0 -- "$@"`
eval set -- "$TEMP"
# echo $TEMP;
while true ; do
    # echo "here -- $1"
    case "$1" in
        -b | --onboard-workload-cluster )
            case "$2" in
                "" ) onboardworkloadcluster='y'; output=$(printf "$output\nonboardworkloadcluster=y") ; shift 2 ;;
                * ) onboardworkloadcluster='y' ; output=$(printf "$output\nonboardworkloadcluster=y") ; shift 2 ;;
            esac ;;
        -l | --login )
            case "$2" in
                "" ) login='y'; output=$(printf "$output\nlogin=y") ; shift 2 ;;
                * ) login='y' ; output=$(printf "$output\nlogin=y") ; shift 2 ;;
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
        -h | --help ) printf "help"; break;; 
        -p | --printhelp ) helpFunction1; break;; 
        -- ) shift; break;; 
        * ) break;;
    esac
done


iserror=""

if [[ -n $login && -n $onboardworkloadcluster ]]
then
    iserror="y"
    printf "\nError: Please specify either onboard-workload-cluster OR login.\n"
fi

if [[ -n $login && -n $clusterendpoint && -n $clustername ]]
then
    iserror="y"
    printf "\nError: Please specify either login OR combo of cluster-endpoint and cluster-name with onboard-workload-cluster.\nThese 3 parameters are invalid input.\n"
fi

if [[ -z $login && -n $onboardworkloadcluster && -z $clusterendpoint && -n $clustername ]]
then
    iserror="y"
    printf "\nError: Please specify both cluster-endpoint and cluster-name.\n"
fi

if [[ -z $login && -n $onboardworkloadcluster && -z $clustername && -n $clusterendpoint ]]
then
    iserror="y"
    printf "\nError: Please specify both cluster-endpoint and cluster-name.\n"
fi

if [[ -z $iserror ]]
then
    printf "$output"
fi