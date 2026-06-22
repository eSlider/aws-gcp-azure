variable "resource_prefix" {
  type    = string
  default = "minimal-health"
}

variable "azure_location" {
  type    = string
  default = "westeurope"
}

variable "lambda_peer_urls" {
  type    = list(string)
  default = []
}
