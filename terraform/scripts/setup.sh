#!/bin/bash

export TERM=xterm-256color

RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
CYAN=`tput setaf 6`
RESET=`tput sgr0`

SKIP_SP_CREATION='false'
WORKING_DIRECTORY=$(pwd)

usage(){
  echo "${CYAN}*** Terraform Setup Script ***"
  echo
  echo "${CYAN}Usage: ./setup.sh [OPTIONS]"
  echo
  echo "${CYAN}Options:"
  echo "${CYAN}-e             :[required] environment - local, dev, prod"
  echo "${CYAN}-a             :[required] azure subscription Id"
  echo "${CYAN}-p             :[required] project name. Used when creating the service principal, the final name will look something like 'http://terraform-sp-projectname-1028018'"
  echo "${CYAN}-r             :[required] terraform backend resource group name"
  echo "${CYAN}-l             :[required] terraform backend resource group location"
  echo "${CYAN}-k             :[required] terraform backend key vault name"
  echo "${CYAN}-s             :[required] terraform backend storage account name"
  echo "${CYAN}-c             :[required] terraform backend storage container name"
  echo "${CYAN}-d             :[optional] set the working directory, defaults to current directory. This should be your terraform folder"
  echo "${CYAN}--skip-sp      :[optional] skip the service principal creation step, required when running in a DevOps pipeline - defaults to false"
  echo "${CYAN}-h             :[optional] prints out the script usage description"
}

OPTS_COUNT=0
while getopts e:a:p:r:l:k:s:c:d:h-: flag
do
  case "${flag}" in
    e)                          ENVIRONMENT=${OPTARG}; ((OPTS_COUNT=OPTS_COUNT+1)) ;;
    a)                      SUBSCRIPTION_ID=${OPTARG}; ((OPTS_COUNT=OPTS_COUNT+1)) ;;
    p)                         PROJECT_NAME=${OPTARG}; ((OPTS_COUNT=OPTS_COUNT+1)) ;;
    r)                  RESOURCE_GROUP_NAME=${OPTARG}; ((OPTS_COUNT=OPTS_COUNT+1)) ;;
    l)              RESOURCE_GROUP_LOCATION=${OPTARG}; ((OPTS_COUNT=OPTS_COUNT+1)) ;;
    k)                       KEY_VAULT_NAME=${OPTARG}; ((OPTS_COUNT=OPTS_COUNT+1)) ;;
    s)                 STORAGE_ACCOUNT_NAME=${OPTARG}; ((OPTS_COUNT=OPTS_COUNT+1)) ;;
    c)                       CONTAINER_NAME=${OPTARG}; ((OPTS_COUNT=OPTS_COUNT+1)) ;;
    d)                                                 WORKING_DIRECTORY=${OPTARG} ;;
    h)                                                             usage && exit 1 ;;
    -)
      case ${OPTARG} in
        "skip-sp")                                         SKIP_SP_CREATION='true' ;;
      esac ;;
    *)                                     echo "Unknown parameter passed"; exit 1 ;;
  esac
done

deployAzureResources() {
  # Login to Azure if running localling. In Azure DevOps, use the Az CLI task with a service connection
  if [ $ENVIRONMENT = 'local' ]; then
    az login
    az account set --subscription=$SUBSCRIPTION_ID
  fi

  # Prepare script paths
  KEY_VAULT_SCRIPT="$WORKING_DIRECTORY/scripts/keyvault.sh"
  STORAGE_SCRIPT="$WORKING_DIRECTORY/scripts/storage.sh"
  SERVICE_PRINCIPAL_SCRIPT="$WORKING_DIRECTORY/scripts/service_principal.sh"

  # Create a resource group
  echo -e "\n$(tput bold)Creating resource group . . .\n${RESET}"
  az group create --name $RESOURCE_GROUP_NAME --location $RESOURCE_GROUP_LOCATION

  # Run setup scripts
  echo -e "\n$(tput bold)Creating key vault . . .\n${RESET}"
  . $KEY_VAULT_SCRIPT r=$RESOURCE_GROUP_NAME l=$RESOURCE_GROUP_LOCATION k=$KEY_VAULT_NAME

  # You cannot create a new service principal in Azure Pipelines through another service principal (service connection)
  # without AAD permisions. When running in pipelines, skip this step and run the service_principal.sh script manually.
  if [ $SKIP_SP_CREATION = 'false' ]; then
    echo -e "\n$(tput bold)Creating service principal . . .\n${RESET}"
    . $SERVICE_PRINCIPAL_SCRIPT s=$SUBSCRIPTION_ID k=$KEY_VAULT_NAME p=$PROJECT_NAME
  else
    echo -e "\n$(tput bold)${YELLOW}Skipping service principal creation.${RESET}"
  fi

  echo -e "\n$(tput bold)Creating storage account . . .\n${RESET}"
  . $STORAGE_SCRIPT e=$ENVIRONMENT r=$RESOURCE_GROUP_NAME k=$KEY_VAULT_NAME s=$STORAGE_ACCOUNT_NAME c=$CONTAINER_NAME

  # If local environment, create the ./local files and init terraform
  if [ $ENVIRONMENT = 'local' ]; then
    createLocalEnvironment
  fi
}

createLocalEnvironment() {
  echo -e "\n$(tput bold)Creating local environment directory . . .\n${RESET}"

  # Setup paths
  ENVIRONMENT_FOLDER_PATH=$WORKING_DIRECTORY'/environments/.local'
  BACKEND_CONFIG_FILE_PATH=$ENVIRONMENT_FOLDER_PATH'/backend.config'
  TF_VARS_FILE_PATH=$ENVIRONMENT_FOLDER_PATH'/variables.tfvars'

  # Create .local environment folder & files
  echo "${GREEN}Creating: $ENVIRONMENT_FOLDER_PATH ${RESET}"
  eval mkdir -p $ENVIRONMENT_FOLDER_PATH

  echo "${GREEN}Creating: $BACKEND_CONFIG_FILE_PATH ${RESET}"
  echo > $BACKEND_CONFIG_FILE_PATH

  echo "${GREEN}Creating: $TF_VARS_FILE_PATH ${RESET}"
  echo > $TF_VARS_FILE_PATH

  echo -e "\n$(tput bold)Writing file content . . .\n${RESET}"

  # Append backend config file
  ACCOUNT_KEY=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name kv-tf-state-blob-access-key | jq -r .value)
  TERRAFORM_FILE=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name kv-tf-state-blob-file | jq -r .value)

  echo "resource_group_name=\"$RESOURCE_GROUP_NAME\""     >> $BACKEND_CONFIG_FILE_PATH
  echo "storage_account_name=\"$STORAGE_ACCOUNT_NAME\""   >> $BACKEND_CONFIG_FILE_PATH
  echo "container_name=\"$CONTAINER_NAME\""               >> $BACKEND_CONFIG_FILE_PATH
  echo "access_key=\"$ACCOUNT_KEY\""                      >> $BACKEND_CONFIG_FILE_PATH
  echo "key=\"$TERRAFORM_FILE\""                          >> $BACKEND_CONFIG_FILE_PATH

  # Append tfvars file
  SP_TENANT=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name kv-arm-tenant-id | jq -r .value)
  SP_CLIENT_ID=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name kv-arm-client-id | jq -r .value)
  SP_CLIENT_SECRET=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name kv-arm-client-secret | jq -r .value)

  echo "tenant_id=\"$SP_TENANT\""                         >> $TF_VARS_FILE_PATH
  echo "subscription_id=\"$SUBSCRIPTION_ID\""             >> $TF_VARS_FILE_PATH
  echo "client_id=\"$SP_CLIENT_ID\""                      >> $TF_VARS_FILE_PATH
  echo "client_secret=\"$SP_CLIENT_SECRET\""              >> $TF_VARS_FILE_PATH

  # Run terraform
  echo -e "\n$(tput bold)Terraform init . . .\n${RESET}"
  eval terraform init -backend-config=$BACKEND_CONFIG_FILE_PATH $TERRAFORM_FOLDER_PATH

  # Add default dev variables to our .local terraform variables file
  echo -e "\n$(tput bold)Setup variables.tfvars file with dev variables . . .\n${RESET}"
  paste $WORKING_DIRECTORY'/environments/dev/variables.tfvars' >> $TF_VARS_FILE_PATH
}

start() {
  echo -e "\n$(tput bold)Starting terraform setup script!\n${RESET}"

  echo "${GREEN}Environment:                ${RESET}$ENVIRONMENT"
  echo "${GREEN}Project Name:               ${RESET}$PROJECT_NAME"
  echo "${GREEN}Subscription Id:            ${RESET}$SUBSCRIPTION_ID"
  echo "${GREEN}Backend Resource Group:     ${RESET}$RESOURCE_GROUP_NAME | $RESOURCE_GROUP_LOCATION"
  echo "${GREEN}Backend Key Vault:          ${RESET}$KEY_VAULT_NAME"
  echo "${GREEN}Backend Storage Account:    ${RESET}$STORAGE_ACCOUNT_NAME"
  echo "${GREEN}Backend Storage Container:  ${RESET}$CONTAINER_NAME"

  RESOURCE_GROUP_EXISTS=$(az group exists -n $RESOURCE_GROUP_NAME)

  if [ $RESOURCE_GROUP_EXISTS = 'false' ]; then
      echo -e "\n$(tput bold)Azure resources don't exist, creating from scrach.\n${RESET}"
      deployAzureResources
  else
    if [ $ENVIRONMENT = 'local' ]; then
      echo -e "\n$(tput bold)Azure $ENVIRONMENT resources already exist, do you want to write the existing values to the environment/.local folder and setup terraform?${RESET}"
      echo "${YELLOW}Warning: This will override any values that already exist in the terraform/enironment/.local folder.${RESET}"
      select yn in "Yes" "No"; do
          case $yn in
              Yes ) createLocalEnvironment; break;;
              No  ) exit;;
          esac
      done
    else
      echo -e "\n$(tput bold)${GREEN}Azure $ENVIRONMENT resources already exist, exiting script.\n${RESET}"
      exit
    fi
  fi

  echo -e "\n$(tput bold)${GREEN}All done!\n${RESET}"
  exit
}

# Exit script if we don't get all required arguments
[[ $OPTS_COUNT < 5 ]] && { usage && exit 1; } || start
