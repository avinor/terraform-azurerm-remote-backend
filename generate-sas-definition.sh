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
    echo "Usage: ./renew-tokens.sh {SUBSCRIPTION_ID} {STORAGEACCOUNT_NAME} {KEYVAULT_NAME}"
    exit 1
}

if [ -z $SUBSCRIPTION_ID ]; then
    usage
fi

if [ -z $STORAGEACCOUNT_NAME ]; then
    usage
fi

if [ -z $KEYVAULT_NAME ]; then
    usage
fi

expiry_date=$(date -d "+1 year" '+%Y-%m-%dT%H:%M:%SZ')

echo -n "Granting access to key-vault..."
az keyvault set-policy --name ${KEYVAULT_NAME} --upn $(az ad signed-in-user show -o tsv --query userPrincipalName) --storage-permission get list listsas delete set update regeneratekey recover backup restore purge
echo "  SUCCESS"

echo ""
az keyvault storage add --vault-name ${KEYVAULT_NAME} -n ${STORAGEACCOUNT_NAME} --active-key-name key1 --auto-regenerate-key --regeneration-period P${ROTATION_DAYS}D --resource-id ${STORAGEACCOUNT_ID}

echo -n "Generating SAS Token..."
sas_token=$(az storage container generate-sas --account-name ${STORAGEACCOUNT_NAME} --subscription ${SUBSCRIPTION_ID} --output tsv --https-only --permissions rwl --expiry ${expiry_date})
echo "  SUCCESS"

echo -n "Generating SAS Token Definition in Key Vault..."
result=$(az keyvault storage sas-definition create --vault-name <YourVaultName> --account-name <YourStorageAccountName> -n <NameOfSasDefinitionYouWantToGive> --validity-period P2D --sas-type account --template-uri $sas_token)
echo "  SUCCESS"
