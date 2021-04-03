data "azurerm_client_config" "current" {}

# Create Resource Group
resource "azurerm_resource_group" "resource_group" {
  name     = var.rg_name
  location = var.location
}

# Call modules