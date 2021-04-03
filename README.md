# Terraform Local Environment Setup Sample

The aim of this repository is to demonstrate how developers on a team can setup their own local terraform environment for
development purposes automatically without impacting dev and prod variables used in pipelines. This sample is primarily
focused on Azure.

## Prerequisites

- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)

## Get Started

1. Clone this repo
1. `bash setup/setup.sh -a <subscription_id> -u <sp-name> -r <tf-backend-rg> -s <tf-backend-storage> -c <tf-backend-storage-container>`
    - Run `bash setup.sh -h` for details on all the options
1. `terraform plan  -var-file=terraform/environments/.local/variables.tfvars terraform`
1. `terraform apply  -var-file=terraform/environments/.local/variables.tfvars terraform`

## The Script

1. Creates the `terraform/environments/.local` folder with these empty files `variables.tfvars`,  `backend.config`
1. Creates a new service principal and writes the details into `variables.tfvars`
1. Creates a resource group and storage account for the terraform backend and writes details to `backend.config`
1. Runs `terraform init` using the created backend (`backend.config`), with the directory context set to `terraform/`
1. Copies the dev variables from `terraform/environments/dev/variables.tfvars` to `terraform/environments/.local/variables.tfvars`

The aim is to have a local configuration available to run terraform with one script.

## Improvements

- Use a shared terraform backend resource group and storage account, then the script will just create a new storage container for different local environments
- Deploy a key vault and write service principal details and storage account details
- Update script with option to retrieve existing service principal details from key vault instead of generating a new one every time
- Setup Azure DevOps deployment pipelines for dev and prod deployment
