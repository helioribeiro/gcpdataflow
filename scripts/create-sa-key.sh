#!/usr/bin/env bash
set -euo pipefail

###############################################################################
#  1. Figure out the service-account e-mail we need a key for
###############################################################################
#
#   Priority order (first one that exists wins):
#     1) Explicit SA via environment variable   DATAFLOW_SA_EMAIL
#     2) Value from Terraform output            dataflow_service_account_email
#     3) Build it from gcloud’s current project + DATAFLOW_SA_ACCOUNT_ID
#

if [[ -n "${DATAFLOW_SA_EMAIL:-}" ]]; then
  SA_EMAIL="$DATAFLOW_SA_EMAIL"

elif SA_EMAIL=$(terraform output -raw dataflow_service_account_email 2>/dev/null); then
  echo "✓ Found service-account e-mail from Terraform output: $SA_EMAIL"

else
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
  [[ -z "$PROJECT_ID" ]] && { echo "No project set in gcloud config"; exit 1; }

  SA_NAME="${DATAFLOW_SA_ACCOUNT_ID:-dataflow-sa}"
  SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
  echo "✓ Constructed service-account e-mail: $SA_EMAIL"
fi

###############################################################################
#  2. Derive the project ID (needed for gcloud flag)
###############################################################################
PROJECT_ID="${PROJECT_ID:-$(cut -d'@' -f2 <<<"$SA_EMAIL" | cut -d'.' -f1)}"

###############################################################################
#  3. Create the key JSON (will **overwrite** an existing one)
###############################################################################
echo "Creating key file: ./sa-key.json"
gcloud iam service-accounts keys create ./sa-key.json \
  --iam-account="$SA_EMAIL" \
  --project="$PROJECT_ID"

echo "✓ Key created.  Add 'sa-key.json' to .gitignore if you use Git."