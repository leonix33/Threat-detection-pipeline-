#!/bin/bash

# Deploy Data Engineering Cluster to Databricks Workspace
# This script focuses only on deploying the Databricks resources (clusters, policies, etc.)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRASTRUCTURE_DIR="$SCRIPT_DIR/../infrastructure"

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

# Check if required variables are set
check_prerequisites() {
    header "Checking Prerequisites"
    
    if [ -z "$DATABRICKS_HOST" ]; then
        error "DATABRICKS_HOST environment variable is not set"
        echo "Please set it to your Databricks workspace URL:"
        echo "export DATABRICKS_HOST=https://your-workspace.cloud.databricks.com"
        exit 1
    fi
    
    if [ -z "$DATABRICKS_TOKEN" ]; then
        error "DATABRICKS_TOKEN environment variable is not set"
        echo "Please set it to your Databricks access token:"
        echo "export DATABRICKS_TOKEN=your-token"
        exit 1
    fi
    
    # Check if Databricks CLI is installed and configured
    if ! command -v databricks &> /dev/null; then
        error "Databricks CLI is not installed"
        echo "Install it with: pip install databricks-cli"
        exit 1
    fi
    
    # Test Databricks connection
    if ! databricks workspace list &> /dev/null; then
        error "Cannot connect to Databricks workspace"
        echo "Please check your DATABRICKS_HOST and DATABRICKS_TOKEN"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Deploy only Databricks resources using Terraform
deploy_databricks_resources() {
    header "Deploying Databricks Resources"
    
    cd "$INFRASTRUCTURE_DIR"
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        warning "terraform.tfvars not found, creating from example..."
        if [ -f "terraform.tfvars.example" ]; then
            cp terraform.tfvars.example terraform.tfvars
            warning "Please edit terraform.tfvars with your actual values before continuing"
            echo "Press Enter when ready to continue..."
            read
        else
            error "No terraform.tfvars.example found"
            exit 1
        fi
    fi
    
    # Target only Databricks resources
    log "Deploying Databricks clusters and policies..."
    
    # Plan only Databricks resources
    terraform plan \
        -target=databricks_cluster_policy.cost_control \
        -target=databricks_cluster.analytics_cluster \
        -target=databricks_cluster.ml_cluster \
        -target=databricks_cluster.data_engineering_cluster \
        -target=databricks_sql_endpoint.analytics_warehouse \
        -target=databricks_directory.shared_analytics \
        -target=databricks_directory.shared_ml \
        -target=databricks_directory.shared_pipelines \
        -target=databricks_secret_scope.main \
        -target=databricks_secret.gcs_credentials \
        -target=databricks_secret.db_password
    
    echo ""
    echo "This will deploy the following Databricks resources:"
    echo "- Cost Control Policy"
    echo "- Analytics Cluster"
    echo "- ML Cluster"
    echo "- Data Engineering Cluster (n1-standard-8, 2-10 workers)"
    echo "- Analytics SQL Warehouse"
    echo "- Workspace directories (/Shared/Analytics, /Shared/ML, /Shared/Pipelines)"
    echo "- Secret scope with credentials"
    echo ""
    read -p "Do you want to proceed? (y/N): " confirm
    
    if [[ $confirm != [yY] ]]; then
        log "Deployment cancelled by user"
        exit 0
    fi
    
    # Apply only Databricks resources
    terraform apply -auto-approve \
        -target=databricks_cluster_policy.cost_control \
        -target=databricks_cluster.analytics_cluster \
        -target=databricks_cluster.ml_cluster \
        -target=databricks_cluster.data_engineering_cluster \
        -target=databricks_sql_endpoint.analytics_warehouse \
        -target=databricks_directory.shared_analytics \
        -target=databricks_directory.shared_ml \
        -target=databricks_directory.shared_pipelines \
        -target=databricks_secret_scope.main \
        -target=databricks_secret.gcs_credentials \
        -target=databricks_secret.db_password
    
    success "Databricks resources deployed successfully!"
}

# Upload notebooks and init scripts
upload_resources() {
    header "Uploading Notebooks and Scripts"
    
    # Create directories
    log "Creating workspace directories..."
    databricks workspace mkdirs /Shared/DataEngineering
    databricks workspace mkdirs /Shared/DataEngineering/Pipelines
    databricks workspace mkdirs /Shared/init-scripts
    
    # Upload init script
    if [ -f "$SCRIPT_DIR/data-engineering-init.sh" ]; then
        log "Uploading data engineering init script..."
        databricks workspace import \
            --format AUTO \
            --overwrite \
            "$SCRIPT_DIR/data-engineering-init.sh" \
            "/Shared/init-scripts/data-engineering-init.sh"
        success "Init script uploaded"
    fi
    
    # Upload notebook
    if [ -f "$SCRIPT_DIR/../notebooks/data_engineering_pipeline.py" ]; then
        log "Uploading data engineering pipeline notebook..."
        databricks workspace import \
            --format AUTO \
            --overwrite \
            "$SCRIPT_DIR/../notebooks/data_engineering_pipeline.py" \
            "/Shared/DataEngineering/Pipelines/ETL_Pipeline"
        success "Pipeline notebook uploaded"
    fi
}

# Start the data engineering cluster
start_data_engineering_cluster() {
    header "Starting Data Engineering Cluster"
    
    # Get cluster ID from Terraform output
    cd "$INFRASTRUCTURE_DIR"
    CLUSTER_ID=$(terraform output -raw data_engineering_cluster_id 2>/dev/null || echo "")
    
    if [ -n "$CLUSTER_ID" ]; then
        log "Starting Data Engineering cluster (ID: $CLUSTER_ID)..."
        databricks clusters start --cluster-id "$CLUSTER_ID"
        success "Data Engineering cluster started"
        
        # Wait for cluster to be ready
        log "Waiting for cluster to be ready..."
        while true; do
            STATUS=$(databricks clusters get --cluster-id "$CLUSTER_ID" | jq -r '.state')
            if [ "$STATUS" == "RUNNING" ]; then
                success "Cluster is running and ready!"
                break
            elif [ "$STATUS" == "ERROR" ] || [ "$STATUS" == "TERMINATED" ]; then
                error "Cluster failed to start. Status: $STATUS"
                exit 1
            else
                log "Cluster status: $STATUS - waiting..."
                sleep 30
            fi
        done
    else
        warning "Could not get cluster ID from Terraform output"
        log "You can manually start the cluster from the Databricks workspace"
    fi
}

# Main execution
main() {
    header "Deploying Data Engineering Cluster to Databricks"
    
    check_prerequisites
    deploy_databricks_resources
    upload_resources
    start_data_engineering_cluster
    
    header "Deployment Complete!"
    
    echo ""
    echo "Data Engineering resources successfully deployed to Databricks workspace!"
    echo ""
    echo "Available resources:"
    echo "- Data Engineering Cluster: n1-standard-8 instances, 2-10 workers"
    echo "- Analytics Cluster: General purpose analytics"
    echo "- ML Cluster: Machine learning workloads" 
    echo "- SQL Warehouse: Interactive queries"
    echo "- ETL Pipeline Notebook: /Shared/DataEngineering/Pipelines/ETL_Pipeline"
    echo ""
    echo "Next steps:"
    echo "1. Open your Databricks workspace: $DATABRICKS_HOST"
    echo "2. Navigate to Compute tab to see your clusters"
    echo "3. Go to /Shared/DataEngineering/Pipelines/ to run the ETL pipeline"
    echo "4. Attach the Data Engineering cluster to notebooks for optimal performance"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Deploy Data Engineering cluster and resources to Databricks workspace"
        echo ""
        echo "Prerequisites:"
        echo "  - DATABRICKS_HOST environment variable set"
        echo "  - DATABRICKS_TOKEN environment variable set"
        echo "  - Databricks CLI installed and configured"
        echo "  - Terraform initialized in infrastructure directory"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --check        Only check prerequisites"
        echo "  --plan         Only show Terraform plan"
        echo ""
        exit 0
        ;;
    --check)
        check_prerequisites
        exit 0
        ;;
    --plan)
        check_prerequisites
        cd "$INFRASTRUCTURE_DIR"
        terraform plan \
            -target=databricks_cluster_policy.cost_control \
            -target=databricks_cluster.analytics_cluster \
            -target=databricks_cluster.ml_cluster \
            -target=databricks_cluster.data_engineering_cluster \
            -target=databricks_sql_endpoint.analytics_warehouse
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