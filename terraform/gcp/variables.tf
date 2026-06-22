variable "gcp_project_id" {
  type        = string
  description = "GCP project ID"
}

variable "gcp_region" {
  type        = string
  description = "GCP region (us-central1 recommended for free tier)"
  default     = "us-central1"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix for resource names"
  default     = "minimal-health"
}
