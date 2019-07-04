#!/bin/bash

# Script that connects key vault to storage account for manageing key rotation and sas-token generation
# Will configure key-vault with access for user running script, so must be run by someone will full access
# It CANNOT be run by a service principal, must be run by a user!

set -e

SUBSCRIPTION_ID=$1
STORAGEACCOUNT_NAME=$2
KEYVAULT_NAME=$3
STORAGEACCOUNT_ID=$4
ROTATION_DAYS=$5

function usage() {
    echo "Usage: ./renew-tokens.sh {SUBSCRIPTION_ID} {STORAGEACCOUNT_NAME} {KEYVAULT_NAME} {STORAGEACCOUNT_ID} {ROTATION_DAYS}"
    exit 1
}

if [ -z $SUBSCRIPTION_ID ] || [ -z $STORAGEACCOUNT_NAME ] || [ -z $KEYVAULT_NAME ] || [ -z $STORAGEACCOUNT_ID ] || [ -z $ROTATION_DAYS ]; then
    usage
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    expiry_date=$(date -v +1y '+%Y-%m-%dT%H:%M:%SZ')
else
    expiry_date=$(date -d "+1 year" '+%Y-%m-%dT%H:%M:%SZ')
fi

echo "Configuring key rotation with Key Vault..."
az keyvault storage add --vault-name ${KEYVAULT_NAME} -n ${STORAGEACCOUNT_NAME} --active-key-name key1 --auto-regenerate-key --regeneration-period P${ROTATION_DAYS}D --resource-id ${STORAGEACCOUNT_ID}

echo "Generating SAS Token..."
sas_token=$(az storage account generate-sas --account-name ${STORAGEACCOUNT_NAME} --subscription ${SUBSCRIPTION_ID} --output tsv --https-only --permissions rwl --expiry ${expiry_date} --resource-types sco --services b)

echo "Generating SAS Token Definition in Key Vault..."
result=$(az keyvault storage sas-definition create --vault-name ${KEYVAULT_NAME} --account-name ${STORAGEACCOUNT_NAME} -n terraformsastoken --validity-period P1D --sas-type account --template-uri $sas_token)
