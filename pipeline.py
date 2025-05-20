import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
import pyarrow

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

with beam.Pipeline(options=options) as p:
    (
        p 
        | "ReadBigQueryTable" >> beam.io.ReadFromBigQuery(table="bigquery-public-data:samples.shakespeare")
        | "FilterCommonWords" >> beam.Filter(lambda row: row['word_count'] > 100)   
        | "WriteToParquet" >> beam.io.WriteToParquet(
            file_path_prefix=output_prefix, 
            schema=parquet_schema, 
            file_name_suffix='.parquet',
            num_shards=1 
        )
    )