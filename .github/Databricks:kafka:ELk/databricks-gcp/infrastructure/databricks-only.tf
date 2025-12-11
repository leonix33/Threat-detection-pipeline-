# Simple Databricks cluster configuration
# This file only contains Databricks resources that can be deployed to an existing workspace

terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

# Configure the Databricks provider
provider "databricks" {
  host  = var.databricks_host
  token = var.databricks_token
}

# Variables
variable "databricks_host" {
  description = "Databricks workspace URL"
  type        = string
  default     = "https://4302395672529079.9.gcp.databricks.com"
}

variable "databricks_token" {
  description = "Databricks access token"
  type        = string
  sensitive   = true
}

variable "auto_termination_minutes" {
  description = "Auto-terminate idle clusters after minutes"
  type        = number
  default     = 30
}

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
      "maxValue": var.auto_termination_minutes
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
  node_type_id           = "n1-standard-8"
  driver_node_type_id    = "n1-standard-8"
  autotermination_minutes = var.auto_termination_minutes
  
  autoscale {
    min_workers = 2
    max_workers = 10
  }
  
  spark_version = "13.3.x-scala2.12"
  
  spark_conf = {
    "spark.databricks.cluster.profile" = "serverless"
    "spark.databricks.repl.allowedLanguages" = "python,sql,scala"
    "spark.sql.adaptive.enabled" = "true"
    "spark.sql.adaptive.coalescePartitions.enabled" = "true"
    "spark.sql.adaptive.skewJoin.enabled" = "true"
    "spark.sql.adaptive.localShuffleReader.enabled" = "true"
    "spark.databricks.delta.optimizeWrite.enabled" = "true"
    "spark.databricks.delta.autoCompact.enabled" = "true"
    "spark.databricks.io.cache.enabled" = "true"
    "spark.sql.streaming.stateStore.providerClass" = "com.databricks.sql.streaming.state.RocksDBStateStoreProvider"
    "spark.databricks.streaming.statefulOperator.useStrictDistribution" = "true"
  }

  custom_tags = {
    "Environment" = "dev"
    "Team" = "DataEngineering"
    "CostCenter" = "Analytics"
    "Purpose" = "ETL-Processing"
  }

  policy_id = databricks_cluster_policy.cost_control.id
}

# Workspace directories
resource "databricks_directory" "shared_data_engineering" {
  path = "/Shared/DataEngineering"
}

resource "databricks_directory" "shared_pipelines" {
  path = "/Shared/DataEngineering/Pipelines"
}

resource "databricks_directory" "shared_init_scripts" {
  path = "/Shared/init-scripts"
}

# Outputs
output "data_engineering_cluster_id" {
  description = "Data Engineering cluster ID"
  value       = databricks_cluster.data_engineering_cluster.id
}

output "cluster_policy_id" {
  description = "Cost control policy ID"
  value       = databricks_cluster_policy.cost_control.id
}

output "cluster_url" {
  description = "Data Engineering cluster URL"
  value       = databricks_cluster.data_engineering_cluster.url
}