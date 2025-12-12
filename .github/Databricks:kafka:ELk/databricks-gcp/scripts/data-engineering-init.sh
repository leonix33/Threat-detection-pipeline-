#!/bin/bash

# Data Engineering Cluster Initialization Script
# This script sets up the cluster environment for optimal ETL processing

echo "Starting Data Engineering cluster initialization..."

# Install additional Python packages for data engineering
/databricks/python/bin/pip install --upgrade pip
/databricks/python/bin/pip install \
    pandas==2.1.3 \
    numpy==1.24.3 \
    pyarrow==14.0.1 \
    delta-spark==2.4.0 \
    pyspark==3.5.0 \
    great-expectations==0.17.23 \
    dbt-core==1.6.9 \
    dbt-spark==1.6.1 \
    sqlalchemy==2.0.23 \
    psycopg2-binary==2.9.9 \
    confluent-kafka==2.3.0 \
    google-cloud-pubsub==2.18.4 \
    google-cloud-storage==2.10.0 \
    google-cloud-bigquery==3.13.0 \
    kafka-python==2.0.2 \
    avro-python3==1.11.3

# Install DBT profiles directory
mkdir -p /home/ubuntu/.dbt
cat << 'EOF' > /home/ubuntu/.dbt/profiles.yml
databricks_analytics:
  target: dev
  outputs:
    dev:
      type: databricks
      catalog: hive_metastore
      schema: analytics_dev
      host: "{{ env_var('DATABRICKS_HOST') }}"
      http_path: "{{ env_var('DATABRICKS_HTTP_PATH') }}"
      token: "{{ env_var('DATABRICKS_TOKEN') }}"
      threads: 4
    prod:
      type: databricks
      catalog: hive_metastore
      schema: analytics_prod
      host: "{{ env_var('DATABRICKS_HOST') }}"
      http_path: "{{ env_var('DATABRICKS_HTTP_PATH') }}"
      token: "{{ env_var('DATABRICKS_TOKEN') }}"
      threads: 8
EOF

# Set up Delta Lake configurations
cat << 'EOF' > /tmp/delta-defaults.conf
spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension
spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog
spark.databricks.delta.retentionDurationCheck.enabled=false
spark.databricks.delta.schema.autoMerge.enabled=true
EOF

# Configure logging for better debugging
mkdir -p /tmp/spark-logs
chmod 777 /tmp/spark-logs

# Set up environment variables for data engineering
cat << 'EOF' > /tmp/data-engineering-env.sh
export PYTHONPATH="/databricks/spark/python:/databricks/spark/python/lib/py4j-0.10.9.7-src.zip:$PYTHONPATH"
export SPARK_HOME="/databricks/spark"
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
export DBT_PROFILES_DIR="/home/ubuntu/.dbt"
export GREAT_EXPECTATIONS_CONFIG_DIR="/tmp/great_expectations"
EOF

# Source the environment variables
source /tmp/data-engineering-env.sh

# Create Great Expectations configuration
mkdir -p /tmp/great_expectations
great_expectations init --dir /tmp/great_expectations --assume-yes

# Create common utility functions directory
mkdir -p /tmp/data-engineering-utils

# Create a utility script for common data engineering tasks
cat << 'EOF' > /tmp/data-engineering-utils/common_utils.py
"""
Common utilities for data engineering tasks
"""

import logging
from pyspark.sql import DataFrame
from pyspark.sql.functions import *
from delta.tables import DeltaTable
import great_expectations as ge

def setup_logging(log_level="INFO"):
    """Set up logging configuration"""
    logging.basicConfig(
        level=getattr(logging, log_level),
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    return logging.getLogger(__name__)

def validate_dataframe(df: DataFrame, expectations_config: dict):
    """Validate DataFrame using Great Expectations"""
    pandas_df = df.toPandas()
    ge_df = ge.from_pandas(pandas_df)
    
    results = []
    for expectation in expectations_config.get('expectations', []):
        result = getattr(ge_df, expectation['method'])(**expectation['kwargs'])
        results.append(result)
    
    return results

def optimize_delta_table(table_path: str, partition_cols: list = None):
    """Optimize Delta table for better query performance"""
    delta_table = DeltaTable.forPath(spark, table_path)
    
    # Run OPTIMIZE command
    if partition_cols:
        delta_table.optimize().where(f"date >= current_date() - interval 30 days").executeCompaction()
    else:
        delta_table.optimize().executeCompaction()
    
    # Run VACUUM to remove old files (retain for 7 days)
    delta_table.vacuum(retentionHours=168)
    
    return "Table optimization completed"

def create_data_quality_check(df: DataFrame, table_name: str):
    """Create comprehensive data quality checks"""
    checks = {
        'row_count': df.count(),
        'column_count': len(df.columns),
        'null_counts': {col: df.filter(F.col(col).isNull()).count() for col in df.columns},
        'duplicate_count': df.count() - df.dropDuplicates().count(),
        'data_types': dict(df.dtypes)
    }
    
    return checks
EOF

# Create ETL framework utilities
cat << 'EOF' > /tmp/data-engineering-utils/etl_framework.py
"""
ETL Framework for Databricks Data Engineering
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from delta.tables import DeltaTable
import logging

class ETLPipeline:
    def __init__(self, spark_session=None):
        self.spark = spark_session or SparkSession.getActiveSession()
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def extract_from_gcs(self, bucket_path: str, file_format: str = "parquet"):
        """Extract data from Google Cloud Storage"""
        self.logger.info(f"Extracting data from {bucket_path}")
        
        if file_format.lower() == "parquet":
            df = self.spark.read.parquet(bucket_path)
        elif file_format.lower() == "csv":
            df = self.spark.read.option("header", "true").option("inferSchema", "true").csv(bucket_path)
        elif file_format.lower() == "json":
            df = self.spark.read.json(bucket_path)
        else:
            raise ValueError(f"Unsupported file format: {file_format}")
        
        return df
    
    def transform_data(self, df, transformations: list):
        """Apply transformations to DataFrame"""
        self.logger.info("Applying data transformations")
        
        for transformation in transformations:
            if transformation['type'] == 'filter':
                df = df.filter(transformation['condition'])
            elif transformation['type'] == 'select':
                df = df.select(*transformation['columns'])
            elif transformation['type'] == 'withColumn':
                df = df.withColumn(transformation['column_name'], transformation['expression'])
            elif transformation['type'] == 'dropDuplicates':
                df = df.dropDuplicates(transformation.get('subset', None))
        
        return df
    
    def load_to_delta(self, df, table_path: str, mode: str = "overwrite", partition_by: list = None):
        """Load data to Delta Lake table"""
        self.logger.info(f"Loading data to Delta table: {table_path}")
        
        writer = df.write.format("delta").mode(mode)
        
        if partition_by:
            writer = writer.partitionBy(*partition_by)
        
        writer.save(table_path)
        
        return f"Data successfully loaded to {table_path}"
    
    def upsert_delta_table(self, df, table_path: str, merge_condition: str, update_set: dict, insert_values: dict):
        """Perform upsert operation on Delta table"""
        self.logger.info(f"Performing upsert on Delta table: {table_path}")
        
        delta_table = DeltaTable.forPath(self.spark, table_path)
        
        delta_table.alias("target").merge(
            df.alias("source"),
            merge_condition
        ).whenMatchedUpdate(set=update_set).whenNotMatchedInsert(values=insert_values).execute()
        
        return "Upsert operation completed successfully"
EOF

# Set permissions for the utility scripts
chmod +x /tmp/data-engineering-utils/*.py

# Add utility scripts to Python path
echo 'export PYTHONPATH="/tmp/data-engineering-utils:$PYTHONPATH"' >> /home/ubuntu/.bashrc

# Configure Spark SQL warehouse connection
cat << 'EOF' > /tmp/warehouse-config.conf
spark.sql.warehouse.dir=/tmp/spark-warehouse
spark.sql.execution.arrow.pyspark.enabled=true
spark.sql.execution.arrow.maxRecordsPerBatch=10000
spark.sql.adaptive.advisory.enabled=true
spark.sql.adaptive.coalescePartitions.parallelismFirst=false
EOF

# Create monitoring and alerting configuration
mkdir -p /tmp/monitoring
cat << 'EOF' > /tmp/monitoring/cluster-metrics.py
"""
Cluster monitoring utilities
"""

import psutil
import json
from datetime import datetime

def get_cluster_metrics():
    """Get current cluster performance metrics"""
    metrics = {
        'timestamp': datetime.now().isoformat(),
        'cpu_percent': psutil.cpu_percent(interval=1),
        'memory_percent': psutil.virtual_memory().percent,
        'disk_usage': psutil.disk_usage('/').percent,
        'network_io': psutil.net_io_counters()._asdict(),
        'process_count': len(psutil.pids())
    }
    return metrics

def log_cluster_metrics():
    """Log cluster metrics to file"""
    metrics = get_cluster_metrics()
    with open('/tmp/spark-logs/cluster-metrics.json', 'a') as f:
        f.write(json.dumps(metrics) + '\n')

# Schedule metrics collection every 5 minutes
# This would typically be done via cron or cluster scheduler
EOF

echo "Data Engineering cluster initialization completed successfully!"
echo "Available utilities:"
echo "- Common data engineering functions: /tmp/data-engineering-utils/common_utils.py"
echo "- ETL framework: /tmp/data-engineering-utils/etl_framework.py"
echo "- DBT profiles: /home/ubuntu/.dbt/profiles.yml"
echo "- Great Expectations config: /tmp/great_expectations/"
echo "- Cluster monitoring: /tmp/monitoring/cluster-metrics.py"
echo "- Spark logs: /tmp/spark-logs/"