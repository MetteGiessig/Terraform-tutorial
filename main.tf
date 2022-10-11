# Configure the Azure provider
provider "azurerm" {
  features {}
}

locals {
  environment_name = {
    flu-dev   = "flu-dev"
    flu-stage = "flu-stage"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.resource_group_name[terraform.workspace]}-datalake-rg"
  location = "North Europe"
}