output "function_url" {
  description = "Public URL for the health endpoint"
  value       = google_cloudfunctions2_function.health.service_config[0].uri
}
