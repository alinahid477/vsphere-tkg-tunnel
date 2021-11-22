#!/bin/bash

packagename=$1

listsupportedpackages() {
    printf "\n\nThis wizard is capable of instlling below packages:\n"
    echo -e "\tcert-manager"
    echo -e "\tcontour"
    echo -e "\tfluent-bit"
    echo -e "\tprometheus"
    echo -e "\tgrafana"
    echo -e "\tharbor"
}

if [[ -z $packagename ]]
then
    printf "\nERROR: Empty packagename received.\n"
    listsupportedpackages
    exit 1
fi

printf "\nChecking if package is already installed...\n"
isexist=$(tanzu package installed list --output json -A | jq '.[].name' | xargs | grep -w $packagename)
if [[ -n $isexist ]]
then
    tanzu package installed list -A
    printf "\n\nERROR: packagename $packagename is already installed.\n"
    exit
fi
printf "Package in NOT installed. Installing...\n"

printf "\nRetrieving full package name...\n"
packageid=$(tanzu package available list -A | grep -w $packagename | awk '{print $1}' | xargs)
if [[ -z $packageid ]]
then
    printf "\n\nERROR: Could not find package id."
    listsupportedpackages
    exit
fi
printf "Retrieved full package name: $packageid\n"

printf "\nRetrieving package namespace...\n"
packagenamespace=''
packagenamespace=$(cat ~/binaries/tanzuwizard/package-ns.map | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="'$packageid'"{print $2}' | xargs)
if [[ -z $packagenamespace ]]
then
    printf "\n\nERROR: Not supported by this wizard."
    listsupportedpackages
    exit
fi
printf "Retrieved package namespace: $packagenamespace...\n"


printf "\nRetrieving package version...\n"
packageversion=$(tanzu package available list $packageid -A --output json | jq '.[].version' | xargs)
if [[ -z $packageversion ]]
then
    printf "\n\nERROR: Unable to retrieve package version."
    exit
fi
printf "Retrieved package version: $packageversion...\n"

printf "\nThis require associating with psp...\n"
sleep 1
printf "Checking existing POD security policy:\n"
unset psp
isvmwarepsp=$(kubectl get psp | grep -w vmware-system-privileged)
if [[ -n $isvmwarepsp ]]
then
    printf "found existing psp: vmware-system-privileged\n"
    psp=vmware-system-privileged        
else
    istmcpsp=$(kubectl get psp | grep -w vmware-system-tmc-privileged)
    if [[ -n $istmcpsp ]]
    then
        printf "found existing psp: vmware-system-tmc-privileged\n"
        psp=vmware-system-tmc-privileged
    fi
fi
sleep 2
if [[ -z $SILENTMODE || $SILENTMODE == 'n' ]]
then
    unset pspprompter
    printf "getting list of available Pod Security Policies....\n"
    kubectl get psp
    if [[ -n $psp ]]
    then
        printf "\nSelected existing pod security policy: $psp"
        printf "\nPress/Hit enter to accept $psp"
        pspprompter=" (selected $psp)"  
    else 
        printf "\nHit enter to create a new one"
    fi
    printf "\nOR\nType a name from the available list\n"
    while true; do
        read -p "pod security policy$pspprompter: " inp
        if [[ -z $inp ]]
        then
            if [[ -z $psp ]]
            then 
                printf "\nERROR: A vsphere with tanzu cluster should contain a psp.\n"
                exit 1
            else
                printf "\nAccepted psp: $psp"
                break
            fi
        else
            isvalidvalue=$(kubectl get psp | grep -w $inp)
            if [[ -z $isvalidvalue ]]
            then
                printf "\nYou must provide a valid input.\n"
            else 
                psp=$inp
                printf "\nAccepted psp: $psp"
                break
            fi
        fi
    done
fi

if [[ -n $psp ]]
then
    printf "\nusing psp $psp to create ClusterRole and ClusterRoleBinding for $packagenamespace so that pods for package $packagename can get admitted in that namespace...\n"
    rm /tmp/psp-rolebinding-ns.* > /dev/null 2>&1
    cp ~/binaries/tanzuwizard/psp-rolebinding-ns.template /tmp/
    search=SELECTED_PACKAGE_NAME
    replace=$packagename
    sed -i 's!'$search'!'$replace'!' /tmp/psp-rolebinding-ns.template
    awk -v old="POD_SECURITY_POLICY_NAME" -v new="$psp" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/psp-rolebinding-ns.template > /tmp/psp-rolebinding-ns.tmp
    awk -v old="PACKAGE_NAMESPACE_NAME" -v new="$packagenamespace" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/psp-rolebinding-ns.tmp > /tmp/psp-rolebinding-ns.yaml
    kubectl apply -f /tmp/psp-rolebinding-ns.yaml
    printf "Done.\n"
fi    


packagedatavalues=$(cat ~/binaries/tanzuwizard/data-file.map | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="'$packageid'"{print $2}' | xargs)

if [[ -n $packagedatavalues ]]
then
    printf "\nStarting tanzu package $packagename installtion with $packagedatavalues using tanzu cli...\n"
    tanzu package install $packagename --package-name $packageid --create-namespace --version $packageversion --create-namespace --values-file ~/binaries/tanzuwizard/$packagedatavalues
else
    printf "\nStarting tanzu package $packagename installtion using tanzu cli...\n"
    tanzu package install $packagename --package-name $packageid --create-namespace --version $packageversion --create-namespace
fi

printf "\n*******Package installation COMPLETE*******\n\n"

if [[ -z $packagedatavalues ]]
then
    printf "\n================================\n"
    printf "\nYou can modify the data-values of ~/binaries/tanzuwizard/$packagedatavalues for $packagename and run the below command to update...\n"
    printf "tanzu package installed update $packagename --version $packageversion --values-file ~/binaries/tanzuwizard/$packagedatavalues"
    printf "\n================================\n"
fi

printf "\n\n"