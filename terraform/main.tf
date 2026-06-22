locals {
  function_root = "${path.module}/../function"
}

module "aws" {
  count  = contains(var.enabled_clouds, "aws") ? 1 : 0
  source = "./modules/aws"

  resource_prefix  = var.resource_prefix
  aws_region       = var.aws_region
  function_root    = local.function_root
  lambda_cloud     = "aws"
  lambda_peer_urls = var.lambda_peer_urls.aws
}

module "gcp" {
  count  = contains(var.enabled_clouds, "gcp") && var.gcp_project_id != "" ? 1 : 0
  source = "./modules/gcp"

  resource_prefix  = var.resource_prefix
  gcp_project_id   = var.gcp_project_id
  gcp_region       = var.gcp_region
  function_root    = local.function_root
  lambda_cloud     = "gcp"
  lambda_peer_urls = var.lambda_peer_urls.gcp
}

module "azure" {
  count  = contains(var.enabled_clouds, "azure") ? 1 : 0
  source = "./modules/azure"

  resource_prefix  = var.resource_prefix
  azure_location   = var.azure_location
  function_root    = local.function_root
  lambda_cloud     = "azure"
  lambda_peer_urls = var.lambda_peer_urls.azure
}
