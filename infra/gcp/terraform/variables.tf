variable "resource_prefix" {
  type    = string
  default = "minimal-health"
}

variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "lambda_peer_urls" {
  type    = list(string)
  default = []
}
