locals {
  environment_name = {
    flu-dev   = "flu-dev"
    flu-stage = "flu-stage"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.environment_name[terraform.workspace]}-datalake-rg"
  location = var.region
}

resource "azurerm_log_analytics_workspace" "log" {
  location            = var.region
  name                = "${local.environment_name[terraform.workspace]}-datalaker-log"
  resource_group_name = azurerm_resource_group.rg.name
  depends_on = [
    azurerm_resource_group.rg,
  ]
}

resource "azurerm_application_insights" "appi" {
  application_type    = "web"
  location            = var.region
  name                = "${local.environment_name[terraform.workspace]}-datalake-appi"
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.log.id
  sampling_percentage = 0
  depends_on = [
    azurerm_log_analytics_workspace.log,
  ]
}