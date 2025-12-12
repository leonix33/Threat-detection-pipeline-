# Kafka Infrastructure for Real-time Data Processing
# This file adds Kafka/Pub-Sub infrastructure to support streaming data processing

# Pub/Sub Topics for Kafka-style messaging
resource "google_pubsub_topic" "raw_events" {
  name = "raw-events-topic"
  
  labels = {
    environment = var.environment
    component   = "kafka"
    team        = "data-engineering"
  }
}

resource "google_pubsub_topic" "processed_events" {
  name = "processed-events-topic"
  
  labels = {
    environment = var.environment
    component   = "kafka"
    team        = "data-engineering"
  }
}

resource "google_pubsub_topic" "alerts" {
  name = "alerts-topic"
  
  labels = {
    environment = var.environment
    component   = "kafka"
    team        = "data-engineering"
  }
}

# Subscriptions for stream processing
resource "google_pubsub_subscription" "raw_events_sub" {
  name  = "raw-events-subscription"
  topic = google_pubsub_topic.raw_events.name

  ack_deadline_seconds = 20
  
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 10
  }
}

resource "google_pubsub_subscription" "processed_events_sub" {
  name  = "processed-events-subscription"  
  topic = google_pubsub_topic.processed_events.name

  ack_deadline_seconds = 20
}

# Dead letter topic for failed messages
resource "google_pubsub_topic" "dead_letter" {
  name = "dead-letter-topic"
  
  labels = {
    environment = var.environment
    component   = "kafka"
    purpose     = "dead-letter"
  }
}

# Service account for Kafka operations
resource "google_service_account" "kafka_service_account" {
  account_id   = "kafka-databricks-sa"
  display_name = "Kafka Databricks Service Account"
  description  = "Service account for Kafka operations in Databricks"
}

# IAM permissions for Pub/Sub
resource "google_project_iam_member" "kafka_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.kafka_service_account.email}"
}

resource "google_project_iam_member" "kafka_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.kafka_service_account.email}"
}

resource "google_project_iam_member" "kafka_pubsub_viewer" {
  project = var.project_id
  role    = "roles/pubsub.viewer"
  member  = "serviceAccount:${google_service_account.kafka_service_account.email}"
}

# Service account key for Databricks authentication
resource "google_service_account_key" "kafka_key" {
  service_account_id = google_service_account.kafka_service_account.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Store service account key in Secret Manager
resource "google_secret_manager_secret" "kafka_credentials" {
  secret_id = "kafka-service-account-key"
  
  labels = {
    environment = var.environment
    component   = "kafka"
  }

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "kafka_credentials_version" {
  secret      = google_secret_manager_secret.kafka_credentials.id
  secret_data = base64decode(google_service_account_key.kafka_key.private_key)
}

# Cloud Storage bucket for Kafka checkpoints and offsets
resource "google_storage_bucket" "kafka_checkpoints" {
  name     = "${var.project_id}-kafka-checkpoints"
  location = var.region
  
  labels = {
    environment = var.environment
    component   = "kafka"
    purpose     = "checkpoints"
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# Output values
output "kafka_topics" {
  description = "Kafka topics for streaming"
  value = {
    raw_events       = google_pubsub_topic.raw_events.name
    processed_events = google_pubsub_topic.processed_events.name
    alerts          = google_pubsub_topic.alerts.name
    dead_letter     = google_pubsub_topic.dead_letter.name
  }
}

output "kafka_service_account_email" {
  description = "Service account email for Kafka operations"
  value = google_service_account.kafka_service_account.email
}

output "kafka_credentials_secret" {
  description = "Secret Manager secret for Kafka credentials"
  value = google_secret_manager_secret.kafka_credentials.secret_id
  sensitive = true
}

output "kafka_checkpoint_bucket" {
  description = "GCS bucket for Kafka checkpoints"
  value = google_storage_bucket.kafka_checkpoints.name
}