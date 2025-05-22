###############################################################################
#  Terraform & provider requirements
###############################################################################
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.25.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

###############################################################################
#  Provider configuration
###############################################################################
provider "google" {
  project = var.project_id
  region  = var.region
}

###############################################################################
#  Variables
###############################################################################
variable "project_id" {
  description = "ID of the GCP project."
  type        = string
}

variable "region" {
  description = "Default GCP region."
  type        = string
  default     = "us-central1"
}

variable "dataflow_sa_account_id" {
  description = "Short name (account_id) for the Dataflow service account."
  type        = string
  default     = "dataflow-sa"
}

###############################################################################
#  Service-account (created once, then always reused)
###############################################################################
resource "google_service_account" "dataflow_sa" {
  project      = var.project_id
  account_id   = var.dataflow_sa_account_id
  display_name = "Dataflow Service Account"

  create_ignore_already_exists = true

  lifecycle {
    prevent_destroy = true       # guard against accidental deletion
  }
}

###############################################################################
#  Bucket for Dataflow staging / temp files
###############################################################################
resource "random_id" "suffix" {
  byte_length = 4                # 8-char hex string
}

resource "google_storage_bucket" "dataflow_bucket" {
  name          = "${var.project_id}-dataflow-temp-${random_id.suffix.hex}"
  location      = var.region
  force_destroy = true           # auto-delete objects if the bucket is removed
}

###############################################################################
#  IAM bindings
###############################################################################
# Dataflow worker role (run jobs)
resource "google_project_iam_member" "dataflow_worker" {
  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# Optional: Dataflow developer role (create templates, flex jobs, etc.)
resource "google_project_iam_member" "dataflow_developer" {
  project = var.project_id
  role    = "roles/dataflow.developer"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

resource "google_project_iam_member" "dataflow_serviceusage" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

resource "google_project_iam_member" "dataflow_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# Bucket permissions – read/write objects
resource "google_storage_bucket_iam_member" "bucket_permissions" {
  bucket = google_storage_bucket.dataflow_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

resource "google_project_iam_member" "dataflow_bq_storage" {
  project = var.project_id
  role    = "roles/bigquery.readSessionUser"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

resource "google_project_iam_member" "dataflow_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# Example (commented) – grant the SA access to a private BigQuery dataset
# resource "google_bigquery_dataset_iam_member" "bq_access" {
#   dataset_id = "your_dataset"
#   role       = "roles/bigquery.dataViewer"
#   member     = "serviceAccount:${google_service_account.dataflow_sa.email}"
# }

###############################################################################
#  Outputs
###############################################################################
output "dataflow_service_account_email" {
  description = "Service-account e-mail used by Dataflow jobs"
  value       = google_service_account.dataflow_sa.email
}

output "bucket_name" {
  description = "GCS bucket for staging / temp files"
  value       = google_storage_bucket.dataflow_bucket.name
}

output "region" {
  value = var.region
}