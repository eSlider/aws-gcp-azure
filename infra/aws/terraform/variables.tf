variable "resource_prefix" {
  type    = string
  default = "minimal-health"
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "lambda_peer_urls" {
  type    = list(string)
  default = []
}
