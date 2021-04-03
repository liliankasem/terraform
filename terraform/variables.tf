variable "tenant_id" {
    description = "The Azure tenant ID."
}

variable "subscription_id" {
    description = "The Azure subscription ID."
}

variable "client_id" {
    description = "The service principal client ID."
}

variable "client_secret" {
    description = "The service principal secret."
}

variable "location" {
  description = "The Azure Region in which all resources groups should be created."
}

variable "rg_name" {
    description = "The name of the resource group"
}

variable "storage_account_name" {
  description = "The name of the storage account"
}

variable "index_document" {
  description = "The index document of the static website"
}

variable "source_content" {
  description = "This is the source content for the static website"
}