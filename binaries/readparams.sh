#!/bin/bash

helpFunction()
{
    printf "\nProvide valid params\n\n"
    echo "Usage: $0"
    echo -e "\t-s | --switch-to-supervisor no value needed. Signals this script to initiate login into TKG supervisor cluster"
    echo -e "\t-w | --switch-to-workload no value needed. Signals this script to initiate login into TKG workload cluster"
    echo -e "\t-c | --cluster-endpoint the endpoint of the workload cluster"
    echo -e "\t-n | --cluster-name name of the workload cluster"
    # exit 1 # Exit script after printing help
}


output=""

# read the options
TEMP=`getopt -o swc:n:hp --long switch-to-supervisor,switch-to-workload,cluster-endpoint:,cluster-name:,help,printhelp -n $0 -- "$@"`
eval set -- "$TEMP"
# echo $TEMP;
while true ; do
    # echo "here -- $1"
    case "$1" in
        -s | --switch-to-supervisor )
            case "$2" in
                "" ) switchtosupervisor='y'; output=$(printf "$output\nswitchtosupervisor=y") ; shift 2 ;;
                * ) switchtosupervisor='y' ; output=$(printf "$output\nswitchtosupervisor=y") ; shift 2 ;;
            esac ;;
        -s | --switch-to-workload )
            case "$2" in
                "" ) switchtoworkload='y'; output=$(printf "$output\nswitchtoworkload=y") ; shift 2 ;;
                * ) switchtoworkload='y' ; output=$(printf "$output\nswitchtoworkload=y") ; shift 2 ;;
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
        -p | --printhelp ) helpFunction; break;; 
        -- ) shift; break;; 
        * ) break;;
    esac
done


iserror=""

if [[ -n $switchtosupervisor && -n $switchtoworkload ]]
then
    iserror="y"
    printf "\nError: Please specify either switch-to-supervisor OR switch-to-workload.\n"
fi

if [[ -n $switchtosupervisor && -n $clusterendpoint && -n $clustername ]]
then
    iserror="y"
    printf "\nError: Please specify either switch-to-supervisor OR combo of cluster-endpoint and cluster-name.\nALL 3 parameters are invalid input.\n"
fi

if [[ -z "$switchtosupervisor" && -z "$clusterendpoint" && -n $clustername ]]
then
    iserror="y"
    printf "\nError: Please specify either switch-to-supervisor OR combo of cluster-endpoint and cluster-name.\n"
fi

if [[ -z "$switchtosupervisor" && -n $clusterendpoint && -z "$clustername" ]]
then
    iserror="y"
    printf "\nError: Please specify either switch-to-supervisor OR combo of cluster-endpoint and cluster-name.\n"
fi

if [[ -z $iserror ]]
then
    printf "$output"
fi