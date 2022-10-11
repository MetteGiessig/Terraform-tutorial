output "instrumentation_key" {
  value = azurerm_application_insights.appi.instrumentation_key
  sensitive = true
}

output "app_id" {
  value = azurerm_application_insights.appi.app_id
  sensitive = true
}