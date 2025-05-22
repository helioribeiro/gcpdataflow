# ─────────────────────────────────────────────────────────────
# Base image
FROM python:3.10-slim

# Put the application in /app
WORKDIR /app

# 1. Copy only the dependency list first so that
#    Docker can cache the pip layer when your code changes.
COPY requirements.txt .

# 2. Install all Python dependencies in one go
RUN pip install --no-cache-dir -r requirements.txt

# 3. Copy the application code
COPY pipeline.py .
COPY auto_gcs_locations.py .

# 4. Default command – will use DirectRunner unless --runner is provided
ENTRYPOINT ["python", "pipeline.py"]