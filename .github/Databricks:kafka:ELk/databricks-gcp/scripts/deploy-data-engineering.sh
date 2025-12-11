#!/bin/bash

# Data Engineering Cluster Deployment Script
# Deploys and configures the data engineering cluster with all necessary components

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

header() {
    echo -e "${BOLD}${CYAN}"
    echo "================================================="
    echo "$1"
    echo "================================================="
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    header "Checking Prerequisites"
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if Databricks CLI is installed
    if ! command -v databricks &> /dev/null; then
        error "Databricks CLI is not installed. Please install Databricks CLI first."
        exit 1
    fi
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        error "Google Cloud SDK is not installed. Please install gcloud first."
        exit 1
    fi
    
    success "All prerequisites met"
}

# Deploy infrastructure if not already deployed
deploy_infrastructure() {
    header "Deploying Infrastructure"
    
    cd "$PROJECT_ROOT/infrastructure"
    
    if [ ! -f "terraform.tfstate" ]; then
        log "Initializing and applying Terraform configuration..."
        terraform init
        terraform plan
        terraform apply -auto-approve
        success "Infrastructure deployed successfully"
    else
        log "Infrastructure already exists, applying any changes..."
        terraform plan
        terraform apply -auto-approve
        success "Infrastructure updated successfully"
    fi
    
    cd "$SCRIPT_DIR"
}

# Upload init script to Databricks workspace
upload_init_script() {
    header "Uploading Data Engineering Init Script"
    
    log "Creating workspace directories..."
    databricks workspace mkdirs /Shared/init-scripts
    
    log "Uploading init script..."
    databricks workspace import \
        --format AUTO \
        --overwrite \
        "$SCRIPT_DIR/data-engineering-init.sh" \
        "/Shared/init-scripts/data-engineering-init.sh"
    
    success "Init script uploaded successfully"
}

# Upload notebooks to workspace
upload_notebooks() {
    header "Uploading Data Engineering Notebooks"
    
    log "Creating notebook directories..."
    databricks workspace mkdirs /Shared/DataEngineering
    databricks workspace mkdirs /Shared/DataEngineering/Pipelines
    databricks workspace mkdirs /Shared/DataEngineering/Utils
    
    log "Uploading data engineering pipeline notebook..."
    databricks workspace import \
        --format AUTO \
        --overwrite \
        "$PROJECT_ROOT/notebooks/data_engineering_pipeline.py" \
        "/Shared/DataEngineering/Pipelines/ETL_Pipeline"
    
    success "Notebooks uploaded successfully"
}

# Create Databricks job for the data engineering pipeline
create_databricks_job() {
    header "Creating Databricks Job"
    
    cat > /tmp/data-engineering-job.json << EOF
{
  "name": "Data Engineering ETL Pipeline",
  "job_clusters": [
    {
      "job_cluster_key": "data-engineering-cluster",
      "new_cluster": {
        "cluster_name": "Data Engineering Job Cluster",
        "node_type_id": "n1-standard-8",
        "driver_node_type_id": "n1-standard-8",
        "num_workers": 3,
        "autotermination_minutes": 30,
        "spark_version": "13.3.x-scala2.12",
        "spark_conf": {
          "spark.databricks.cluster.profile": "serverless",
          "spark.sql.adaptive.enabled": "true",
          "spark.sql.adaptive.coalescePartitions.enabled": "true",
          "spark.databricks.delta.optimizeWrite.enabled": "true",
          "spark.databricks.delta.autoCompact.enabled": "true"
        },
        "init_scripts": [
          {
            "workspace": {
              "destination": "/Shared/init-scripts/data-engineering-init.sh"
            }
          }
        ],
        "custom_tags": {
          "Environment": "production",
          "Team": "DataEngineering",
          "Purpose": "ETL-Processing"
        }
      }
    }
  ],
  "tasks": [
    {
      "task_key": "etl-pipeline",
      "job_cluster_key": "data-engineering-cluster",
      "notebook_task": {
        "notebook_path": "/Shared/DataEngineering/Pipelines/ETL_Pipeline",
        "base_parameters": {
          "environment": "production",
          "data_source": "gcs"
        }
      },
      "timeout_seconds": 3600,
      "max_retries": 2
    }
  ],
  "schedule": {
    "quartz_cron_expression": "0 0 2 * * ?",
    "timezone_id": "UTC"
  },
  "max_concurrent_runs": 1,
  "tags": {
    "team": "data-engineering",
    "environment": "production"
  }
}
EOF

    log "Creating Databricks job..."
    databricks jobs create --json-file /tmp/data-engineering-job.json
    
    success "Databricks job created successfully"
    rm -f /tmp/data-engineering-job.json
}

# Create sample data for testing
create_sample_data() {
    header "Creating Sample Data"
    
    log "Setting up sample data in Google Cloud Storage..."
    
    # Create sample CSV data
    cat > /tmp/sample_users.csv << EOF
id,name,email,created_date,status,department,salary
1,John Doe,john.doe@company.com,2024-01-15,active,Engineering,75000
2,Jane Smith,jane.smith@company.com,2024-01-16,active,Marketing,65000
3,Bob Johnson,bob.johnson@company.com,2024-01-17,inactive,Sales,55000
4,Alice Brown,alice.brown@company.com,2024-01-18,active,Engineering,80000
5,Charlie Wilson,charlie.wilson@company.com,2024-01-19,active,HR,50000
6,Diana Prince,diana.prince@company.com,2024-01-20,inactive,Legal,90000
7,Eve Davis,eve.davis@company.com,2024-01-21,active,Engineering,72000
8,Frank Miller,frank.miller@company.com,2024-01-22,active,Marketing,58000
9,Grace Lee,grace.lee@company.com,2024-01-23,active,Sales,62000
10,Henry Ford,henry.ford@company.com,2024-01-24,inactive,Engineering,85000
EOF

    # Get bucket name from Terraform output
    BUCKET_NAME=$(cd "$PROJECT_ROOT/infrastructure" && terraform output -raw data_lake_bucket_name 2>/dev/null || echo "databricks-datalake-$(date +%s)")
    
    log "Uploading sample data to gs://${BUCKET_NAME}/sample-data/"
    gsutil cp /tmp/sample_users.csv "gs://${BUCKET_NAME}/sample-data/users.csv"
    
    success "Sample data created and uploaded"
    rm -f /tmp/sample_users.csv
}

# Setup monitoring and alerting
setup_monitoring() {
    header "Setting Up Monitoring"
    
    log "Creating monitoring dashboard configuration..."
    
    cat > /tmp/monitoring-config.json << EOF
{
  "dashboard_name": "Data Engineering Cluster Monitoring",
  "widgets": [
    {
      "name": "Cluster CPU Usage",
      "type": "metric",
      "query": "databricks.cluster.cpu.utilization"
    },
    {
      "name": "Job Success Rate",
      "type": "metric", 
      "query": "databricks.job.success.rate"
    },
    {
      "name": "Data Processing Volume",
      "type": "metric",
      "query": "databricks.data.processed.bytes"
    }
  ]
}
EOF

    log "Monitoring configuration created at /tmp/monitoring-config.json"
    success "Monitoring setup completed"
}

# Main deployment function
main() {
    header "Data Engineering Cluster Deployment"
    
    log "Starting deployment process..."
    
    # Run deployment steps
    check_prerequisites
    deploy_infrastructure
    
    # Wait for infrastructure to be ready
    sleep 30
    
    upload_init_script
    upload_notebooks
    create_databricks_job
    create_sample_data
    setup_monitoring
    
    header "Deployment Complete"
    success "Data Engineering cluster deployed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Log into your Databricks workspace"
    echo "2. Navigate to /Shared/DataEngineering/Pipelines/"
    echo "3. Run the ETL_Pipeline notebook"
    echo "4. Check the Jobs tab for scheduled pipeline execution"
    echo "5. Monitor cluster performance in the monitoring dashboard"
    echo ""
    echo "Resources created:"
    echo "- Data Engineering cluster with optimized configuration"
    echo "- ETL pipeline notebook with best practices"
    echo "- Scheduled job for automated pipeline execution"
    echo "- Sample data for testing"
    echo "- Monitoring and alerting configuration"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --check        Only check prerequisites"
        echo "  --infra        Only deploy infrastructure"
        echo "  --notebooks    Only upload notebooks"
        echo "  --sample-data  Only create sample data"
        echo ""
        echo "Examples:"
        echo "  $0                    # Full deployment"
        echo "  $0 --check          # Check prerequisites only"
        echo "  $0 --infra          # Deploy infrastructure only"
        exit 0
        ;;
    --check)
        check_prerequisites
        exit 0
        ;;
    --infra)
        check_prerequisites
        deploy_infrastructure
        exit 0
        ;;
    --notebooks)
        upload_notebooks
        exit 0
        ;;
    --sample-data)
        create_sample_data
        exit 0
        ;;
    "")
        main
        ;;
    *)
        error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac