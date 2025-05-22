#!/bin/bash

# Enable required Google Cloud services
gcloud services enable \
  dataflow.googleapis.com \
  bigquery.googleapis.com \
  bigquerystorage.googleapis.com \
  compute.googleapis.com \
  iam.googleapis.com \
  serviceusage.googleapis.com \
  storage.googleapis.com

# Make create-sa-key.sh executable
chmod +x scripts/create-sa-key.sh

# Clear existing Google credentials
unset GOOGLE_APPLICATION_CREDENTIALS

# Set the project ID from gcloud configuration
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
echo "Using project: $PROJECT_ID"

# Navigate to terraform directory, initialize and apply terraform configuration
cd terraform
terraform init
terraform apply -auto-approve -var="project_id=$PROJECT_ID"

# Fetch outputs from terraform
BUCKET_NAME=$(terraform output -raw bucket_name)
SA_EMAIL=$(terraform output -raw dataflow_service_account_email)
REGION=$(terraform output -raw region)

# Return to the root directory
cd ..

# Export service account email for Dataflow
export DATAFLOW_SA_EMAIL="$SA_EMAIL"

# Generate service account key
./scripts/create-sa-key.sh

# Set Google application credentials
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/sa-key.json"

# Confirm the bucket name
echo "Using bucket: $BUCKET_NAME"

# Unset credentials after completion
unset GOOGLE_APPLICATION_CREDENTIALS
