import os
import apache_beam as beam
from apache_beam.options.pipeline_options import (
    PipelineOptions,
    SetupOptions,
    GoogleCloudOptions,
)
from apache_beam.io.gcp.bigquery import ReadFromBigQuery
import pyarrow
from auto_gcs_locations import enrich_args_with_gcs_locations

parquet_schema = pyarrow.schema([
    ("word", pyarrow.string()),
    ("word_count", pyarrow.int64()),
    ("corpus", pyarrow.string()),
    ("corpus_date", pyarrow.int64())
])

class UserOptions(PipelineOptions):
    @classmethod
    def _add_argparse_args(cls, parser):
        parser.add_argument("--output", help="GCS path prefix for output Parquet files")

# Parse pipeline options (reads options from sys.argv by default)
options = UserOptions()

output_prefix = options.view_as(UserOptions).output
if output_prefix is None:
    raise ValueError("Please provide an --output GCS path for results (e.g., gs://<BUCKET>/output/shakespeare)")

if __name__ == "__main__":
    import sys
    pipeline_args = enrich_args_with_gcs_locations(sys.argv[1:])
    options = PipelineOptions(pipeline_args)
    options.view_as(SetupOptions).save_main_session = True

    gcp_opts = options.view_as(GoogleCloudOptions)
    if not gcp_opts.project:
        gcp_opts.project = (
            os.getenv("GOOGLE_CLOUD_PROJECT")
            or os.getenv("GCLOUD_PROJECT")
        )
        if not gcp_opts.project:
            raise ValueError(
                "Add  --project=<YOUR_PROJECT_ID>  (or set "
                "$GOOGLE_CLOUD_PROJECT) when you run the container."
            )

    output_prefix = options.view_as(UserOptions).output

    with beam.Pipeline(options=options) as p:
        (
            p
            | "QueryShakespeare" >> beam.io.ReadFromBigQuery(
                query="""
                  SELECT word, word_count, corpus, corpus_date
                  FROM `bigquery-public-data.samples.shakespeare`
                  WHERE word_count > 100
                """,
                use_standard_sql=True,
                method=beam.io.ReadFromBigQuery.Method.DIRECT_READ,
            )
            | "FilterCommonWords" >> beam.Filter(lambda row: row['word_count'] > 100)   
            | "WriteToParquet" >> beam.io.WriteToParquet(
                file_path_prefix=output_prefix, 
                schema=parquet_schema, 
                file_name_suffix='.parquet',
                num_shards=1 
            )
        )