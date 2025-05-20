# 🚀 BigQuery ➜ Apache Beam (Dataflow) ➜ Parquet on GCS

<p align="center">
  <img alt="GCP" src="https://img.shields.io/badge/GCP-Dataflow-blue?logo=googlecloud" />
  <img alt="Apache Beam" src="https://img.shields.io/badge/Apache%20Beam-2.56-orange?logo=apache" />
  <img alt="Python" src="https://img.shields.io/badge/Python-3.10-yellow?logo=python" />
  <img alt="Terraform" src="https://img.shields.io/badge/Terraform-1.x-purple?logo=terraform" />
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
* **Sink**: Parquet file(s) in a Terraform‑generated bucket `gs://devhelio-460409-dataflow-temp-XXXX/`.

---

## ⚡ Quick Start

```bash
# 0) clone & cd
git clone https://github.com/helioribeiro/gcpdataflow
cd gcpdataflow
gcloud services enable dataflow.googleapis.com bigquery.googleapis.com compute.googleapis.com iam.googleapis.com serviceusage.googleapis.com storage.googleapis.com

# 1) provision infra
PROJECT_ID=$(gcloud config get-value project 2>/dev/null) && \
echo "🔧  Using project: $PROJECT_ID" && \
cd terraform && \
terraform init && \
terraform apply -auto-approve -var="project_id=${PROJECT_ID}"
# grab the bucket_name and service_account_email outputs
cd ..

# 2) local smoke‑test (DirectRunner)
docker compose build         
docker compose run pipeline   --output gs://$(terraform -chdir=terraform output -raw bucket_name)/output/shakespeare

# 3) launch in the cloud (DataflowRunner)
python pipeline.py   --runner DataflowRunner   --project devhelio-460409   --region us-central1   --temp_location gs://$(terraform -chdir=terraform output -raw bucket_name)/temp/   --staging_location gs://$(terraform -chdir=terraform output -raw bucket_name)/staging/   --service_account_email $(terraform -chdir=terraform output -raw service_account_email)   --output gs://$(terraform -chdir=terraform output -raw bucket_name)/output/shakespeare   --max_num_workers 1
```

👉 Check **Dataflow → Jobs** for progress, and **Cloud Storage** for the Parquet file when done.

---

## 🛠️ Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| **gcloud** | ≥ 467 | Auth & API enablement |
| **Terraform** | ≥ 1.3 | IaC provisioning |
| **Docker & Compose** | ≥ 24 | Local DirectRunner (optional) |
| **Python** | ≥ 3.10 | Direct CLI submission (if not using Docker) |

Make sure the following APIs are **enabled** in *devhelio‑460409*:

```bash
gcloud services enable dataflow.googleapis.com                        bigquery.googleapis.com                        compute.googleapis.com
```

---

## ☁️ Infrastructure as Code – Terraform

* **Randomized bucket**: `${project}-dataflow-temp-<suffix>` (multi‑region **US**).  
* **Service Account**: `dataflow-pipeline-sa@devhelio-460409.iam.gserviceaccount.com`  
  * `roles/dataflow.worker` • `roles/dataflow.developer` • `roles/storage.objectAdmin` (bucket‑scoped)  
* **force_destroy** = true → easy teardown.

```bash
terraform destroy -auto-approve -var="project_id=devhelio-460409"
```

---

## 🏃‍♂️ Local Run (DirectRunner)

1. **Build**: `docker compose build`
2. **Run**:  
   ```bash
   docker compose run pipeline      --output gs://<BUCKET>/output/shakespeare      --temp_location gs://<BUCKET>/temp
   ```
3. **Validate**: `gsutil ls gs://<BUCKET>/output/`

No Dataflow charges; only a tiny BigQuery read (under free tier).

---

## ☁️ Cloud Run (Dataflow)

Submit with either **Python** (native) or **Docker**:

```bash
# native
python pipeline.py --runner DataflowRunner ...

# containerised
docker run --rm -v ~/.config/gcloud:/root/.config/gcloud:ro   your-image:latest --runner DataflowRunner ...
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
├── Dockerfile              # Beam + PyArrow image
├── docker-compose.yml      # local DirectRunner harness
├── pipeline.py             # Apache Beam pipeline
├── terraform/
│   └── main.tf             # bucket, service account, IAM
└── README.md               # you’re here
```

---


PROJECT_ID=$(gcloud config get-value project 2>/dev/null) && \
echo "🔧  Enabling APIs for project: $PROJECT_ID" && \
gcloud services enable iam.googleapis.com serviceusage.googleapis.com \
  --project="$PROJECT_ID" && \
echo "⏳  Waiting ~30 s for API propagation…" && sleep 30 && \
terraform init && \
terraform apply -auto-approve -var="project_id=$PROJECT_ID"