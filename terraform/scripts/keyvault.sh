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
      r)                RESOURCE_GROUP_NAME=${VALUE} ;;
      l)                  RESOURCE_LOCATION=${VALUE} ;;
      k)                     KEY_VAULT_NAME=${VALUE} ;;
      *)
    esac
done

createKeyVault() {
  # Create key vault
  az keyvault create --resource-group $RESOURCE_GROUP_NAME \
                      --location $RESOURCE_LOCATION \
                      --name $KEY_VAULT_NAME

  echo -e "\n${GREEN}Key Vault Created:  ${RESET}$KEY_VAULT_NAME"
}

# Check Arguments
[[ $inputs < 3 ]] && { exit 1; } || createKeyVault
