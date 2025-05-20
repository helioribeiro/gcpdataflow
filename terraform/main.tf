terraform {
  required_version = ">= 1.3.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.73" 
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

data "google_iam_service_accounts" "existing_sa" {
  project = var.project_id

  # exact match on the e‑mail we plan to use
  filter = "email = \"dataflow-pipeline-sa@${var.project_id}.iam.gserviceaccount.com\""
}

resource "google_service_account" "dataflow_sa" {
  count        = length(data.google_iam_service_accounts.existing_sa.accounts) == 0 ? 1 : 0
  account_id   = "dataflow-pipeline-sa"
  display_name = "Dataflow Pipeline Service Account"
}

locals {
  dataflow_sa_email = (
    length(data.google_iam_service_accounts.existing_sa.accounts) > 0
      ? data.google_iam_service_accounts.existing_sa.accounts[0].email
      : google_service_account.dataflow_sa[0].email
  )
}

variable "project_id" {
  description = "Your GCP Project ID"
  type        = string
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "dataflow_bucket" {
  name          = "${var.project_id}-dataflow-temp-${random_id.suffix.hex}"
  location      = "US"
  force_destroy = true
}

resource "google_service_account" "dataflow_sa" {
  account_id   = "dataflow-pipeline-sa"
  display_name = "Dataflow Pipeline Service Account"
}

# Grant Dataflow and resource access roles to the service account (least privilege)
resource "google_project_iam_member" "dataflow_worker" {
  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}
resource "google_project_iam_member" "dataflow_developer" {
  project = var.project_id
  role    = "roles/dataflow.developer"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}
# Allow the service account to read/write objects in the bucket (for staging and output)
resource "google_storage_bucket_iam_member" "bucket_permissions" {
  bucket = google_storage_bucket.dataflow_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.dataflow_sa.email}"
}
# (If reading from a *private* BigQuery dataset, grant bigquery.dataViewer on that dataset. Not needed for public data.)
# resource "google_bigquery_dataset_iam_member" "bq_access" {
#   dataset_id = "your_dataset"
#   role       = "roles/bigquery.dataViewer"
#   member     = "serviceAccount:${google_service_account.dataflow_sa.email}"
# }

output "bucket_name" {
  description = "Name of the GCS bucket for staging and output"
  value       = google_storage_bucket.dataflow_bucket.name
}
output "service_account_email" {
  description = "Service account email to run Dataflow jobs"
  value       = google_service_account.dataflow_sa.email
}