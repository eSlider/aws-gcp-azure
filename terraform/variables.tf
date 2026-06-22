variable "resource_prefix" {
  type    = string
  default = "minimal-health"
}

variable "enabled_clouds" {
  type    = list(string)
  default = ["aws", "gcp", "azure"]
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "gcp_project_id" {
  type    = string
  default = ""
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "azure_location" {
  type    = string
  default = "westeurope"
}

variable "lambda_peer_urls" {
  type = object({
    aws   = list(string)
    gcp   = list(string)
    azure = list(string)
  })
  default = {
    aws   = []
    gcp   = []
    azure = []
  }
}
