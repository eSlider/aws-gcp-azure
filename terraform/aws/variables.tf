variable "aws_region" {
  type        = string
  description = "AWS region for Lambda and API Gateway"
  default     = "eu-central-1"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix for resource names"
  default     = "minimal-health"
}
