# 🚀 BigQuery ➜ Apache Beam (Dataflow) ➜ Parquet on GCS

<p align="center">
  <img alt="GCP" src="https://img.shields.io/badge/GCP-Dataflow-blue?logo=googlecloud" />
  <img alt="Apache Beam" src="https://img.shields.io/badge/Apache%20Beam-2.65-orange?logo=apache" />
  <img alt="Python" src="https://img.shields.io/badge/Python-3.12-yellow?logo=python" />
  <img alt="Terraform" src="https://img.shields.io/badge/Terraform-1.3-purple?logo=terraform" />
</p>

> **Demo**: query a BigQuery public dataset, filter it with Apache Beam,  
> and write the result as Parquet to Cloud Storage—locally with **DirectRunner** or fully‑managed on **Dataflow**, all provisioned by **Terraform**.

---

## 📖 Table of Contents

1. [Architecture](#-architecture)
2. [Quick Start](#-quick-start)
3. [Prerequisites](#-prerequisites)
4. [Infrastructure as Code](#-infrastructure-as-code--terraform)
5. [Local Run (DirectRunner)](#-local-run-directrunner)
6. [Cloud Run (Dataflow)](#-cloud-run-dataflow)
7. [Cost & Cleanup](#-cost--cleanup)
8. [Project Structure](#-project-structure)

---

## 🖼️ Architecture

Dataflow (Python), BigQuery, GCS, TerraForm, Docker.

* **Dataset**: `bigquery-public-data.samples.shakespeare` (~6 MB, free tier).  
* **Transform**: keep words with `word_count > 100`.  
* **Sink**: Parquet file(s) in a Terraform‑generated bucket `gs://project-dataflow-temp-XXXX/`.

---

## ⚡ Quick Start

### 1) Run the following commands
```bash
gcloud init
gcloud auth application-default login
git clone https://github.com/helioribeiro/gcpdataflow
cd gcpdataflow
gcloud services enable dataflow.googleapis.com bigquery.googleapis.com bigquerystorage.googleapis.com compute.googleapis.com iam.googleapis.com serviceusage.googleapis.com storage.googleapis.com
pip install -r requirements.txt
chmod +x scripts/create-sa-key.sh

# infra
unset GOOGLE_APPLICATION_CREDENTIALS
PROJECT_ID=$(gcloud config get-value project 2>/dev/null) && \
echo "Using project: $PROJECT_ID" && \
cd terraform && terraform init && terraform apply -auto-approve -var="project_id=$PROJECT_ID" && \
BUCKET_NAME=$(terraform output -raw bucket_name) && \
SA_EMAIL=$(terraform output -raw dataflow_service_account_email) && \
REGION=$(terraform output -raw region) && \
cd .. && \
export DATAFLOW_SA_EMAIL="$SA_EMAIL" && \
./scripts/create-sa-key.sh && \
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/sa-key.json" && \
echo "Using bucket: $BUCKET_NAME"
unset GOOGLE_APPLICATION_CREDENTIALS
```

### 2) Local Test (DirectRunner)
```bash
docker compose build         
docker compose run pipeline \
  --project "$PROJECT_ID" \
  --output gs://$(terraform -chdir=terraform output -raw bucket_name)/output/shakespeare
```

### 3) Dataflow (DataflowRunner)
```bash
python pipeline.py \
  --runner               DataflowRunner \
  --project              "$PROJECT_ID" \
  --region               "$REGION" \
  --temp_location        "gs://$BUCKET_NAME/temp/" \
  --staging_location     "gs://$BUCKET_NAME/staging/" \
  --service_account_email "$DATAFLOW_SA_EMAIL" \
  --output               "gs://$BUCKET_NAME/output/shakespeare" \
  --max_num_workers      1
```

👉 Check **Dataflow → Jobs** for progress, and **Cloud Storage** for the Parquet file when done.

---

## 🛠️ Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| **gcloud** | ≥ 467 | Auth & API enablement |
| **Terraform** | ≥ 1.3 | IaC provisioning |
| **Docker & Compose** | ≥ 24 | Local DirectRunner (optional) |
| **Python** | ≥ 3.12 | Direct CLI submission |
| **Apache Beam (GCP)** | ≥ 2.65 | Transformation Engine |

Make sure the following APIs are **enabled**:

```bash
gcloud services enable dataflow.googleapis.com bigquery.googleapis.com bigquerystorage.googleapis.com compute.googleapis.com iam.googleapis.com serviceusage.googleapis.com storage.googleapis.com 
```

---

## ☁️ Infrastructure as Code – Terraform

* **Randomized bucket**: `${project}-dataflow-temp-<suffix>` (multi‑region **US**).  
* **Service Account**: `dataflow-pipeline-sa@account.iam.gserviceaccount.com`  
  * `roles/dataflow.worker` • `roles/dataflow.developer` • `roles/storage.objectAdmin` (bucket‑scoped)  
* **force_destroy** = true → easy teardown.

---

## 🏃‍♂️ Local Run (DirectRunner)

1. **Build**: `docker compose build`
2. **Run**:  
   ```bash
   docker compose build         
   docker compose run pipeline \
   --project "$PROJECT_ID" \
   --output gs://$(terraform -chdir=terraform output -raw bucket_name)/output/shakespeare
   ```
3. **Validate**: `gsutil ls gs://${BUCKET_NAME}/output/`

No Dataflow charges; only a tiny BigQuery read (under free tier).

---

## ☁️ Cloud Run (Dataflow)

Submit with either **Python** (native) or **Docker**:

```bash
# native
python pipeline.py \
  --runner               DataflowRunner \
  --project              "$PROJECT_ID" \
  --region               "$REGION" \
  --temp_location        "gs://$BUCKET_NAME/temp/" \
  --staging_location     "gs://$BUCKET_NAME/staging/" \
  --service_account_email "$DATAFLOW_SA_EMAIL" \
  --output               "gs://$BUCKET_NAME/output/shakespeare" \
  --max_num_workers      1
```

### Cost Guardrails 💸

| Flag | Value | Why |
|------|-------|-----|
| `--max_num_workers` | **1** | Prevent auto‑scaling |
| `--worker_machine_type` | `e2-small` (optional) | Cheapest vCPU |
| `--disk_size_gb` | `20` (optional) | Minimal persistent disk |
| **Data size** | 6 MB read | Fits in free tier |

A single run typically finishes in < 5 min and costs **≈ $0.02**.

---

## 🧹 Cost & Cleanup

| Resource | Ongoing cost | Cleanup |
|----------|--------------|---------|
| **GCS bucket** | a few MB ⟶ ~\$0.00 | `terraform destroy` |
| **Service account** | free | destroy |
| **Dataflow job** | per‑job | auto‑deleted after 30 days |

Always destroy the bucket if you no longer need the output files.

---

## 📂 Project Structure

```
.
├── create-sa-key.sh        # Script to generate GCP service account key
├── Dockerfile              # Beam + PyArrow container image
├── docker-compose.yml      # Local DirectRunner harness
├── pipeline.py             # Apache Beam pipeline definition
├── auto_gcs_locations.py   # Auto-inject GCS temp/staging options
├── requirements.txt        # Python dependencies
├── terraform/
│   └── main.tf             # Terraform config: GCP resources
├── setup_environment.sh    # Script for quick setup with Terraform
└── README.md               # You're here
```

---