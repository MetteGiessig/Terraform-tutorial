terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    azapi = {
      source = "Azure/azapi"
    }
  }
  required_version = ">= 1.1.0"

}

provider "azurerm" {
  features {}

  subscription_id = "120f86d0-0658-4b55-9567-9628808bd3f7"
  tenant_id = "68d985ee-2a2c-4657-8805-80c51919d65d"
}

provider "azapi" {
}