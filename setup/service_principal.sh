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
      u)                         USERNAME=${VALUE} ;;
      f)                TF_VARS_FILE_PATH=${VALUE} ;;
      *)
    esac
done

createServicePrincipal() {
  # Set service princial name
  USERNAME="terraform-sp-$USERNAME-$RANDOM"

  # Login to Azure
  az login

  # Set Azure subscription
  az account set --subscription=$SUBSCRIPTION_ID

  # Create service principal
  SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --name $USERNAME --role="Contributor" --scopes="/subscriptions/$SUBSCRIPTION_ID")

  SP_NAME=$(echo $SERVICE_PRINCIPAL | jq -r .displayName)
  SP_TENANT=$(echo $SERVICE_PRINCIPAL | jq -r .tenant)
  SP_CLIENT_ID=$(echo $SERVICE_PRINCIPAL | jq -r .appId)
  SP_CLIENT_SECRET=$(echo $SERVICE_PRINCIPAL | jq -r .password)

  echo "${GREEN}Service Principal Name:           ${RESET}$SP_NAME"
  echo "${GREEN}Service Principal Tenant:         ${RESET}$SP_TENANT"
  echo "${GREEN}Service Principal Id:             ${RESET}$SP_CLIENT_ID"
  echo "${GREEN}Service Principal Secret:         ${RESET}$SP_CLIENT_SECRET"

  # Append tfvars file
  echo "tenant_id=\"$SP_TENANT\""                 >> $TF_VARS_FILE_PATH
  echo "subscription_id=\"$SUBSCRIPTION_ID\""     >> $TF_VARS_FILE_PATH
  echo "client_id=\"$SP_CLIENT_ID\""              >> $TF_VARS_FILE_PATH
  echo "client_secret=\"$SP_CLIENT_SECRET\""      >> $TF_VARS_FILE_PATH
}

# Check Arguments
[[ $inputs < 2 ]] && { exit 1; } || createServicePrincipal
