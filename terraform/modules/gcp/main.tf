resource "google_project_service" "required" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
  ])
  project            = var.gcp_project_id
  service            = each.value
  disable_on_destroy = false
}

data "google_project" "current" {
  project_id = var.gcp_project_id
}

locals {
  cloudbuild_sa = "${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

resource "google_service_account" "function" {
  account_id   = "${replace(var.resource_prefix, "-", "")}run"
  display_name = "LAMBDA runtime"
  project      = var.gcp_project_id
  depends_on   = [google_project_service.required]
}

resource "google_storage_bucket" "events" {
  name                        = "${var.resource_prefix}-events-${var.gcp_project_id}"
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  force_destroy               = true
  depends_on                  = [google_project_service.required]
}

resource "google_project_iam_member" "cloudbuild_storage" {
  project = var.gcp_project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${local.cloudbuild_sa}"
}

resource "google_project_iam_member" "cloudbuild_artifact_writer" {
  project = var.gcp_project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${local.cloudbuild_sa}"
}

resource "google_project_iam_member" "cloudbuild_logs" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${local.cloudbuild_sa}"
}

resource "google_project_iam_member" "function_logs" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.function.email}"
}

resource "google_storage_bucket_iam_member" "function_writer" {
  bucket = google_storage_bucket.events.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.function.email}"
}

data "archive_file" "function" {
  type        = "zip"
  output_path = "${path.module}/build/function.zip"
  source_dir  = var.function_root
  excludes    = ["__pycache__", "*.pyc", "aws_handler.py", "gcp_main.py", "requirements-aws.txt", "requirements-gcp.txt", "azure"]
}

resource "google_storage_bucket" "source" {
  name                        = "${var.resource_prefix}-src-${var.gcp_project_id}"
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  force_destroy               = true
  depends_on                  = [google_project_service.required]
}

resource "google_storage_bucket_object" "function" {
  name   = "function-${data.archive_file.function.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.function.output_path
}

resource "google_cloudfunctions2_function" "main" {
  name        = "${var.resource_prefix}-lambda"
  location    = var.gcp_region
  description = "LAMBDA multi-route HTTP"

  build_config {
    runtime     = "python312"
    entry_point = "health"
    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.function.name
      }
    }
  }

  service_config {
    available_memory      = "256Mi"
    max_instance_count    = 2
    min_instance_count    = 0
    timeout_seconds       = 60
    ingress_settings      = "ALLOW_ALL"
    service_account_email = google_service_account.function.email
    environment_variables = {
      LAMBDA_CLOUD     = var.lambda_cloud
      LAMBDA_PEER_URLS = jsonencode(var.lambda_peer_urls)
      BLOB_URI         = "gs://${google_storage_bucket.events.name}"
    }
  }

  depends_on = [
    google_project_service.required,
    google_project_iam_member.cloudbuild_storage,
    google_storage_bucket_iam_member.function_writer,
  ]
}

resource "google_cloud_run_service_iam_member" "public" {
  project  = var.gcp_project_id
  location = google_cloudfunctions2_function.main.location
  service  = google_cloudfunctions2_function.main.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
