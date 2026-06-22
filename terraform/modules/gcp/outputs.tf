output "base_url" {
  value = google_cloudfunctions2_function.main.service_config[0].uri
}

output "blob_uri" {
  value = "gs://${google_storage_bucket.events.name}"
}
