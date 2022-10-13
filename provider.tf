terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }

        azapi = {
      source  = "azure/azapi"
      version = "=0.1.0"
    }
  }
  required_version = ">= 1.1.0"

}

provider "azurerm" {
  skip_provider_registration = true
  features {}
}

provider "azapi" {
}