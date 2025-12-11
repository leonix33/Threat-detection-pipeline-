# Databricks notebook source
# MAGIC %md
# MAGIC # Data Engineering Pipeline - ETL Processing
# MAGIC 
# MAGIC This notebook demonstrates a complete data engineering pipeline using the data engineering cluster.
# MAGIC 
# MAGIC ## Features:
# MAGIC - Extract data from Google Cloud Storage
# MAGIC - Transform data using Spark SQL and PySpark
# MAGIC - Load data into Delta Lake tables
# MAGIC - Data quality validation
# MAGIC - Performance optimization

# COMMAND ----------

# MAGIC %md
# MAGIC ## Setup and Configuration

# COMMAND ----------

# Import required libraries
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from delta.tables import DeltaTable
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
data_lake_bucket = "gs://your-data-lake-bucket"
bronze_table_path = "/mnt/delta/bronze/raw_data"
silver_table_path = "/mnt/delta/silver/cleaned_data" 
gold_table_path = "/mnt/delta/gold/aggregated_data"

print("Data Engineering Pipeline - ETL Processing")
print("=" * 50)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Extract - Data Ingestion from GCS

# COMMAND ----------

# Extract data from Google Cloud Storage
def extract_data_from_gcs(source_path: str, file_format: str = "parquet"):
    """
    Extract data from Google Cloud Storage
    """
    logger.info(f"Extracting data from {source_path}")
    
    try:
        if file_format.lower() == "parquet":
            df = spark.read.parquet(source_path)
        elif file_format.lower() == "csv":
            df = spark.read.option("header", "true").option("inferSchema", "true").csv(source_path)
        elif file_format.lower() == "json":
            df = spark.read.json(source_path)
        else:
            raise ValueError(f"Unsupported file format: {file_format}")
        
        logger.info(f"Successfully extracted {df.count()} records")
        return df
    except Exception as e:
        logger.error(f"Error extracting data: {str(e)}")
        raise

# Example: Extract sample data (replace with your actual data source)
sample_data = [
    (1, "John Doe", "john@email.com", "2024-01-01", "active"),
    (2, "Jane Smith", "jane@email.com", "2024-01-02", "inactive"),
    (3, "Bob Johnson", "bob@email.com", "2024-01-03", "active"),
    (4, "Alice Brown", "alice@email.com", "2024-01-04", "active")
]

schema = StructType([
    StructField("id", IntegerType(), True),
    StructField("name", StringType(), True),
    StructField("email", StringType(), True),
    StructField("created_date", StringType(), True),
    StructField("status", StringType(), True)
])

raw_df = spark.createDataFrame(sample_data, schema)
raw_df.show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Transform - Data Cleaning and Processing

# COMMAND ----------

def clean_and_transform_data(df):
    """
    Apply data cleaning and transformations
    """
    logger.info("Starting data transformation")
    
    # Add processing timestamp
    df_with_timestamp = df.withColumn("processing_timestamp", current_timestamp())
    
    # Convert date string to proper date type
    df_with_date = df_with_timestamp.withColumn(
        "created_date", 
        to_date(col("created_date"), "yyyy-MM-dd")
    )
    
    # Add derived columns
    df_transformed = df_with_date.withColumn(
        "email_domain", 
        split(col("email"), "@").getItem(1)
    ).withColumn(
        "days_since_created",
        datediff(current_date(), col("created_date"))
    ).withColumn(
        "is_active",
        when(col("status") == "active", True).otherwise(False)
    )
    
    # Data quality checks
    df_cleaned = df_transformed.filter(
        col("email").isNotNull() & 
        col("email").contains("@") &
        col("name").isNotNull()
    )
    
    logger.info(f"Transformation completed. Records after cleaning: {df_cleaned.count()}")
    return df_cleaned

# Apply transformations
cleaned_df = clean_and_transform_data(raw_df)
cleaned_df.show()
cleaned_df.printSchema()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Load - Write to Delta Lake Tables

# COMMAND ----------

def load_to_delta_bronze(df, table_path: str):
    """
    Load raw data to Bronze layer (append mode)
    """
    logger.info(f"Loading data to Bronze layer: {table_path}")
    
    df.write \
      .format("delta") \
      .mode("append") \
      .option("mergeSchema", "true") \
      .save(table_path)
    
    logger.info("Bronze layer load completed")

def load_to_delta_silver(df, table_path: str):
    """
    Load cleaned data to Silver layer (overwrite mode)
    """
    logger.info(f"Loading data to Silver layer: {table_path}")
    
    df.write \
      .format("delta") \
      .mode("overwrite") \
      .option("overwriteSchema", "true") \
      .save(table_path)
    
    logger.info("Silver layer load completed")

def create_gold_aggregations(silver_path: str, gold_path: str):
    """
    Create aggregated data for Gold layer
    """
    logger.info("Creating Gold layer aggregations")
    
    silver_df = spark.read.format("delta").load(silver_path)
    
    # Create aggregations
    aggregated_df = silver_df.groupBy("email_domain", "status") \
        .agg(
            count("*").alias("user_count"),
            avg("days_since_created").alias("avg_days_since_created"),
            max("created_date").alias("latest_created_date"),
            min("created_date").alias("earliest_created_date")
        ).withColumn("aggregation_timestamp", current_timestamp())
    
    aggregated_df.write \
        .format("delta") \
        .mode("overwrite") \
        .save(gold_path)
    
    logger.info("Gold layer aggregations completed")
    return aggregated_df

# Load data to different layers
load_to_delta_bronze(raw_df, bronze_table_path)
load_to_delta_silver(cleaned_df, silver_table_path)
gold_df = create_gold_aggregations(silver_table_path, gold_table_path)

gold_df.show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Quality Validation

# COMMAND ----------

def perform_data_quality_checks(table_path: str, table_name: str):
    """
    Perform comprehensive data quality checks
    """
    logger.info(f"Performing data quality checks for {table_name}")
    
    df = spark.read.format("delta").load(table_path)
    
    quality_results = {
        "table_name": table_name,
        "total_records": df.count(),
        "total_columns": len(df.columns),
        "null_counts": {},
        "duplicate_count": df.count() - df.dropDuplicates().count(),
        "data_types": dict(df.dtypes)
    }
    
    # Check null counts for each column
    for column in df.columns:
        null_count = df.filter(col(column).isNull()).count()
        quality_results["null_counts"][column] = null_count
    
    return quality_results

# Run data quality checks
bronze_quality = perform_data_quality_checks(bronze_table_path, "bronze")
silver_quality = perform_data_quality_checks(silver_table_path, "silver")
gold_quality = perform_data_quality_checks(gold_table_path, "gold")

print("Data Quality Report:")
print("=" * 30)
for layer, results in [("Bronze", bronze_quality), ("Silver", silver_quality), ("Gold", gold_quality)]:
    print(f"{layer} Layer:")
    print(f"  Records: {results['total_records']}")
    print(f"  Columns: {results['total_columns']}")
    print(f"  Duplicates: {results['duplicate_count']}")
    print()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Delta Lake Optimization

# COMMAND ----------

def optimize_delta_tables():
    """
    Optimize Delta tables for better query performance
    """
    tables_to_optimize = [
        (bronze_table_path, "bronze"),
        (silver_table_path, "silver"),
        (gold_table_path, "gold")
    ]
    
    for table_path, table_name in tables_to_optimize:
        logger.info(f"Optimizing {table_name} table")
        
        try:
            # Run OPTIMIZE command
            spark.sql(f"OPTIMIZE delta.`{table_path}`")
            
            # Run VACUUM to remove old files (retain for 7 days)
            spark.sql(f"VACUUM delta.`{table_path}` RETAIN 168 HOURS")
            
            logger.info(f"{table_name} table optimization completed")
        except Exception as e:
            logger.error(f"Error optimizing {table_name}: {str(e)}")

# Optimize all Delta tables
optimize_delta_tables()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Streaming Data Processing Example

# COMMAND ----------

def create_streaming_pipeline():
    """
    Example of streaming data processing
    """
    logger.info("Setting up streaming pipeline")
    
    # Create a streaming DataFrame (example with rate source)
    streaming_df = spark.readStream \
        .format("rate") \
        .option("rowsPerSecond", 10) \
        .load()
    
    # Transform streaming data
    processed_stream = streaming_df \
        .withColumn("processing_time", current_timestamp()) \
        .withColumn("value_doubled", col("value") * 2) \
        .withColumn("partition_date", date_format(current_timestamp(), "yyyy-MM-dd"))
    
    # Write to Delta Lake with checkpointing
    stream_query = processed_stream.writeStream \
        .format("delta") \
        .outputMode("append") \
        .option("checkpointLocation", "/tmp/checkpoint/streaming") \
        .trigger(processingTime="10 seconds") \
        .start("/mnt/delta/streaming/processed_data")
    
    return stream_query

# Uncomment to run streaming pipeline
# streaming_query = create_streaming_pipeline()
# print("Streaming pipeline started. Check /mnt/delta/streaming/processed_data for output")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Performance Monitoring

# COMMAND ----------

def get_performance_metrics():
    """
    Get cluster and query performance metrics
    """
    logger.info("Collecting performance metrics")
    
    # Spark metrics
    spark_metrics = {
        "active_sessions": len(spark.sparkContext.statusTracker().getExecutorInfos()),
        "total_cores": spark.sparkContext.defaultParallelism,
        "spark_version": spark.version
    }
    
    # Query execution metrics (example)
    query_metrics = {
        "last_query_duration": "N/A",  # Would be captured from actual queries
        "rows_processed": "N/A",
        "data_processed_mb": "N/A"
    }
    
    return {
        "spark_metrics": spark_metrics,
        "query_metrics": query_metrics,
        "timestamp": current_timestamp()
    }

metrics = get_performance_metrics()
print("Performance Metrics:")
print("=" * 25)
for category, values in metrics.items():
    if isinstance(values, dict):
        print(f"{category}:")
        for key, value in values.items():
            print(f"  {key}: {value}")
    else:
        print(f"{category}: {values}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Pipeline Summary and Next Steps
# MAGIC 
# MAGIC This data engineering pipeline demonstrates:
# MAGIC 
# MAGIC 1. **Data Extraction** from Google Cloud Storage
# MAGIC 2. **Data Transformation** with cleaning and validation
# MAGIC 3. **Data Loading** into Bronze, Silver, and Gold Delta Lake layers
# MAGIC 4. **Data Quality** validation and monitoring
# MAGIC 5. **Delta Lake Optimization** for performance
# MAGIC 6. **Streaming Processing** capabilities
# MAGIC 7. **Performance Monitoring** and metrics collection
# MAGIC 
# MAGIC ### Recommended Next Steps:
# MAGIC - Set up automated job scheduling using Databricks Jobs
# MAGIC - Implement comprehensive data lineage tracking
# MAGIC - Add alerting for data quality failures
# MAGIC - Set up monitoring dashboards
# MAGIC - Implement data governance policies

# COMMAND ----------

print("Data Engineering Pipeline Completed Successfully!")
print("=" * 50)
print("All layers created and optimized:")
print(f"- Bronze: {bronze_table_path}")
print(f"- Silver: {silver_table_path}")
print(f"- Gold: {gold_table_path}")
print("Ready for production workloads!")