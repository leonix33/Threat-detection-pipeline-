#!/bin/bash

# Kafka Infrastructure Deployment Script
# This script deploys the complete Kafka streaming infrastructure

set -e  # Exit on any error

echo "🚀 Starting Kafka Infrastructure Deployment"
echo "============================================"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DATABRICKS_HOST="https://4302395672529079.9.gcp.databricks.com"
CLUSTER_ID="6211-214138-ihnmmf40"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if gcloud CLI is available
    if ! command -v gcloud &> /dev/null; then
        print_warning "gcloud CLI not found. Some features may not work."
    fi
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed."
        exit 1
    fi
    
    print_success "Prerequisites check completed"
}

# Function to validate Terraform configuration
validate_terraform() {
    print_status "Validating Terraform configuration..."
    
    cd infrastructure
    
    # Initialize Terraform
    terraform init -upgrade
    
    # Validate configuration
    terraform validate
    
    if [ $? -eq 0 ]; then
        print_success "Terraform configuration is valid"
    else
        print_error "Terraform configuration validation failed"
        exit 1
    fi
    
    cd ..
}

# Function to deploy Kafka infrastructure
deploy_kafka_infrastructure() {
    print_status "Deploying Kafka infrastructure with Terraform..."
    
    cd infrastructure
    
    # Plan the deployment
    terraform plan -var-file="terraform.tfvars" -out=kafka.tfplan
    
    # Apply the plan
    print_status "Applying Terraform configuration..."
    terraform apply kafka.tfplan
    
    if [ $? -eq 0 ]; then
        print_success "Kafka infrastructure deployed successfully"
    else
        print_error "Failed to deploy Kafka infrastructure"
        exit 1
    fi
    
    # Get outputs
    print_status "Retrieving deployment outputs..."
    terraform output -json > kafka_outputs.json
    
    cd ..
}

# Function to update cluster with new configuration
update_databricks_cluster() {
    print_status "Updating Databricks cluster with Kafka configurations..."
    
    # Check if DATABRICKS_TOKEN is set
    if [ -z "$DATABRICKS_TOKEN" ]; then
        print_error "DATABRICKS_TOKEN environment variable not set"
        print_warning "Please set your Databricks token: export DATABRICKS_TOKEN=your_token"
        exit 1
    fi
    
    cd cluster-deployment
    
    # Initialize and apply cluster updates
    terraform init
    terraform plan -out=cluster-update.tfplan
    terraform apply cluster-update.tfplan
    
    if [ $? -eq 0 ]; then
        print_success "Databricks cluster updated with Kafka configurations"
    else
        print_warning "Cluster update encountered issues - may need manual intervention"
    fi
    
    cd ..
}

# Function to install Kafka libraries
install_kafka_libraries() {
    print_status "Installing Kafka libraries on cluster..."
    
    # Check if cluster is running
    cluster_status=$(curl -s -X GET \
        "${DATABRICKS_HOST}/api/2.0/clusters/get?cluster_id=${CLUSTER_ID}" \
        -H "Authorization: Bearer ${DATABRICKS_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.state // "UNKNOWN"')
    
    print_status "Current cluster status: ${cluster_status}"
    
    if [ "$cluster_status" != "RUNNING" ]; then
        print_warning "Cluster is not running. Libraries will be installed when cluster starts."
    fi
    
    # Install libraries via API
    library_payload='{
        "cluster_id": "'${CLUSTER_ID}'",
        "libraries": [
            {
                "pypi": {
                    "package": "confluent-kafka==2.3.0"
                }
            },
            {
                "pypi": {
                    "package": "google-cloud-pubsub==2.18.4"
                }
            },
            {
                "pypi": {
                    "package": "kafka-python==2.0.2"
                }
            },
            {
                "pypi": {
                    "package": "avro-python3==1.11.3"
                }
            }
        ]
    }'
    
    curl -X POST "${DATABRICKS_HOST}/api/2.0/libraries/install" \
        -H "Authorization: Bearer ${DATABRICKS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${library_payload}"
    
    print_success "Kafka libraries installation initiated"
}

# Function to upload Kafka notebook
upload_kafka_notebook() {
    print_status "Uploading Kafka streaming notebook..."
    
    # Base64 encode the notebook
    notebook_content=$(base64 -i notebooks/kafka_streaming_pipeline.py)
    
    # Upload notebook via API
    notebook_payload='{
        "path": "/Shared/DataEngineering/kafka_streaming_pipeline",
        "content": "'${notebook_content}'",
        "language": "PYTHON",
        "overwrite": true,
        "format": "SOURCE"
    }'
    
    curl -X POST "${DATABRICKS_HOST}/api/2.0/workspace/import" \
        -H "Authorization: Bearer ${DATABRICKS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${notebook_payload}"
    
    if [ $? -eq 0 ]; then
        print_success "Kafka streaming notebook uploaded successfully"
    else
        print_warning "Notebook upload may have encountered issues"
    fi
}

# Function to run deployment verification
verify_deployment() {
    print_status "Verifying Kafka deployment..."
    
    # Check Terraform outputs
    if [ -f "infrastructure/kafka_outputs.json" ]; then
        print_status "Kafka topics created:"
        cat infrastructure/kafka_outputs.json | jq -r '.kafka_topics.value // "No topics found"'
        print_success "Infrastructure verification completed"
    fi
    
    # Check cluster status
    cluster_info=$(curl -s -X GET \
        "${DATABRICKS_HOST}/api/2.0/clusters/get?cluster_id=${CLUSTER_ID}" \
        -H "Authorization: Bearer ${DATABRICKS_TOKEN}" \
        -H "Content-Type: application/json")
    
    cluster_state=$(echo $cluster_info | jq -r '.state // "UNKNOWN"')
    print_status "Final cluster status: ${cluster_state}"
    
    if [ "$cluster_state" = "RUNNING" ]; then
        print_success "Cluster is running and ready for Kafka streaming"
    else
        print_warning "Cluster may need to be started manually"
    fi
}

# Function to display next steps
show_next_steps() {
    echo ""
    echo "🎉 Kafka Infrastructure Deployment Completed!"
    echo "============================================="
    echo ""
    echo "📋 Next Steps:"
    echo "1. Start your Databricks cluster if not already running"
    echo "2. Open the Kafka streaming notebook: /Shared/DataEngineering/kafka_streaming_pipeline"
    echo "3. Configure PROJECT_ID in the notebook with your GCP project"
    echo "4. Run the notebook to start streaming pipeline"
    echo "5. Monitor streaming jobs in Databricks UI"
    echo ""
    echo "🔗 Resources:"
    echo "- Databricks Workspace: ${DATABRICKS_HOST}"
    echo "- Cluster ID: ${CLUSTER_ID}"
    echo "- Notebook Path: /Shared/DataEngineering/kafka_streaming_pipeline"
    echo ""
    echo "📊 Monitoring:"
    echo "- Check Spark Streaming UI for real-time metrics"
    echo "- Monitor Delta tables in /mnt/delta/ paths"
    echo "- View logs in cluster event logs"
}

# Main deployment workflow
main() {
    echo "Starting Kafka deployment pipeline..."
    echo "Timestamp: $(date)"
    echo ""
    
    # Run deployment steps
    check_prerequisites
    validate_terraform
    
    # Only proceed with infrastructure if Terraform validation passes
    if [ "$1" != "--skip-terraform" ]; then
        deploy_kafka_infrastructure
    else
        print_warning "Skipping Terraform deployment (--skip-terraform flag)"
    fi
    
    # Update cluster and install libraries
    update_databricks_cluster
    install_kafka_libraries
    upload_kafka_notebook
    
    # Verify deployment
    verify_deployment
    
    # Show completion message
    show_next_steps
    
    print_success "Kafka deployment pipeline completed successfully! 🚀"
}

# Run main function with all arguments
main "$@"