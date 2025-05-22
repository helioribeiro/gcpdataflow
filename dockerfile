FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY pipeline.py .
COPY auto_gcs_locations.py .

ENTRYPOINT ["python", "pipeline.py"]