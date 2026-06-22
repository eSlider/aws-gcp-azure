output "base_url" {
  value = "https://${azurerm_linux_function_app.main.default_hostname}/api"
}

output "blob_uri" {
  value = "https://${azurerm_storage_account.main.name}.blob.core.windows.net/${azurerm_storage_container.events.name}"
}
