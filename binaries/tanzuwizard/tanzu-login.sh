#!/bin/bash

printf "\nChecking if already on supervisor cluster...\n"
isexist=$(kubectl get tkc -A --no-headers --output custom-columns=":metadata.name" | head -n 1)
if [[ -z $isexist ]]
then
    printf "\nCurrent context is not supervisor cluster."
    printf "\nSwitching to supervisor...."

    source ~/binaries/tkgwizard.sh --switch-to-supervisor
fi

export $(cat /root/.env | xargs)
printf "\nPerforming tanzu login...."
tanzu login --kubeconfig ~/.kube/config --name $TKG_SUPERVISOR_ENDPOINT --context $TKG_SUPERVISOR_ENDPOINT

printf "\n==>Tanzu login DONE."