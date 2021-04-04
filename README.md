# Terraform Local Environment Setup Sample

The aim of this repository is to demonstrate how developers on a team can setup their own local terraform environment for
development purposes automatically without impacting dev and prod variables used in pipelines. This sample is primarily
focused on Azure.

## Prerequisites

- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Azure DevOps]
  - [Terraform Task](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks)

## Get Started

1. Clone this repo
2. `cd terraform`
3. `bash scripts/setup.sh -e <local|dev|prod> -a <subscription_id> -p <project-name> -r <tf-backend-rg> -l <rg-location> -k <tf-backend-kv> -s <tf-backend-storage> -c <tf-backend-storage-container>`
    - Run `bash setup.sh -h` for details on all the options
4. `terraform plan -var-file=environments/.local/variables.tfvars`
5. `terraform apply -var-file=environments/.local/variables.tfvars`

### DevOps

1. Configure service connection for Azure DevOps (requires a service principal)
2. Configure `variables/` for terraform azure resource naming
3. Create the terraform backend
   - You can do this through a pipeline or run the setup script locally.

      ***Locally***

      - `cd terraform`
      - Run the `scripts/setup.sh` script twice from your machine, with environment set to `dev` and then `prod`

      ***DevOps Pipeline*** (requires a manual step)

      1. Create and run the terraform backend pipeline (`.pipelines/terraform.yml`)
          - When this pipeline runs the setup script, it intentionally passes the `--skip-sp` flag as the service principal
            cannot be created from the pipeline due to insufficient permissions.
      2. Run the `service_principal.sh` script locally to create a service principal for Terraform

        ```sh
        cd terraform

        # Give yourself secret permission to the Key Vault that was just created
        az ad user show --id YOUR_AAD_ACCOUNT_EMAIL | jq -r .objectId
        az keyvault set-policy --name KEY_VAULT_NAME --object-id YOUR_OBJECT_ID --secret-permissions get set

        # Create a service principal for terraform
        bash scripts/service_principal.sh s=SUBSCRIPTION_ID k=KEY_VAULT_NAME p=PROJECT_NAME
        ```

4. Create variable groups and link them to the Key Vault that was created by the previous step
   - `kv-terraform-dev`
   - `kv-terraform-prod`
5. Create and run the terraform IaC pipeline (`.pipelines/iac.yml`)

## The Script

1. Creates the `terraform/environments/.local` folder with these empty files `variables.tfvars`,  `backend.config`
2. Creates a new service principal and writes the details into `variables.tfvars`
3. Creates a resource group and storage account for the terraform backend and writes details to `backend.config`
4. Runs `terraform init` using the created backend (`backend.config`), with the directory context set to `terraform/`
5. Copies the dev variables from `terraform/environments/dev/variables.tfvars` to `terraform/environments/.local/variables.tfvars`

The aim is to have a local configuration available to run terraform with one script.

## Improvements

- Use a shared terraform backend resource group and storage account, then the script will just create a new storage container for different local environments
- Deploy a key vault and write service principal details and storage account details
- Update script with option to retrieve existing service principal details from key vault instead of generating a new one every time
- Setup Azure DevOps deployment pipelines for dev and prod deployment
