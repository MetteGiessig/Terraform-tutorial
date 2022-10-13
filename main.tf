locals {
  environment_name = {
    flu-dev   = "dev"
    flu-stage = "stage"
  }
}

#Creating the Resource Group for all the resources

resource "azurerm_resource_group" "rg" {
  name     = "flu-${local.environment_name[terraform.workspace]}-datalake-log"
  location = "West Europe"
}

#Create the environment with an application insight

resource "azurerm_log_analytics_workspace" "log" {
  location            = azurerm_resource_group.rg.location
  name                = "flu-${local.environment_name[terraform.workspace]}-datalake-log"
  resource_group_name = azurerm_resource_group.rg.name
  retention_in_days   = 90
  depends_on = [
    azurerm_resource_group.rg,
  ]
}

resource "azurerm_application_insights" "appi" {
  application_type    = "web"
  location            = azurerm_resource_group.rg.location
  name                = "flu-${local.environment_name[terraform.workspace]}-datalake-appi"
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.log.id
  sampling_percentage = 0
  depends_on = [
    azurerm_log_analytics_workspace.log,
  ]
}

resource "azurerm_application_insights_smart_detection_rule" "rule" {
  name                    = "Slow server response time"
  application_insights_id = azurerm_application_insights.appi.id
  enabled                 = false
  send_emails_to_subscription_owners = false
}


# Create the storage account with the Azure Data Lake Storage Gen2

resource "azurerm_storage_account" "st" {
  name                             = "flu${local.environment_name[terraform.workspace]}datalakest"
  account_replication_type         = "LRS"
  account_tier                     = "Standard"
  access_tier                      = "Cool"
  is_hns_enabled                   = true
  location                         = azurerm_resource_group.rg.location
  resource_group_name              = azurerm_resource_group.rg.name
  depends_on = [
    azurerm_resource_group.rg,
  ]
}

resource "azurerm_storage_data_lake_gen2_filesystem" "fs" {
  name               = "flu-${local.environment_name[terraform.workspace]}-datalake-fs"
  storage_account_id = azurerm_storage_account.st.id
}

# For the dev environment we create a service bus with a topic queue with a subscribtion

resource "azurerm_servicebus_namespace" "sb" {
  count = azurerm_resource_group.rg.name == "flu-dev-datalake-log" ? 1 : 0
  name                = "flu-${local.environment_name[terraform.workspace]}-datalake-sbn"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  tags = {
    source = "terraform"
  }
}

resource "azurerm_servicebus_topic" "sbt" {
  count = azurerm_resource_group.rg.name == "flu-dev-datalake-log" ? 1 : 0
  name         = "flu-${local.environment_name[terraform.workspace]}-datalake-sbt"
  namespace_id = azurerm_servicebus_namespace.sb[0].id

  enable_partitioning = true
}

resource "azurerm_servicebus_subscription" "sbts" {
  count = azurerm_resource_group.rg.name == "flu-dev-datalake-log" ? 1 : 0
  name               = "flu-${local.environment_name[terraform.workspace]}-datalake-sbts"
  topic_id           = azurerm_servicebus_topic.sbt[0].id
  max_delivery_count = 500
}

# Create a Container registry with a Repository for the docker container

resource "azurerm_container_registry" "acr" {
  name                = "flu${local.environment_name[terraform.workspace]}datalakeacr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
}

resource "null_resource" "docker_push" {
      provisioner "local-exec" {
      command = <<-EOT
        cd Docker-images/flu-queue-flow
        docker build -t test:latest .
        docker login ${azurerm_container_registry.acr.login_server} 
        docker push ${azurerm_container_registry.acr.login_server}
      EOT
      }
    }

# Create a managed Environment with a container appi

resource "azapi_resource" "aca_env" {
  type      = "Microsoft.App/managedEnvironments@2022-01-01-preview"
  name      = "flu-${local.environment_name[terraform.workspace]}-datalake-env"
  parent_id = azurerm_resource_group.rg.id
  location  = azurerm_resource_group.rg.location
  
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
            name = "flu-${local.environment_name[terraform.workspace]}-datalake-sbt-connection-string"
            value =  azurerm_servicebus_namespace.sb[0].default_primary_connection_string
          }
        ]
      }
      template = {
        containers = [
          {
            image = "${azurerm_container_registry.acr.login_server} /containerapps-helloworld:latest"
            name = "flu-${local.environment_name[terraform.workspace]}-datalake-ci"
            resources = {
              cpu = 0.25
              memory = "0.5Gi"
            }
          }
        ]
        scale = {
          maxReplicas = 5
          minReplicas = 0
          rules = [
            {
              custom = {
                auth = [
                  {
                    secretRef = "flu-${local.environment_name[terraform.workspace]}-datalake-sbt-connection-string"
                    triggerParameter = "connection"
                  }
                ]
                metadata = {
                  messageCount = "10"
                  topicName =  azurerm_resource_group.rg.name == "flu-dev-datalake-log" ? azurerm_servicebus_topic.sbt[0].name : var.Topic_name
                  subscriptionName = azurerm_resource_group.rg.name == "flu-dev-datalake-log" ? azurerm_servicebus_topic.sbt[0].name : var.Topic_name
                }
                type = "azure-servicebus"
              }
              name = "size-queue"
            }
          ]
        }
      }
    }
  })
}