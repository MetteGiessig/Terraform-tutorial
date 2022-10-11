terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/aws"
      version = "~> 3.0.2"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.0.0"
    }
  }

  required_version = ">= 1.1.0"
}