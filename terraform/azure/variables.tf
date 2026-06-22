variable "azure_location" {
  type        = string
  description = "Azure region"
  default     = "westeurope"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix for resource names"
  default     = "minimal-health"
}
