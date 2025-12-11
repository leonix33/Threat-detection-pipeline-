# Service account for Databricks
resource "google_service_account" "databricks_sa" {
  account_id   = "databricks-sa-${local.name_suffix}"
  display_name = "Databricks Service Account"
  description  = "Service account for Databricks workspace operations"
}

# IAM roles for Databricks service account
resource "google_project_iam_member" "databricks_compute_admin" {
  project = var.project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.databricks_sa.email}"
}

resource "google_project_iam_member" "databricks_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.databricks_sa.email}"
}

resource "google_project_iam_member" "databricks_bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.databricks_sa.email}"
}

# Databricks workspace will be created manually or via GCP console
# The clusters and resources below will be applied to the existing workspace

# Databricks cluster policy for cost control
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
    },
    "preemptible": {
      "type": "fixed",
      "value": var.enable_preemptible_instances
    }
  })
}

# Databricks cluster for general analytics
resource "databricks_cluster" "analytics_cluster" {
  cluster_name            = "Analytics Cluster"
  node_type_id           = var.cluster_node_type
  driver_node_type_id    = var.cluster_node_type
  autotermination_minutes = var.auto_termination_minutes
  
  autoscale {
    min_workers = var.cluster_min_workers
    max_workers = var.cluster_max_workers
  }
  
  spark_version = "13.3.x-scala2.12"
  
  spark_conf = {
    "spark.databricks.cluster.profile" = "serverless"
    "spark.databricks.repl.allowedLanguages" = "python,sql,scala,r"
    "spark.sql.adaptive.enabled" = "true"
    "spark.sql.adaptive.coalescePartitions.enabled" = "true"
  }

  policy_id = databricks_cluster_policy.cost_control.id
}

# Databricks cluster for ML workloads
resource "databricks_cluster" "ml_cluster" {
  cluster_name            = "ML Cluster"
  node_type_id           = "n1-highmem-4"
  driver_node_type_id    = "n1-highmem-4"
  autotermination_minutes = var.auto_termination_minutes
  
  autoscale {
    min_workers = 1
    max_workers = 4
  }
  
  spark_version = "13.3.x-cpu-ml-scala2.12"
  
  spark_conf = {
    "spark.databricks.cluster.profile" = "serverless"
    "spark.sql.adaptive.enabled" = "true"
    "spark.databricks.delta.preview.enabled" = "true"
  }

  policy_id = databricks_cluster_policy.cost_control.id
}

# Databricks cluster for Data Engineering workloads
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

  init_scripts {
    workspace {
      destination = "/Shared/init-scripts/data-engineering-init.sh"
    }
  }

  custom_tags = {
    "Environment" = var.environment
    "Team" = "DataEngineering"
    "CostCenter" = "Analytics"
    "Purpose" = "ETL-Processing"
  }

  policy_id = databricks_cluster_policy.cost_control.id

}

# Databricks SQL warehouse
resource "databricks_sql_endpoint" "analytics_warehouse" {
  name             = "Analytics Warehouse"
  cluster_size     = "Small"
  auto_stop_mins   = 30
  max_num_clusters = 1

  tags {
    custom_tags {
      key   = "Environment"
      value = var.environment
    }
  }
}

# Create workspace folders
resource "databricks_directory" "shared_analytics" {
  path = "/Shared/Analytics"
}

resource "databricks_directory" "shared_ml" {
  path = "/Shared/ML"

}

resource "databricks_directory" "shared_pipelines" {
  path = "/Shared/Pipelines"

}

# Secret scope for storing credentials
resource "databricks_secret_scope" "main" {
  name = "main-secrets"
}

# Store GCS credentials in secret scope
resource "databricks_secret" "gcs_credentials" {
  key          = "gcs-service-account"
  string_value = google_service_account.databricks_sa.email
  scope        = databricks_secret_scope.main.name

  depends_on = [databricks_secret_scope.main]
}

# Store database connection details
resource "databricks_secret" "db_password" {
  key          = "hive-metastore-password"
  string_value = random_password.hive_password.result
  scope        = databricks_secret_scope.main.name

  depends_on = [databricks_secret_scope.main]
}