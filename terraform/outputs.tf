output "lambda_urls" {
  value = {
    aws   = length(module.aws) > 0 ? module.aws[0].base_url : null
    gcp   = length(module.gcp) > 0 ? module.gcp[0].base_url : null
    azure = length(module.azure) > 0 ? module.azure[0].base_url : null
  }
}

output "blob_uris" {
  value = {
    aws   = length(module.aws) > 0 ? module.aws[0].blob_uri : null
    gcp   = length(module.gcp) > 0 ? module.gcp[0].blob_uri : null
    azure = length(module.azure) > 0 ? module.azure[0].blob_uri : null
  }
}
