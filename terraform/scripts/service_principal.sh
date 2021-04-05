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
      s)                  SUBSCRIPTION_ID=${VALUE} ;;
      k)                   KEY_VAULT_NAME=${VALUE} ;;
      p)                     PROJECT_NAME=${VALUE} ;;
      *)
    esac
done

# This script will not work if ran within Azure Pipelines due to insuficiant permissions, unless
# you make your AzDO service principal and Owner with AAD permisions (not recommended).
createServicePrincipal() {
  # Set service princial name
  SP_NAME="http://terraform-sp-$PROJECT_NAME-$RANDOM"

  # Create service principal
  SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --name $SP_NAME --role="Contributor" --scopes="/subscriptions/$SUBSCRIPTION_ID")

  SP_TENANT=$(echo $SERVICE_PRINCIPAL | jq -r .tenant)
  SP_CLIENT_ID=$(echo $SERVICE_PRINCIPAL | jq -r .appId)
  SP_CLIENT_SECRET=$(echo $SERVICE_PRINCIPAL | jq -r .password)

  # Create key vault secrets
  az keyvault secret set --vault-name $KEY_VAULT_NAME --name kv-arm-tenant-id --value $SP_TENANT
  az keyvault secret set --vault-name $KEY_VAULT_NAME --name kv-arm-subscription-id --value $SUBSCRIPTION_ID
  az keyvault secret set --vault-name $KEY_VAULT_NAME --name kv-arm-client-id --value $SP_CLIENT_ID
  az keyvault secret set --vault-name $KEY_VAULT_NAME --name kv-arm-client-secret --value $SP_CLIENT_SECRET

  echo -e "\n${GREEN}Service Principal Created:  ${RESET}$SP_NAME | $SP_CLIENT_ID"
}

# Check Arguments
[[ $inputs < 3 ]] && { exit 1; } || createServicePrincipal
