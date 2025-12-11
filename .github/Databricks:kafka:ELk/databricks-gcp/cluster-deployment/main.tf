# Simple Databricks cluster deployment
terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

provider "databricks" {}

# Cost control cluster policy
resource "databricks_cluster_policy" "cost_control" {
  name = "Cost Control Policy"
  
  definition = jsonencode({
    "node_type_id": {
      "type": "allowlist",
      "values": ["n1-standard-4", "n1-standard-8", "n1-highmem-2", "n1-highmem-4", "n1-highmem-8"]
    },
    "autotermination_minutes": {
      "type": "range",
      "maxValue": 30
    },
    "enable_elastic_disk": {
      "type": "fixed",
      "value": true
    }
  })
}

# Data Engineering cluster
resource "databricks_cluster" "data_engineering_cluster" {
  cluster_name            = "Data Engineering Cluster"
  node_type_id           = "n1-standard-4"  # Using smaller instance to start
  driver_node_type_id    = "n1-standard-4"
  autotermination_minutes = 30
  num_workers            = 2  # Fixed number instead of autoscale
  
  spark_version = "13.3.x-scala2.12"
  
  spark_conf = {
    "spark.databricks.cluster.profile" = "serverless"
    "spark.databricks.repl.allowedLanguages" = "python,sql,scala"
    "spark.sql.adaptive.enabled" = "true"
    "spark.sql.adaptive.coalescePartitions.enabled" = "true"
    "spark.databricks.delta.optimizeWrite.enabled" = "true"
    "spark.databricks.delta.autoCompact.enabled" = "true"
  }

  custom_tags = {
    "Environment" = "dev"
    "Team" = "DataEngineering" 
    "Purpose" = "ETL-Processing"
  }

  policy_id = databricks_cluster_policy.cost_control.id
}

# Workspace directories
resource "databricks_directory" "data_engineering" {
  path = "/Shared/DataEngineering"
}

resource "databricks_directory" "pipelines" {
  path = "/Shared/DataEngineering/Pipelines"
}

# Outputs
output "cluster_id" {
  value = databricks_cluster.data_engineering_cluster.id
}

output "cluster_url" {
  value = databricks_cluster.data_engineering_cluster.url
}