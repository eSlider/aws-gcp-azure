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
  display_name = "Minimal health function runtime"
  project      = var.gcp_project_id

  depends_on = [google_project_service.required]
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

resource "google_storage_bucket_iam_member" "cloudbuild_source_reader" {
  bucket = google_storage_bucket.source.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.cloudbuild_sa}"
}

data "archive_file" "function" {
  type        = "zip"
  output_path = "${path.module}/build/function.zip"

  source {
    content  = file("${path.module}/../../functions/gcp/main.py")
    filename = "main.py"
  }

  source {
    content  = file("${path.module}/../../functions/gcp/requirements.txt")
    filename = "requirements.txt"
  }
}

resource "google_storage_bucket" "source" {
  name                        = "${var.resource_prefix}-${var.gcp_project_id}-source"
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket_object" "function" {
  name   = "function-${data.archive_file.function.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.function.output_path
}

resource "google_cloudfunctions2_function" "health" {
  name        = "${var.resource_prefix}-health"
  location    = var.gcp_region
  description = "Minimal health check function"

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
    available_memory        = "128Mi"
    max_instance_count      = 1
    min_instance_count      = 0
    timeout_seconds         = 10
    ingress_settings        = "ALLOW_ALL"
    service_account_email   = google_service_account.function.email
  }

  depends_on = [
    google_project_service.required,
    google_project_iam_member.cloudbuild_storage,
    google_project_iam_member.cloudbuild_artifact_writer,
    google_project_iam_member.cloudbuild_logs,
    google_storage_bucket_iam_member.cloudbuild_source_reader,
  ]
}

resource "google_cloud_run_service_iam_member" "public_invoker" {
  project  = var.gcp_project_id
  location = google_cloudfunctions2_function.health.location
  service  = google_cloudfunctions2_function.health.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
