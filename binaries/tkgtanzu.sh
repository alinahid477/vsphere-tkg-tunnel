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
    tanzubundlename=''
    printf "\nChecking tanzu tar file...\n\n"
    cd /tmp
    sleep 1
    numberoftarfound=$(find ./*tar* -type f -printf "." | wc -c)
    if [[ $numberoftarfound == 1 ]]
    then
        tanzubundlename=$(find ./*tar* -printf "%f\n")
    fi
    if [[ $numberoftarfound -gt 1 ]]
    then
        printf "\nfound more than 1 tar files..\n"
        find ./*tar* -printf "%f\n"
        printf "Error: only 1 tar file is allowed in ~/binaries dir.\n"
        printf "\n\n"
        exit 1
    fi

    if [[ $numberoftarfound -lt 1 ]]
    then
        printf "\nNo tanzu tar file found. Please place the tanzu bindle in ~/binaries and rebuild again to enable tkgtanzu wizard...\n"
        exit 1
    fi
    printf "\nTanzu Tar file: $tanzubundlename. Installing..."
    # sleep 1
    # mkdir tanzu
    # tar -xvf $tanzubundlename -C tanzu/

    if [[ $tanzubundlename == "tce"* ]]
    then
        cd /tmp/tanzu/
        tcefolder=$(ls | grep tce)
        cd $tcefolder
        export ALLOW_INSTALL_AS_ROOT=true
        ./install.sh
    else
        cd /tmp/tanzu/cli/core
        versionfolder=$(ls | grep v)
        cd $versionfolder
        # install core/$versionfolder/tanzu-core-linux_amd64 /usr/local/bin/tanzu
        tanzu plugin install --local /tmp/tanzu/cli all
    fi
}



export $(cat /root/.env | xargs)
export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)

unset createcontext
unset onboardworkloadcluster
unset clusterendpoint
unset clustername

if [[ $@ == "--help"  && "${BASH_SOURCE[0]}" != "${0}" ]]
then
    # "${BASH_SOURCE[0]}" != "${0}" script is being sourced
    # This condition is true ONLY when --help is passed in the init script.
    # In this scenario we just want to print the help message and NOT exit.
    source ~/binaries/readparams-tkgtanzu.sh --printhelp
    return_or_exit # We do not want to exit. We just dont want to continue the rest.
fi

if [[ $isreturn == 'y' ]]
then
    return
fi

result=$(source ~/binaries/readparams-tkgtanzu.sh $@)
# source ~/binaries/readparams.sh $@

if [[ $result == *@("Error"|"help")* ]]
then
    printf "Error: $result\n"
    printf "\nProvide valid params\n"
    source ~/binaries/readparams-tkgtanzu.sh --printhelp
    return_or_exit
else
    export $(echo $result | xargs)
fi

if [[ $isreturn == 'y' ]]
then
    return
fi


isexist=$(tanzu version)
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


if [[ -n $createcontext || -n $onboardworkloadcluster ]]
then
    isexist=$(tanzu config server list -o json | jq '.[].context' | xargs)
    if [[ -z $isexist || $isexist != $TKG_SUPERVISOR_ENDPOINT ]]
    then
        printf "\nTanzu context not found matching with $TKG_SUPERVISOR_ENDPOINT. Creating new....\n"
        source ~/binaries/tanzuwizard/tanzu-create-context.sh
    fi
fi

if [[ -n $onboardworkloadcluster ]]
then
    printf "\n\nstarting onboard of workload cluster...\n\n"
    source ~/binaries/tanzuwizard/tanzu-onboard-workloadcluster.sh $clusterendpoint $clustername
fi

if [[ -n $installpackage ]]
then
    printf "\n\nstarting tanzu package installation...\n\n"
    source ~/binaries/tanzuwizard/tanzu-install-package.sh $installpackage
fi


