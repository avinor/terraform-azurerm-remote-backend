#!/bin/bash

# Script that renews the SAS Tokens in key-vault
# By default adds token thats valid for 1 year

set -e

SUBSCRIPTION_ID=$1
STORAGEACCOUNT_NAME=$2
CONTAINER=$3
KEYVAULT_NAME=$4
SHARED_CONTAINER=$5

function usage() {
    echo "Usage: ./renew-tokens.sh {SUBSCRIPTION_ID} {STORAGEACCOUNT_NAME} {CONTAINER} {KEYVAULT_NAME} {?SHARED_CONTAINER}"
    exit 1
}

if [ -z $STORAGEACCOUNT_NAME ]; then
    usage
fi

if [ -z $CONTAINER ]; then
    usage
fi

if [ -z $SUBSCRIPTION_ID ]; then
    usage
fi

if [ -z $KEYVAULT_NAME ]; then
    usage
fi

expiry_date=$(date -d "+1 year" '+%Y-%m-%dT%H:%M:%SZ')

echo -n -e "\e[0mGenerating SAS Token..."
sas_token=$(az storage container generate-sas -n ${CONTAINER} --account-name ${STORAGEACCOUNT_NAME} --subscription ${SUBSCRIPTION_ID} --output tsv --https-only --permissions rwl --expiry ${expiry_date})
echo -e "  \e[32mSUCCESS"

echo -n -e "\e[0mStoring SAS Token in key-vault..."
result=$(az keyvault secret set --vault-name ${KEYVAULT_NAME} --name 'SAS-TOKEN' --value "${sas_token}" --expires "${expiry_date}")
echo -e "  \e[32mSUCCESS"

if ! [ -z $SHARED_CONTAINER ]; then
    echo -n -e "\e[0mGenerating shared SAS Token..."
    sas_token=$(az storage container generate-sas -n ${SHARED_CONTAINER} --account-name ${STORAGEACCOUNT_NAME} --subscription ${SUBSCRIPTION_ID} --output tsv --https-only --permissions rl --expiry ${expiry_date})
    echo -e "  \e[32mSUCCESS"

    echo -n -e "\e[0mStoring shared SAS Token in key-vault..."
    result=$(az keyvault secret set --vault-name ${KEYVAULT_NAME} --name 'SHARED-SAS-TOKEN' --value "${sas_token}" --expires "${expiry_date}")
    echo -e "  \e[32mSUCCESS"
fi