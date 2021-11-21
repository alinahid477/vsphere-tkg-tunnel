#!/bin/bash
install_tanzu_plugin()
{
    tanzubundlename=''
    printf "\nChecking tanzu bundle...\n\n"
    cd /tmp
    sleep 1
    numberoftarfound=$(find ./*tar* -type f -printf "." | wc -c)
    if [[ $numberoftarfound == 1 ]]
    then
        tanzubundlename=$(find ./*tar* -printf "%f\n")
    fi
    if [[ $numberoftarfound -gt 1 ]]
    then
        printf "\nfound more than 1 bundles..\n"
        find ./*tar* -printf "%f\n"
        printf "Error: only 1 tar file is allowed in ~/binaries dir.\n"
        printf "\n\n"
        exit 1
    fi

    if [[ $numberoftarfound -lt 1 ]]
    then
        printf "\nNo tanzu bundle found. Please place the tanzu bindle in ~/binaries and rebuild again. Exiting...\n"
        exit 1
    fi
    printf "\nTanzu Bundle: $tanzubundlename. Installing..."
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
    printf "\nPlease place the tanzu cli tar file in the binaries directory and perform \"./start.sh/bat forcebuild\" to rebuild with tanzu cli"
    sleep 1
    printf "\nExit..."
    printf "\n\n\n"
    exit 1
fi





export $(cat /root/.env | xargs)
export KUBECTL_VSPHERE_PASSWORD=$(echo $TKG_VSPHERE_CLUSTER_PASSWORD | xargs)

unset login
unset onboardworkloadcluster
unset clusterendpoint
unset clustername

if [[ $@ == "--help"  && "${BASH_SOURCE[0]}" != "${0}" ]]
then
    # "${BASH_SOURCE[0]}" != "${0}" script is being sourced
    # This condition is true ONLY when --help is passed in the init script.
    # In this scenario we just want to print the help message and NOT exit.
    source ~/binaries/readparams-tanzu.sh --printhelp
    return # We do not want to exit. We just dont want to continue the rest.
fi

result=$(source ~/binaries/readparams-tanzu.sh $@)
# source ~/binaries/readparams.sh $@

if [[ $result == *@("Error"|"help")* ]]
then
    printf "Error: $result\n"
    printf "\nProvide valid params\n"
    source ~/binaries/readparams-tanzu.sh --printhelp
    exit
else
    export $(echo $result | xargs)
fi

if [[ -n $login || -n $onboardworkloadcluster ]]
then
    isexist=$(tanzu config server list -o json | jq '.[].context' | xargs)
    if [[ -z $isexist || $isexist != $TKG_SUPERVISOR_ENDPOINT ]]
    then
        printf "\nTanzu context not found matching with $TKG_SUPERVISOR_ENDPOINT. Creating new....\n"
        source ~/binaries/tanzuwizard/tanzu-login.sh
    fi
fi

if [[ -n $onboardworkloadcluster ]]
then
    printf "\n\nstarting onboard of workload cluster...\n\n"
    source ~/binaries/tanzuwizard/tanzu-onboard-workloadcluster.sh $clusterendpoint $clustername
fi


