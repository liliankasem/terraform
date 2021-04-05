# Terraform Environment Setup Sample

The aim of this repository is to demonstrate how developers on a team can setup their own local terraform environment for
development purposes automatically without impacting dev and prod variables used in pipelines, and how to setup dev and prod
environments using Azure DevOps Pipelines. This sample is primarily focused on Azure.

## Prerequisites

- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Azure DevOps](https://azure.microsoft.com/services/devops/)
  - [Terraform Task](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks)
- [Azure Subscription](https://azure.microsoft.com/free/)

## Get Started

### Local

1. Clone this repo
1. `cd terraform`
1. `bash scripts/setup.sh -e <local|dev|prod> -a <subscription_id> -p <project-name> -r <tf-backend-rg> -l <rg-location> -k <tf-backend-kv> -s <tf-backend-storage> -c <tf-backend-storage-container>`
    - Run `bash scripts/setup.sh -h` for details on all the options
1. `terraform plan -var-file=environments/.local/variables.tfvars`
1. `terraform apply -var-file=environments/.local/variables.tfvars`

### DevOps

[Example Azure DevOps project](https://dev.azure.com/liliankasem/Terraform%20Sample/_build).

1. Create an [Azure Resource Manager Service Connection](https://docs.microsoft.com/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml)
   for Azure DevOps (requires a service principal)
     - You might need multiple service connections for all of your environments/subscriptions
1. Configure the `.pipelines/terraform.yml` file with the names of the service connection you created
1. Configure `.pipelines/variables/` files with terraform backend resource names and Azure subscription Id
1. Create the terraform backend
   - You can do this through a pipeline or run the setup script locally.

      ***Locally***

      - `cd terraform`
      - Run the `scripts/setup.sh` script from your machine for all your environments (e.g. `dev` and `prod`)

      ***DevOps Pipeline*** (requires a manual step)

      1. Create and run the terraform backend pipeline (`.pipelines/terraform.yml`)
          - When this pipeline runs the setup script, it intentionally passes the `--skip-sp` flag as the service principal
            cannot be created from the pipeline due to insufficient permissions.
      1. Run the `service_principal.sh` script locally to create a service principal for Terraform

        > Run these steps for each environment, such as `dev` and `prod`

        ```sh
        cd terraform

        # Give yourself secret permissions to the Key Vault that was created
        az ad user show --id YOUR_AAD_ACCOUNT_EMAIL | jq -r .objectId
        az keyvault set-policy --name KEY_VAULT_NAME --object-id YOUR_OBJECT_ID --secret-permissions get set

        # Create a service principal for terraform
        bash scripts/service_principal.sh s=SUBSCRIPTION_ID k=KEY_VAULT_NAME p=PROJECT_NAME
        ```

1. Create these [variable groups and link them to the Key Vaults](https://docs.microsoft.com/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml#link-secrets-from-an-azure-key-vault)
   that were created by the previous step
   - `kv-terraform-dev`
   - `kv-terraform-prod`
   - Make sure to add all of the secrets that have been created to the variable groups
1. Create and run the terraform IaC pipeline (`.pipelines/iac.yml`)

## The Script

The aim is to have a local configuration available to run terraform with one script.

- Checks if the terraform backend resource group already exists:
  - If no, the script will [start deploying the Azure resources](#deploy-azure-resources) required for the terraform backend
  - If yes and local environment, user will be prompted if they want setup their [local terraform environment](#setup-local-environment)
    using the existing resources in the Key Vault (from a previous script run), or exit the script
  - If yes and not-local environment, the script will exit

### Deploy Azure Resources

1. Log user into Azure if running locally. In Azure DevOps, the Az CLI task is used with a service connection
1. Prepare path variables for the scripts we need to run
1. Create a resource group
1. Create a key vault
1. Check for `--skip-sp` flag
   - `--skip-sp` = `true`: skip service principal creation step
   - `--skip-sp` = `false`: create a new service principal for terraform and save details to key vault
1. Create terraform backend storage account and save details to key vault
1. If running for the local environment, [setup the local terraform environment](#setup-local-environment)

### Setup Local Environment

1. Creates the `terraform/environments/.local` folder with these empty files: `variables.tfvars`,  `backend.config`
1. Reads the terraform service principal values from key vault and writes them into `variables.tfvars`
1. Reads the terraform backend storage account values from key vault and writes them into `backend.config`
1. Runs `terraform init` using the created backend (`backend.config`)
1. Copies the dev variables from `terraform/environments/dev/variables.tfvars` to `terraform/environments/.local/variables.tfvars`
