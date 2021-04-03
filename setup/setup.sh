#!/bin/bash

RED=`tput setaf 1`
GREEN=`tput setaf 2`
CYAN=`tput setaf 6`
RESET=`tput sgr0`

BACKEND_SCRIPT="setup/backend.sh"
SERVICE_PRINCIPAL_SCRIPT="setup/service_principal.sh"

workingDirectory=$(pwd)

usage(){
    echo "${CYAN}*** Local Environment Terraform Setup Script ***"
    echo
    echo "${CYAN}Usage: ./setup.sh -a <subscription_id> -u <username> -r <resource_group> -s <storage_account> -c <container_name>"
    echo
    echo "${CYAN}Options:"
    echo "${CYAN}-a          :[required] azure subscription Id"
    echo "${CYAN}-u          :[required] name to use when creating your service principal, the final name will look something like 'terraform-sp-username--1028018'"
    echo "${CYAN}-r          :[required] terraform backend resource group name"
    echo "${CYAN}-s          :[required] terraform backend storage account name"
    echo "${CYAN}-c          :[required] terraform backend storage container name"
    echo "${CYAN}-d          :[optional] set the working directory, defaults to current directory. Files created by this script are relative to the working directory."
    echo "${CYAN}-h          :[optional] prints out the script usage description"
}

opts_count=0
while getopts :ha:u:r:s:c:d: flag
do
    case "${flag}" in
        a)                      subscriptionId=${OPTARG}; ((opts_count=opts_count+1)) ;;
        u)                            username=${OPTARG}; ((opts_count=opts_count+1)) ;;
        r)            backendResourceGroupName=${OPTARG}; ((opts_count=opts_count+1)) ;;
        s)           backendStorageAccountName=${OPTARG}; ((opts_count=opts_count+1)) ;;
        c)                backendContainerName=${OPTARG}; ((opts_count=opts_count+1)) ;;
        d)                                                 workingDirectory=${OPTARG} ;;
        h)                                                            usage && exit 1 ;;
        *)                                    echo "Unknown parameter passed"; exit 1 ;;
    esac
done

start() {
  echo -e "\n$(tput bold)Setting up local environment . . .\n${RESET}"

  echo "${GREEN}Subscription Id:            ${RESET}$subscriptionId"
  echo "${GREEN}Username:                   ${RESET}$username"
  echo "${GREEN}Backend Resource Group:     ${RESET}$backendResourceGroupName"
  echo "${GREEN}Backend Storage Account:    ${RESET}$backendStorageAccountName"
  echo "${GREEN}Backend Storage Container:  ${RESET}$backendContainerName"

  echo -e "\n$(tput bold)Creating local environment directory . . .\n${RESET}"

  # Configure paths
  terraformFolderPath=${workingDirectory}'/terraform'
  localEnvironmentFolderPath=$terraformFolderPath'/environments/.local'
  backendConfigFile=$localEnvironmentFolderPath'/backend.config'
  tfvarsFile=$localEnvironmentFolderPath'/variables.tfvars'

  # Create .local environment folder & files
  echo $GREEN
  echo "Creating: $localEnvironmentFolderPath"
  eval mkdir -p $localEnvironmentFolderPath
  echo "Creating: $backendConfigFile"
  echo > $backendConfigFile
  echo "Creating: $tfvarsFile"
  echo > $tfvarsFile
  echo $RESET

  # Run setup scripts
  echo -e "\n$(tput bold)Creating service principal . . .\n${RESET}"
  . $SERVICE_PRINCIPAL_SCRIPT s=$subscriptionId u=$username f=$tfvarsFile

  echo -e "\n$(tput bold)Creating terraform backend resources . . .\n${RESET}"
  . $BACKEND_SCRIPT r=$backendResourceGroupName s=$backendStorageAccountName c=$backendContainerName f=$backendConfigFile

  # Run terraform
  echo -e "\n$(tput bold)Terraform init . . .\n${RESET}"
  eval terraform init -backend-config=$backendConfigFile $terraformFolderPath

  # Add default dev variables to our .local terraform variables file
  echo -e "\n$(tput bold)Setup variables.tfvars file with dev variables . . .\n${RESET}"
  paste $terraformFolderPath'/environments/dev/variables.tfvars' >> $tfvarsFile
}

# Exit program if we don't get all required arguments
[[ $opts_count < 5 ]] && { usage && exit 1; } || start
