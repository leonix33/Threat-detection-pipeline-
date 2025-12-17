#!/bin/bash

# Secret Manager Deployment Script
# Deploy comprehensive secret management infrastructure to GCP

set -e

echo "🔐 Deploying Secret Manager Infrastructure"
echo "========================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if [ -z "$PROJECT_ID" ]; then
        print_error "GCP_PROJECT_ID environment variable not set"
        echo "Please run: export GCP_PROJECT_ID=your-project-id"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not installed"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not installed"
        exit 1
    fi
    
    print_success "Prerequisites check completed"
}

deploy_infrastructure() {
    print_status "Deploying Secret Manager infrastructure..."
    
    cd infrastructure
    
    # Initialize Terraform
    terraform init -upgrade
    
    # Validate configuration
    terraform validate
    
    # Plan deployment
    terraform plan -var="project_id=$PROJECT_ID" -var="region=$REGION" -out=secret-manager.tfplan
    
    # Apply deployment
    terraform apply secret-manager.tfplan
    
    if [ $? -eq 0 ]; then
        print_success "Secret Manager infrastructure deployed successfully"
    else
        print_error "Failed to deploy infrastructure"
        exit 1
    fi
    
    cd ..
}

setup_monitoring() {
    print_status "Setting up monitoring automation..."
    
    # Make scripts executable
    chmod +x scripts/manage-secrets.sh
    chmod +x scripts/secret_monitor.py
    
    # Install Python dependencies
    if command -v pip3 &> /dev/null; then
        pip3 install google-cloud-secret-manager google-cloud-monitoring google-cloud-pubsub
        print_success "Python dependencies installed"
    else
        print_warning "pip3 not found. Please install Python dependencies manually:"
        echo "pip install google-cloud-secret-manager google-cloud-monitoring google-cloud-pubsub"
    fi
}

create_sample_secrets() {
    print_status "Creating sample secrets..."
    
    export GCP_PROJECT_ID="$PROJECT_ID"
    
    # Run the secret management script to create samples
    scripts/manage-secrets.sh --create-samples
    
    print_success "Sample secrets created"
}

setup_scheduler() {
    print_status "Setting up Cloud Scheduler for automated monitoring..."
    
    # Create Cloud Scheduler job for daily secret monitoring
    gcloud scheduler jobs create pubsub secret-expiry-monitor \
        --project="$PROJECT_ID" \
        --schedule="0 9 * * *" \
        --topic="secret-expiration-alerts" \
        --message-body='{"trigger": "daily-check"}' \
        --description="Daily secret expiration monitoring" \
        --time-zone="UTC" || print_warning "Scheduler job may already exist"
    
    print_success "Cloud Scheduler configured"
}

run_initial_check() {
    print_status "Running initial secret expiration check..."
    
    export GCP_PROJECT_ID="$PROJECT_ID"
    
    # Run expiration check
    scripts/manage-secrets.sh --check-expiry
    
    # Generate rotation schedule
    scripts/manage-secrets.sh --schedule
    
    print_success "Initial monitoring check completed"
}

show_deployment_summary() {
    echo ""
    echo "🎉 Secret Manager Deployment Completed!"
    echo "======================================"
    echo ""
    echo "📋 Deployed Components:"
    echo "- Secret Manager infrastructure with sample secrets"
    echo "- Automated expiration monitoring and alerting"
    echo "- Cloud Scheduler for daily checks"
    echo "- Management scripts for manual operations"
    echo ""
    echo "🔧 Available Commands:"
    echo "scripts/manage-secrets.sh --list                 # List all secrets"
    echo "scripts/manage-secrets.sh --check-expiry         # Check expiring secrets"
    echo "scripts/manage-secrets.sh --schedule             # Generate rotation schedule"
    echo "scripts/manage-secrets.sh --cleanup-expired      # Remove expired secrets"
    echo ""
    echo "🔍 Monitor Your Secrets:"
    echo "- Check Cloud Monitoring for custom metrics"
    echo "- Review Pub/Sub topic 'secret-expiration-alerts'"
    echo "- Cloud Scheduler runs daily at 09:00 UTC"
    echo ""
    echo "📊 Sample Secrets Created:"
    echo "- test-short-term-secret (expires in 7 days)"
    echo "- test-medium-term-secret (expires in 30 days)" 
    echo "- test-long-term-secret (expires in 1 year)"
    echo "- test-expired-secret (already expired for testing)"
    echo ""
    echo "Project: $PROJECT_ID"
    echo "Region: $REGION"
    echo ""
    print_success "Secret Manager platform is ready! 🔐"
}

main() {
    echo "Starting Secret Manager deployment..."
    echo "Project: $PROJECT_ID"
    echo "Region: $REGION"
    echo "Timestamp: $(date)"
    echo ""
    
    check_prerequisites
    deploy_infrastructure
    setup_monitoring
    create_sample_secrets
    setup_scheduler
    run_initial_check
    show_deployment_summary
}

# Run main function
main "$@"