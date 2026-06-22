locals {
  function_app_name = replace("${var.resource_prefix}fn", "-", "")
}

resource "azurerm_resource_group" "main" {
  name     = "${var.resource_prefix}-rg"
  location = var.azure_location
}

resource "azurerm_storage_account" "main" {
  name                     = substr(replace("${var.resource_prefix}st", "-", ""), 0, 24)
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "events" {
  name                  = "events"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "deploy" {
  name                  = "function-deploy"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

data "archive_file" "function" {
  type        = "zip"
  output_path = "${path.module}/build/function.zip"
  source_dir  = var.function_root
  excludes    = ["__pycache__", "*.pyc", "aws_handler.py", "gcp_main.py", "requirements-aws.txt", "requirements-gcp.txt"]
}

resource "azurerm_storage_blob" "function" {
  name                   = "function-${data.archive_file.function.output_md5}.zip"
  storage_account_name   = azurerm_storage_account.main.name
  storage_container_name = azurerm_storage_container.deploy.name
  type                   = "Block"
  source                 = data.archive_file.function.output_path
}

data "azurerm_storage_account_sas" "function" {
  connection_string = azurerm_storage_account.main.primary_connection_string
  https_only        = true
  start             = "2024-01-01T00:00:00Z"
  expiry            = "2030-01-01T00:00:00Z"
  resource_types { object = true }
  services { blob = true }
  permissions { read = true }
}

resource "azurerm_service_plan" "main" {
  name                = "${var.resource_prefix}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "main" {
  name                = local.function_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  functions_extension_version = "~4"

  site_config {
    application_stack { python_version = "3.12" }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME       = "python"
    AzureWebJobsFeatureFlags       = "EnableWorkerIndexing"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    WEBSITE_RUN_FROM_PACKAGE       = "${azurerm_storage_blob.function.url}${data.azurerm_storage_account_sas.function.sas}"
    LAMBDA_CLOUD                   = var.lambda_cloud
    LAMBDA_PEER_URLS               = jsonencode(var.lambda_peer_urls)
    BLOB_URI                       = "https://${azurerm_storage_account.main.name}.blob.core.windows.net/${azurerm_storage_container.events.name}"
    AZURE_STORAGE_CONNECTION_STRING = azurerm_storage_account.main.primary_connection_string
  }
}
