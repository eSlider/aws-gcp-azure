output "function_url" {
  description = "Public URL for the health endpoint"
  value       = "https://${azurerm_linux_function_app.main.default_hostname}/api/health"
}

output "function_app_name" {
  description = "Deployed Function App name"
  value       = azurerm_linux_function_app.main.name
}
