#!/bin/bash

isreturn='n'

return_or_exit()
{
    isinit=$(echo $0 | grep init.sh)
    if [[ $isinit ]]
    then
        isreturn='y'
        return
    else
        exit
    fi
}


install_tanzu_plugin()
{
    printf "\n\n************Tanzu CLI**************\n\n"
    source $HOME/binaries/scripts/install-tanzu-cli.sh
    installTanzuCLI
    ret=$?
    if [[ $ret == 1 ]]
    then
        printf "\nERROR: Tanzu CLI was not successfully installed. Merling will not function without Tanzu CLI. Please check if you have place right tar file in the binaries directory.\n"
        return 1
    fi
    printf "DONE\n\n\n"
}

# unset createcontext
# unset onboardworkloadcluster
# unset installpackage
# unset clusterendpoint
# unset clustername

# if [[ $@ == "--help"  && "${BASH_SOURCE[0]}" != "${0}" ]]
# then
#     # "${BASH_SOURCE[0]}" != "${0}" script is being sourced
#     # This condition is true ONLY when --help is passed in the init script.
#     # In this scenario we just want to print the help message and NOT exit.
#     source ~/binaries/readparams-tkgtanzu.sh --printhelp
#     return_or_exit # We do not want to exit. We just dont want to continue the rest.
# fi

# if [[ $isreturn == 'y' ]]
# then
#     return
# fi

# result=$(source ~/binaries/readparams-tkgtanzu.sh $@)
# # source ~/binaries/readparams.sh $@

# if [[ $result == *@("Error"|"help")* ]]
# then
#     printf "Error: $result\n"
#     printf "\nProvide valid params\n"
#     source ~/binaries/readparams-tkgtanzu.sh --printhelp
#     return_or_exit
# else
#     export $(echo $result | xargs)
# fi

# if [[ $isreturn == 'y' ]]
# then
#     return
# fi


function dotkgtanzu() {

    local createcontext=$1
    local onboardworkloadcluster=$2
    local clusterendpoint=$3
    local clustername=$4
    local installpackage=$5

    test -f $HOME/.env && export $(cat $HOME/.env | xargs) || true
    export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)

    local isexist=$(tanzu version)
    if [[ -n $isexist ]]
    then
        ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep "login$")
        if [[ -z $ISINSTALLED ]]
        then
            printf "\n\ntanzu plugin login not found. installing...\n"
            install_tanzu_plugin
            printf "\n\n"
        fi
        ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep "package$")
        if [[ -z $ISINSTALLED ]]
        then
            printf "\n\ntanzu plugin login not found. installing...\n"
            install_tanzu_plugin
            printf "\n\n"
        fi
    else
        printf "\n\n\nTanzu CLI does not exist."
        sleep 1
        printf "\nPlease place the tanzu cli tar file in the binaries directory to use tkgtanzu wizard\n\nYou must perform \"./start.sh/bat forcebuild\" to rebuild with tanzu cli\n"
        sleep 1
        return_or_exit
    fi

    if [[ $isreturn == 'y' ]]
    then
        return
    fi



    if [[ $createcontext == 'y' || $onboardworkloadcluster == 'y' ]]
    then
        isexist=$(tanzu config server list -o json | jq '.[].context' | xargs)
        if [[ -z $isexist || $isexist != $TKG_SUPERVISOR_ENDPOINT ]]
        then
            printf "\nTanzu context not found matching with $TKG_SUPERVISOR_ENDPOINT. Creating new....\n"
            source ~/binaries/tanzuwizard/tanzu-create-context.sh
            doTanzuCreateContext
        fi
    fi

    if [[ $onboardworkloadcluster == 'y' && -n $clusterendpoint && -n $clustername ]]
    then
        printf "\n\nstarting onboard of workload cluster...\n\n"
        source ~/binaries/tanzuwizard/tanzu-onboard-workloadcluster.sh
        doOnboardWorkloadCluster $clusterendpoint $clustername
    fi

    if [[ -n $installpackage ]]
    then
        printf "\n\nstarting tanzu package installation...\n\n"
        source ~/binaries/tanzuwizard/tanzu-install-package.sh
        doTanzuInstallPackage $installpackage
    fi
}







