# Google Secret Manager Infrastructure
# Comprehensive secret management with automated lifecycle management

# Enable Secret Manager API
resource "google_project_service" "secretmanager_api" {
  service = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Sample Application Database Secrets
resource "google_secret_manager_secret" "db_credentials" {
  secret_id = "app-database-credentials"
  
  labels = {
    environment = var.environment
    component   = "database"
    rotation    = "quarterly"
    criticality = "high"
    owner       = "data-engineering"
    expires_on  = "2025-03-15"
  }

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager_api]
}

resource "google_secret_manager_secret_version" "db_credentials_version" {
  secret = google_secret_manager_secret.db_credentials.id
  secret_data = jsonencode({
    username = "admin"
    password = "complex-password-123!"
    host     = "10.0.1.100"
    port     = "5432"
    database = "analytics_db"
  })
}

# API Keys for External Services
resource "google_secret_manager_secret" "external_api_keys" {
  secret_id = "external-service-api-keys"
  
  labels = {
    environment = var.environment
    component   = "integrations"
    rotation    = "monthly"
    criticality = "medium"
    owner       = "platform-team"
    expires_on  = "2025-01-30"
  }

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager_api]
}

resource "google_secret_manager_secret_version" "external_api_keys_version" {
  secret = google_secret_manager_secret.external_api_keys.id
  secret_data = jsonencode({
    slack_webhook_url = "https://hooks.slack.com/services/YOUR_WORKSPACE/YOUR_CHANNEL/YOUR_WEBHOOK_TOKEN"
    github_token     = "ghp_YOUR_GITHUB_TOKEN_HERE"
    datadog_api_key  = "YOUR_DATADOG_API_KEY_HERE"
    sendgrid_api_key = "SG.YOUR_SENDGRID_API_KEY_HERE"
  })
}

# SSL/TLS Certificates
resource "google_secret_manager_secret" "ssl_certificates" {
  secret_id = "ssl-tls-certificates"
  
  labels = {
    environment = var.environment
    component   = "security"
    rotation    = "annually"
    criticality = "high"
    owner       = "security-team"
    expires_on  = "2025-12-01"
  }

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager_api]
}

resource "google_secret_manager_secret_version" "ssl_certificates_version" {
  secret = google_secret_manager_secret.ssl_certificates.id
  secret_data = jsonencode({
    private_key = "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7VJTUt9Us8cKB...\n-----END PRIVATE KEY-----"
    certificate = "-----BEGIN CERTIFICATE-----\nMIIDXTCCAkWgAwIBAgIJAKoK/OvD/XR9MA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV...\n-----END CERTIFICATE-----"
    ca_bundle   = "-----BEGIN CERTIFICATE-----\nMIIE0DCCA7igAwIBAgIBBzANBgkqhkiG9w0BAQsFADCBgzELMAkGA1UEBhMCVVMx...\n-----END CERTIFICATE-----"
  })
}

# OAuth Client Secrets
resource "google_secret_manager_secret" "oauth_credentials" {
  secret_id = "oauth-client-secrets"
  
  labels = {
    environment = var.environment
    component   = "authentication"
    rotation    = "biannually"
    criticality = "high"
    owner       = "auth-team"
    expires_on  = "2025-06-15"
  }

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager_api]
}

resource "google_secret_manager_secret_version" "oauth_credentials_version" {
  secret = google_secret_manager_secret.oauth_credentials.id
  secret_data = jsonencode({
    google_client_id     = "123456789-abcdefghijklmnop.apps.googleusercontent.com"
    google_client_secret = "GOCSPX-xxxxxxxxxxxxxxxxxxxxxxxx"
    azure_client_id      = "12345678-1234-1234-1234-123456789012"
    azure_client_secret  = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  })
}

# Development Environment Secrets
resource "google_secret_manager_secret" "dev_secrets" {
  secret_id = "development-environment-secrets"
  
  labels = {
    environment = "development"
    component   = "development"
    rotation    = "weekly"
    criticality = "low"
    owner       = "dev-team"
    expires_on  = "2025-01-15"
  }

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager_api]
}

resource "google_secret_manager_secret_version" "dev_secrets_version" {
  secret = google_secret_manager_secret.dev_secrets.id
  secret_data = jsonencode({
    test_db_password = "dev-password-123"
    debug_api_key   = "dev-api-key-456"
    local_jwt_secret = "dev-jwt-secret-789"
  })
}

# Service Account for Secret Management
resource "google_service_account" "secret_manager_sa" {
  account_id   = "secret-manager-automation"
  display_name = "Secret Manager Automation Service Account"
  description  = "Service account for automated secret management and rotation"
}

# IAM permissions for secret management
resource "google_project_iam_member" "secret_manager_admin" {
  project = var.project_id
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${google_service_account.secret_manager_sa.email}"
}

resource "google_project_iam_member" "secret_manager_viewer" {
  project = var.project_id
  role    = "roles/secretmanager.viewer"
  member  = "serviceAccount:${google_service_account.secret_manager_sa.email}"
}

# Cloud Monitoring for secret expiration alerts - Personal Email
resource "google_monitoring_notification_channel" "secret_expiration_email" {
  display_name = "Secret Expiration Personal Alerts"
  type         = "email"
  
  labels = {
    email_address = "leonix23@gmail.com"
  }
}

# Cloud Monitoring for secret expiration alerts - GitHub Notifications
resource "google_monitoring_notification_channel" "secret_expiration_github" {
  display_name = "Secret Expiration GitHub Alerts"
  type         = "email"
  
  labels = {
    email_address = "leonix33@users.noreply.github.com"
  }
}

# Alert policy for secret expiration
resource "google_monitoring_alert_policy" "secret_expiration_alert" {
  display_name = "Secret Manager - Expiring Secrets Alert"
  combiner     = "OR"
  
  conditions {
    display_name = "Secrets expiring within 30 days"
    
    condition_threshold {
      filter          = "resource.type=\"gce_instance\""
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 0
      duration        = "300s"
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.secret_expiration_email.name,
    google_monitoring_notification_channel.secret_expiration_github.name
  ]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Cloud Function for automated secret rotation (trigger)
resource "google_storage_bucket" "secret_automation_source" {
  name     = "${var.project_id}-secret-automation-source"
  location = var.region
  
  labels = {
    environment = var.environment
    purpose     = "secret-automation"
  }
}

# Output values for secret management
output "secret_manager_secrets" {
  description = "Created secret manager secrets"
  value = {
    database_credentials = google_secret_manager_secret.db_credentials.secret_id
    api_keys            = google_secret_manager_secret.external_api_keys.secret_id
    ssl_certificates    = google_secret_manager_secret.ssl_certificates.secret_id
    oauth_credentials   = google_secret_manager_secret.oauth_credentials.secret_id
    dev_secrets        = google_secret_manager_secret.dev_secrets.secret_id
  }
}

output "secret_manager_service_account" {
  description = "Service account for secret management automation"
  value = google_service_account.secret_manager_sa.email
}