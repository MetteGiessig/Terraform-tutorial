variable "region" {
  description = "region"
  default     = "northeurope"
}

variable "container_apps" {
  type = list(object({
    name = string
    image = string
    tag = string
    containerPort = number
    ingress_enabled = bool
    min_replicas = number
    max_replicas = number
    cpu_requests = number
    mem_requests = string
  }))

  default = [ {
   image = "thorstenhans/gopher"
   name = "herogopher"
   tag = "hero"
   containerPort = 80
   ingress_enabled = true
   min_replicas = 1
   max_replicas = 2
   cpu_requests = 0.5
   mem_requests = "1.0Gi"
  }] 
}

resource "azapi_resource" "aca" {
  for_each  = { for ca in var.container_apps: ca.name => ca}
  type      = "Microsoft.App/containerApps@2022-03-01"
  parent_id = azurerm_resource_group.rg.id
  location  = azurerm_resource_group.rg.location
  name      = each.value.name
  
  body = jsonencode({
    properties: {
      managedEnvironmentId = azapi_resource.aca_env.id
      configuration = {
        ingress = {
          external = each.value.ingress_enabled
          targetPort = each.value.ingress_enabled?each.value.containerPort: null
        }
      }
      template = {
        containers = [
          {
            name = "main"
            image = "${each.value.image}:${each.value.tag}"
            resources = {
              cpu = each.value.cpu_requests
              memory = each.value.mem_requests
            }
          }         
        ]
        scale = {
          minReplicas = each.value.min_replicas
          maxReplicas = each.value.max_replicas
        }
      }
    }
  })
  tags = local.tags
}