terraform {
  backend "azurerm" {
    resource_group_name   = "multitstate"
    storage_account_name  = "multitstate14594"
    container_name        = "multitstate"
    key                   = "terraform.tfstate"
    # set ARM_ACCESS_KEY in environment || ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_SUBSCRIPTION_ID ARM_TENANT_ID 
  }
}