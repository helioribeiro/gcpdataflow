FROM python:3.10-slim

# Install Apache Beam SDK with GCP extras and PyArrow for Parquet support
RUN pip install apache-beam[gcp]==2.56.0 pyarrow==13.0.0

# Copy pipeline code into the image
WORKDIR /app
COPY pipeline.py .

# Set entrypoint to run the Beam pipeline (default to DirectRunner if --runner not given)
ENTRYPOINT ["python", "pipeline.py"]