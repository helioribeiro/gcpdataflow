# ---------- auto_gcs_locations.py ----------
import sys
import re
import uuid
from urllib.parse import urlparse

from google.cloud import storage               # pip install google-cloud-storage
from apache_beam.options.pipeline_options import (
    PipelineOptions, GoogleCloudOptions, SetupOptions
)

def _parse_gcs_path(path: str):
    """
    Converts gs://bucket/path → ('bucket', 'path')
    """
    parsed = urlparse(path)
    if parsed.scheme != "gs":
        raise ValueError(f"{path} is not a valid GCS URI (must start with gs://)")
    return parsed.netloc, parsed.path.lstrip("/")

def _ensure_bucket(bucket: str, project: str | None):
    """
    Creates the bucket if it does not already exist.
    """
    client = storage.Client(project=project)
    bkt = client.bucket(bucket)
    if not bkt.exists():
        print(f"[auto-gcs] Bucket gs://{bucket} not found – creating it…")
        bkt.storage_class = "STANDARD"
        # You can hard-code a region here if you like:
        bkt.create(location="US")              # or europe-west1, etc.
    else:
        print(f"[auto-gcs] Bucket gs://{bucket} already exists.")
    return bkt

def enrich_args_with_gcs_locations(argv: list[str]) -> list[str]:
    """
    Returns a *new* argv list containing --temp_location (and, for Dataflow,
    --staging_location) if the user did not specify them.
    """
    args = argv[:]        # shallow copy
    opts = PipelineOptions(args)
    gcloud = opts.view_as(GoogleCloudOptions)

    # 1) Find an output path to reuse its bucket, else invent one.
    output_path = None
    for i, a in enumerate(args):
        if a.startswith("--output"):
            output_path = a.split("=", 1)[1] if "=" in a else args[i + 1]
            break

    if output_path is None:
        project = gcloud.project or "auto-project"
        bucket = f"dataflow-{project}-{uuid.uuid4().hex[:6]}"
        output_path = f"gs://{bucket}/output/auto"
        print(f"[auto-gcs] No --output supplied; using {output_path}")
    bucket, _ = _parse_gcs_path(output_path)

    # 2) Add --temp_location if missing.
    if not gcloud.temp_location:
        temp = f"gs://{bucket}/temp"
        args += [f"--temp_location={temp}"]
        print(f"[auto-gcs] Injected --temp_location={temp}")

    # 3) If the job is going to Dataflow, add --staging_location too.
    runner = (opts.get_all_options().get("runner") or "").lower()
    if "dataflow" in runner and not gcloud.staging_location:
        staging = f"gs://{bucket}/staging"
        args += [f"--staging_location={staging}"]
        print(f"[auto-gcs] Injected --staging_location={staging}")

    # 4) Make sure the bucket exists.
    _ensure_bucket(bucket, gcloud.project)

    return args
# ---------- end helper ----------