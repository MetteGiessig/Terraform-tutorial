# Configure the Azure provider
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "North Europe"

tags = {
    Environment = "Dev"
    Team = "Terraform"
  }
}