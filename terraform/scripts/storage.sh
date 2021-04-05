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
      e)                       ENVIRONMENT=${VALUE} ;;
      r)               RESOURCE_GROUP_NAME=${VALUE} ;;
      k)                    KEY_VAULT_NAME=${VALUE} ;;
      s)              STORAGE_ACCOUNT_NAME=${VALUE} ;;
      c)                    CONTAINER_NAME=${VALUE} ;;
      *)
    esac
done

createTerraformBackendStorage() {
  TERRAFORM_FILE="$ENVIRONMENT.terraform.tfstate"

  # Create storage account
  az storage account create --resource-group $RESOURCE_GROUP_NAME \
                            --name $STORAGE_ACCOUNT_NAME \
                            --sku Standard_LRS \
                            --encryption-services blob \
                            --https-only true \
                            --allow-blob-public-access false

  # Get storage account key
  ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv)

  # Create blob container
  az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --account-key $ACCOUNT_KEY

  # Create key vault secrets
  az keyvault secret set --vault-name $KEY_VAULT_NAME --name kv-tf-state-blob-account --value $STORAGE_ACCOUNT_NAME
  az keyvault secret set --vault-name $KEY_VAULT_NAME --name kv-tf-state-blob-container --value $CONTAINER_NAME
  az keyvault secret set --vault-name $KEY_VAULT_NAME --name kv-tf-state-blob-file --value $TERRAFORM_FILE
  az keyvault secret set --vault-name $KEY_VAULT_NAME --name kv-tf-state-blob-access-key --value $ACCOUNT_KEY

  echo -e "\n${GREEN}Storage Account Created:  ${RESET}$STORAGE_ACCOUNT_NAME | $CONTAINER_NAME"
}

# Check Arguments
[[ $inputs < 5 ]] && { exit 1; } || createTerraformBackendStorage
