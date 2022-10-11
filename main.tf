locals {
  environment_name = {
    flu-dev   = "dev"
    flu-stage = "stage"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "flu-${local.environment_name[terraform.workspace]}-datalake-rg"
  location = var.region
}

resource "azurerm_log_analytics_workspace" "log" {
  location            = var.region
  name                = "flu-${local.environment_name[terraform.workspace]}-datalaker-log"
  resource_group_name = azurerm_resource_group.rg.name
  depends_on = [
    azurerm_resource_group.rg,
  ]
}

resource "azurerm_application_insights" "appi" {
  application_type    = "web"
  location            = var.region
  name                = "flu${local.environment_name[terraform.workspace]}-datalake-appi"
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.log.id
  sampling_percentage = 0
  depends_on = [
    azurerm_log_analytics_workspace.log,
  ]
}

resource "azurerm_storage_account" "st" {
  name                             = "flu${local.environment_name[terraform.workspace]}datalakest"
  account_replication_type         = "LRS"
  account_tier                     = "Standard"
  access_tier                      = "Cool"
  is_hns_enabled                   = true
  location                         = "northeurope"
  resource_group_name              = azurerm_resource_group.rg.name
  depends_on = [
    azurerm_resource_group.rg,
  ]
}

resource "azurerm_storage_container" "dls" {
  name                 = "flu-dev-datalake-dls"
  storage_account_name = azurerm_storage_account.st.name
}
