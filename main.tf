locals {
  environment_name = {
    flu-dev   = "dev"
    flu-stage = "stage"
  }
  create_queue = {
    flu-dev   = true
    flu-stage = false
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
  retention_in_days   = 90
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
  name                 = "flu${local.environment_name[terraform.workspace]}datalakedls"
  storage_account_name = azurerm_storage_account.st.name
}

resource "azurerm_storage_queue" "sbq" {
  count = ${local.create_queue[terraform.workspace]} ? 1 : 0
  name                 = "flu${local.environment_name[terraform.workspace]}datalakesbq"
  storage_account_name = azurerm_storage_account.st.name
}

resource "azapi_resource" "aca_env" {
  type      = "Microsoft.App/managedEnvironments@2022-01-01-preview"
  parent_id = azurerm_resource_group.rg.id
  location  = azurerm_resource_group.rg.location
  name      = "flu-${local.environment_name[terraform.workspace]}-datalake-env"
  
  body   = jsonencode({
    properties = {
      appLogsConfiguration = {
        destination               = "log-analytics"
        logAnalyticsConfiguration = {
          customerId = azurerm_log_analytics_workspace.log.workspace_id
          sharedKey  = azurerm_log_analytics_workspace.log.primary_shared_key
        }
      }
    }
 })
}

resource "azapi_resource" "aca" {
  type = "Microsoft.App/containerApps@2022-01-01-preview"
  name = "flu-${local.environment_name[terraform.workspace]}-datalake-aca"
  location = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id

  body = jsonencode({
    properties = {
      managedEnvironmentId = azapi_resource.aca_env.id
      configuration = {
        activeRevisionsMode = "single"
        ingress = {
          external = true
          targetPort = 8080
        }
        secrets = [
          {
            name = "flu-${local.environment_name[terraform.workspace]}-datalake-sbq-connection-string"
            value = azurerm_storage_queue.sbq.name
          }
        ]
      }
      template = {
        containers = [
          {
            image = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
            name = "flu-${local.environment_name[terraform.workspace]}-datalake-ci"
            resources = {
              cpu = 0.25
              memory = "0.5Gi"
            }
          }
        ]
        scale = {
          maxReplicas = 2
          minReplicas = 0
          rules = [
            {
              custom = {
                auth = [
                  {
                    secretRef = "flu-${local.environment_name[terraform.workspace]}-datalake-sbq-connection-string"
                    triggerParameter = "connection"
                  }
                ]
                metadata = {
                  messageCount = "10"
                  queueName = azurerm_storage_queue.sbq.name
                }
                type = "string"
              }
              name = "size-queue"
            }
          ]
        }
      }
    }
  })
}