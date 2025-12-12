# Databricks notebook source
# MAGIC %md
# MAGIC # Kafka Streaming Pipeline - Real-time Data Processing
# MAGIC 
# MAGIC This notebook demonstrates real-time data processing using Kafka (via Google Pub/Sub) with Databricks.
# MAGIC 
# MAGIC ## Features:
# MAGIC - Real-time data ingestion from Kafka topics
# MAGIC - Stream processing with Apache Spark Structured Streaming
# MAGIC - Integration with Google Cloud Pub/Sub
# MAGIC - Delta Lake for streaming data storage
# MAGIC - Real-time analytics and monitoring

# COMMAND ----------

# MAGIC %md
# MAGIC ## Setup and Configuration

# COMMAND ----------

# Import required libraries
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from delta.tables import DeltaTable
import json
import logging
from google.cloud import pubsub_v1
from google.auth import exceptions
import base64

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

print("Kafka Streaming Pipeline - Real-time Data Processing")
print("=" * 60)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Configuration Parameters

# COMMAND ----------

# Kafka/Pub Sub Configuration
PROJECT_ID = "your-gcp-project-id"  # Replace with actual project ID
SUBSCRIPTION_NAME = "raw-events-subscription"
TOPIC_NAME = "raw-events-topic"

# Delta Lake paths
BRONZE_PATH = "/mnt/delta/bronze/kafka_raw"
SILVER_PATH = "/mnt/delta/silver/kafka_processed"
GOLD_PATH = "/mnt/delta/gold/kafka_aggregated"
CHECKPOINT_PATH = "/mnt/delta/checkpoints/kafka_streaming"

# Schema definition for incoming data
event_schema = StructType([
    StructField("timestamp", TimestampType(), True),
    StructField("event_type", StringType(), True),
    StructField("user_id", StringType(), True),
    StructField("session_id", StringType(), True),
    StructField("payload", StringType(), True),
    StructField("source_system", StringType(), True)
])

print(f"Configuration loaded for project: {PROJECT_ID}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Kafka Stream Reader Setup

# COMMAND ----------

def create_kafka_stream():
    """
    Create streaming DataFrame from Kafka (Pub/Sub) source
    """
    logger.info("Setting up Kafka streaming source")
    
    # For demonstration, using rate source with Kafka-like structure
    # In production, replace with actual Kafka connector
    kafka_stream = spark.readStream \
        .format("rate") \
        .option("rowsPerSecond", 10) \
        .option("rampUpTime", "10s") \
        .load()
    
    # Transform rate source to simulate Kafka messages
    kafka_messages = kafka_stream.select(
        current_timestamp().alias("timestamp"),
        lit("user_action").alias("event_type"),
        concat(lit("user_"), col("value") % 1000).alias("user_id"),
        concat(lit("session_"), col("value") % 100).alias("session_id"),
        to_json(struct(
            col("value").alias("action_id"),
            (rand() * 100).cast("int").alias("score"),
            when(col("value") % 2 == 0, "mobile").otherwise("web").alias("platform")
        )).alias("payload"),
        lit("web_app").alias("source_system")
    )
    
    return kafka_messages

# Create the stream
kafka_stream = create_kafka_stream()
print("Kafka stream created successfully")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Processing Pipeline

# COMMAND ----------

def process_kafka_stream(stream_df):
    """
    Process the incoming Kafka stream with transformations
    """
    logger.info("Processing Kafka stream data")
    
    # Parse JSON payload and add derived fields
    processed_stream = stream_df \
        .withColumn("parsed_payload", from_json(col("payload"), MapType(StringType(), StringType()))) \
        .withColumn("action_id", col("parsed_payload.action_id").cast("int")) \
        .withColumn("score", col("parsed_payload.score").cast("int")) \
        .withColumn("platform", col("parsed_payload.platform")) \
        .withColumn("processing_time", current_timestamp()) \
        .withColumn("date", to_date(col("timestamp"))) \
        .withColumn("hour", hour(col("timestamp"))) \
        .drop("parsed_payload")
    
    # Add data quality checks
    quality_stream = processed_stream \
        .withColumn("is_valid", 
            (col("user_id").isNotNull()) & 
            (col("event_type").isNotNull()) & 
            (col("score") >= 0)
        ) \
        .withColumn("data_quality_score", 
            when(col("is_valid"), 1.0).otherwise(0.0)
        )
    
    return quality_stream

# Process the stream
processed_kafka_stream = process_kafka_stream(kafka_stream)
print("Stream processing pipeline configured")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Bronze Layer - Raw Data Storage

# COMMAND ----------

def write_to_bronze_layer(stream_df):
    """
    Write raw streaming data to Bronze Delta table
    """
    logger.info("Writing to Bronze layer")
    
    bronze_query = stream_df.writeStream \
        .format("delta") \
        .outputMode("append") \
        .option("checkpointLocation", f"{CHECKPOINT_PATH}/bronze") \
        .option("mergeSchema", "true") \
        .trigger(processingTime="30 seconds") \
        .start(BRONZE_PATH)
    
    return bronze_query

# Start Bronze layer streaming
bronze_query = write_to_bronze_layer(processed_kafka_stream)
print("Bronze layer streaming started")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Silver Layer - Cleaned and Enriched Data

# COMMAND ----------

def create_silver_stream():
    """
    Read from Bronze layer and create Silver layer with enrichments
    """
    logger.info("Creating Silver layer stream")
    
    # Read from Bronze Delta table
    bronze_stream = spark.readStream \
        .format("delta") \
        .load(BRONZE_PATH)
    
    # Apply business logic and enrichments
    silver_stream = bronze_stream \
        .filter(col("is_valid") == True) \
        .withColumn("user_segment", 
            when(col("score") >= 80, "high_value")
            .when(col("score") >= 50, "medium_value")
            .otherwise("low_value")
        ) \
        .withColumn("engagement_score", 
            col("score") * 
            when(col("platform") == "mobile", 1.2).otherwise(1.0)
        ) \
        .withColumn("risk_level",
            when(col("score") < 20, "high")
            .when(col("score") < 60, "medium")
            .otherwise("low")
        )
    
    return silver_stream

def write_to_silver_layer(stream_df):
    """
    Write enriched data to Silver Delta table
    """
    logger.info("Writing to Silver layer")
    
    silver_query = stream_df.writeStream \
        .format("delta") \
        .outputMode("append") \
        .option("checkpointLocation", f"{CHECKPOINT_PATH}/silver") \
        .trigger(processingTime="1 minute") \
        .start(SILVER_PATH)
    
    return silver_query

# Create and start Silver layer
silver_stream = create_silver_stream()
silver_query = write_to_silver_layer(silver_stream)
print("Silver layer streaming started")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Gold Layer - Aggregated Analytics

# COMMAND ----------

def create_gold_aggregations():
    """
    Create real-time aggregations for Gold layer
    """
    logger.info("Creating Gold layer aggregations")
    
    # Read from Silver layer
    silver_stream = spark.readStream \
        .format("delta") \
        .load(SILVER_PATH)
    
    # Create windowed aggregations
    gold_aggregations = silver_stream \
        .withWatermark("timestamp", "10 minutes") \
        .groupBy(
            window(col("timestamp"), "5 minutes", "1 minute"),
            col("platform"),
            col("user_segment")
        ) \
        .agg(
            count("*").alias("event_count"),
            avg("score").alias("avg_score"),
            avg("engagement_score").alias("avg_engagement"),
            countDistinct("user_id").alias("unique_users"),
            sum(when(col("risk_level") == "high", 1).otherwise(0)).alias("high_risk_events")
        ) \
        .select(
            col("window.start").alias("window_start"),
            col("window.end").alias("window_end"),
            col("platform"),
            col("user_segment"),
            col("event_count"),
            col("avg_score"),
            col("avg_engagement"),
            col("unique_users"),
            col("high_risk_events"),
            current_timestamp().alias("calculation_time")
        )
    
    return gold_aggregations

def write_to_gold_layer(stream_df):
    """
    Write aggregated data to Gold Delta table
    """
    logger.info("Writing to Gold layer")
    
    gold_query = stream_df.writeStream \
        .format("delta") \
        .outputMode("update") \
        .option("checkpointLocation", f"{CHECKPOINT_PATH}/gold") \
        .trigger(processingTime="2 minutes") \
        .start(GOLD_PATH)
    
    return gold_query

# Create and start Gold layer
gold_stream = create_gold_aggregations()
gold_query = write_to_gold_layer(gold_stream)
print("Gold layer streaming started")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Real-time Monitoring and Alerting

# COMMAND ----------

def setup_stream_monitoring():
    """
    Monitor stream health and performance
    """
    logger.info("Setting up stream monitoring")
    
    # Monitor streaming query progress
    def monitor_progress(query, query_name):
        progress = query.lastProgress
        if progress:
            print(f"\n{query_name} Progress:")
            print(f"  Batch ID: {progress.get('batchId', 'N/A')}")
            print(f"  Input Rows: {progress.get('inputRowsPerSecond', 0):.2f}/sec")
            print(f"  Processing Rate: {progress.get('processingTime', 'N/A')}")
            
            # Check for anomalies
            if progress.get('inputRowsPerSecond', 0) < 1:
                print(f"  ⚠️  Low input rate detected for {query_name}")
    
    return monitor_progress

# Set up monitoring
monitor = setup_stream_monitoring()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Stream Status and Control

# COMMAND ----------

# Check status of all running streams
def check_stream_status():
    """
    Check the status of all running streaming queries
    """
    active_streams = spark.streams.active
    
    print(f"Active Streaming Queries: {len(active_streams)}")
    print("=" * 50)
    
    for i, stream in enumerate(active_streams):
        print(f"Stream {i+1}:")
        print(f"  ID: {stream.id}")
        print(f"  Name: {stream.name}")
        print(f"  Status: {stream.isActive}")
        print(f"  Exception: {stream.exception()}")
        print(f"  Recent Progress: {stream.lastProgress}")
        print("-" * 30)

# Check current status
check_stream_status()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Kafka Producer Example (For Testing)

# COMMAND ----------

def create_test_kafka_producer():
    """
    Create test data producer to simulate Kafka messages
    This would typically be an external system producing to Kafka
    """
    import json
    import time
    from datetime import datetime
    
    def generate_test_event(user_id, session_id):
        return {
            "timestamp": datetime.now().isoformat(),
            "event_type": "user_action",
            "user_id": f"user_{user_id}",
            "session_id": f"session_{session_id}",
            "payload": json.dumps({
                "action": "click",
                "page": "/dashboard",
                "duration": 1200,
                "score": user_id % 100
            }),
            "source_system": "web_app"
        }
    
    # In production, this would publish to actual Kafka/Pub Sub
    print("Test event structure:")
    test_event = generate_test_event(123, 456)
    print(json.dumps(test_event, indent=2))

create_test_kafka_producer()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Performance Optimization

# COMMAND ----------

# Optimize Delta tables for better streaming performance
def optimize_delta_tables():
    """
    Optimize Delta tables for streaming workloads
    """
    logger.info("Optimizing Delta tables")
    
    # Optimize Bronze table
    spark.sql(f"OPTIMIZE delta.`{BRONZE_PATH}` ZORDER BY (timestamp, user_id)")
    
    # Optimize Silver table  
    spark.sql(f"OPTIMIZE delta.`{SILVER_PATH}` ZORDER BY (timestamp, user_segment)")
    
    # Optimize Gold table
    spark.sql(f"OPTIMIZE delta.`{GOLD_PATH}` ZORDER BY (window_start, platform)")
    
    print("Delta table optimization completed")

# Uncomment to run optimization
# optimize_delta_tables()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Stream Cleanup and Management

# COMMAND ----------

def stop_all_streams():
    """
    Stop all running streaming queries
    """
    logger.info("Stopping all streaming queries")
    
    for stream in spark.streams.active:
        stream.stop()
        print(f"Stopped stream: {stream.id}")
    
    print("All streams stopped")

def restart_streams():
    """
    Restart streaming pipeline
    """
    logger.info("Restarting streaming pipeline")
    
    # Stop existing streams
    stop_all_streams()
    
    # Wait for cleanup
    time.sleep(5)
    
    # Restart the pipeline
    print("Restarting Kafka streaming pipeline...")
    # Would call the main streaming functions here
    
# Uncomment to stop streams when needed
# stop_all_streams()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Results and Next Steps
# MAGIC 
# MAGIC ### Current Implementation:
# MAGIC - ✅ Multi-layer streaming architecture (Bronze/Silver/Gold)
# MAGIC - ✅ Real-time data processing with Apache Spark
# MAGIC - ✅ Data quality validation and monitoring
# MAGIC - ✅ Windowed aggregations for analytics
# MAGIC - ✅ Delta Lake integration for ACID transactions
# MAGIC 
# MAGIC ### Production Enhancements:
# MAGIC - Replace rate source with actual Kafka connector
# MAGIC - Implement schema evolution handling
# MAGIC - Add comprehensive error handling and retry logic
# MAGIC - Set up alerting for anomaly detection
# MAGIC - Configure auto-scaling based on throughput
# MAGIC 
# MAGIC ### Monitoring Dashboard:
# MAGIC Check the streaming UI for real-time metrics and performance monitoring.

print("\nKafka Streaming Pipeline deployment completed!")
print("Check Databricks Streaming UI for real-time monitoring")
print("=" * 60)