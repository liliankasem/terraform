#!/bin/bash

RED=`tput setaf 1`
GREEN=`tput setaf 2`
RESET=`tput sgr0`

inputs=$@

for ARGUMENT in "$@"
do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)

    case "$KEY" in
      r)               RESOURCE_GROUP_NAME=${VALUE} ;;
      s)              STORAGE_ACCOUNT_NAME=${VALUE} ;;
      c)                    CONTAINER_NAME=${VALUE} ;;
      f)          BACKEND_CONFIG_FILE_PATH=${VALUE} ;;
      *)
    esac
done

createTerraformBackend() {
  # Create resource group
  az group create --name $RESOURCE_GROUP_NAME --location eastus

  # Create storage account
  az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob

  # Get storage account key
  ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv)

  # Create blob container
  az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --account-key $ACCOUNT_KEY

  echo "${GREEN}Storage Account:    ${RESET}$STORAGE_ACCOUNT_NAME"
  echo "${GREEN}Container:          ${RESET}$CONTAINER_NAME"
  echo "${GREEN}Access Key:         ${RESET}$ACCOUNT_KEY"

  # Append backend config file
  echo "resource_group_name=\"$RESOURCE_GROUP_NAME\""     >> $BACKEND_CONFIG_FILE_PATH
  echo "storage_account_name=\"$STORAGE_ACCOUNT_NAME\""   >> $BACKEND_CONFIG_FILE_PATH
  echo "container_name=\"$CONTAINER_NAME\""               >> $BACKEND_CONFIG_FILE_PATH
  echo "access_key=\"$ACCOUNT_KEY\""                      >> $BACKEND_CONFIG_FILE_PATH
  echo "key=\"local.terraform.tfstate\""                  >> $BACKEND_CONFIG_FILE_PATH
}

# Check Arguments
[[ $inputs < 3 ]] && { exit 1; } || createTerraformBackend
