# Configure the Azure provider
provider "azurerm" {
  features {}
}

locals {
  resource_group_name = {
    flu-dev   = "flu-dev-datalake-rg"
    flu-stage = "flu-stage-datalake-rg"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name[terraform.workspace]
  location = "North Europe"
}