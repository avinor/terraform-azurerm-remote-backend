#!/bin/bash

# Script to set access keys for remote backend storage. Retrieved SAS TOKEN from key vault

set -e

function usage() {
    echo "sh set-access-keys.sh <name>"
    exit 0
}

if [ -z "$1" ]; then
    usage
fi

NAME=$1

sas_token=$(az keyvault secret show --vault-name ${NAME}kv --name ${NAME}sa-terraformsastoken --query value -o tsv)
echo "ARM_SAS_TOKEN=${sas_token}"