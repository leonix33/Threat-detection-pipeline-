#!/bin/bash

# Secret Manager Automation Script
# Comprehensive secret lifecycle management with expiration tracking

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-your-project-id}"
SERVICE_ACCOUNT_EMAIL="secret-manager-automation@${PROJECT_ID}.iam.gserviceaccount.com"
NOTIFICATION_EMAIL="${ADMIN_EMAIL:-leonix23@gmail.com}"
WARNING_DAYS=30
CRITICAL_DAYS=7

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

print_critical() {
    echo -e "${PURPLE}[CRITICAL]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed. Please install Google Cloud SDK."
        exit 1
    fi
    
    # Check authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "No active gcloud authentication found. Please run 'gcloud auth login'"
        exit 1
    fi
    
    # Check if jq is installed for JSON processing
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found. Installing jq for JSON processing..."
        # Try to install jq
        if command -v brew &> /dev/null; then
            brew install jq
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        else
            print_error "Please install jq manually for JSON processing"
            exit 1
        fi
    fi
    
    print_success "Prerequisites check completed"
}

# Function to list all secrets with their metadata
list_secrets() {
    print_status "Retrieving all secrets from Secret Manager..."
    
    secrets=$(gcloud secrets list --project="${PROJECT_ID}" --format="json")
    
    if [ "$secrets" = "[]" ]; then
        print_warning "No secrets found in project ${PROJECT_ID}"
        return
    fi
    
    echo "$secrets" | jq -r '.[] | "\(.name)|\(.labels.expires_on // "no-expiry")|\(.labels.criticality // "unknown")|\(.labels.component // "unknown")|\(.labels.rotation // "unknown")"' | \
    while IFS='|' read -r secret_name expires_on criticality component rotation; do
        echo "Secret: $secret_name"
        echo "  Component: $component"
        echo "  Criticality: $criticality"
        echo "  Rotation: $rotation"
        echo "  Expires: $expires_on"
        echo ""
    done
}

# Function to check secret expiration dates
check_expiring_secrets() {
    print_status "Checking for expiring secrets..."
    
    current_date=$(date +%s)
    warning_date=$((current_date + WARNING_DAYS * 86400))
    critical_date=$((current_date + CRITICAL_DAYS * 86400))
    
    expiring_secrets=()
    critical_secrets=()
    
    secrets=$(gcloud secrets list --project="${PROJECT_ID}" --format="json")
    
    echo "$secrets" | jq -r '.[] | "\(.name)|\(.labels.expires_on // "no-expiry")|\(.labels.criticality // "unknown")|\(.labels.component // "unknown")"' | \
    while IFS='|' read -r secret_name expires_on criticality component; do
        if [ "$expires_on" != "no-expiry" ]; then
            expiry_timestamp=$(date -d "$expires_on" +%s 2>/dev/null || echo "0")
            
            if [ "$expiry_timestamp" -gt 0 ]; then
                days_until_expiry=$(( (expiry_timestamp - current_date) / 86400 ))
                
                if [ "$expiry_timestamp" -le "$critical_date" ]; then
                    print_critical "Secret '$secret_name' expires in $days_until_expiry days! (Component: $component, Criticality: $criticality)"
                    critical_secrets+=("$secret_name:$expires_on:$criticality:$component")
                elif [ "$expiry_timestamp" -le "$warning_date" ]; then
                    print_warning "Secret '$secret_name' expires in $days_until_expiry days (Component: $component, Criticality: $criticality)"
                    expiring_secrets+=("$secret_name:$expires_on:$criticality:$component")
                fi
            else
                print_warning "Invalid expiry date format for secret '$secret_name': $expires_on"
            fi
        fi
    done
    
    # Generate reports
    if [ ${#critical_secrets[@]} -gt 0 ] || [ ${#expiring_secrets[@]} -gt 0 ]; then
        generate_expiration_report "${critical_secrets[@]}" "${expiring_secrets[@]}"
    else
        print_success "No secrets expiring within $WARNING_DAYS days"
    fi
}

# Function to generate expiration report
generate_expiration_report() {
    local critical_secrets=("$@")
    local expiring_secrets=()
    
    # Separate critical and warning secrets
    for secret in "$@"; do
        if [[ "$secret" == *":high:"* ]] || [[ "$secret" =~ :[0-6]: ]]; then
            critical_secrets+=("$secret")
        else
            expiring_secrets+=("$secret")
        fi
    done
    
    report_file="/tmp/secret_expiration_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Secret Manager Expiration Report"
        echo "Generated on: $(date)"
        echo "Project: $PROJECT_ID"
        echo "================================"
        echo ""
        
        if [ ${#critical_secrets[@]} -gt 0 ]; then
            echo "CRITICAL - Secrets expiring within $CRITICAL_DAYS days:"
            echo "======================================================"
            for secret in "${critical_secrets[@]}"; do
                IFS=':' read -r name expiry criticality component <<< "$secret"
                echo "- $name (Component: $component, Criticality: $criticality, Expires: $expiry)"
            done
            echo ""
        fi
        
        if [ ${#expiring_secrets[@]} -gt 0 ]; then
            echo "WARNING - Secrets expiring within $WARNING_DAYS days:"
            echo "================================================="
            for secret in "${expiring_secrets[@]}"; do
                IFS=':' read -r name expiry criticality component <<< "$secret"
                echo "- $name (Component: $component, Criticality: $criticality, Expires: $expiry)"
            done
            echo ""
        fi
        
        echo "Recommended Actions:"
        echo "==================="
        echo "1. Review and rotate expiring secrets"
        echo "2. Update expiration dates in secret labels"
        echo "3. Test applications after secret rotation"
        echo "4. Update monitoring and alerting thresholds"
        
    } > "$report_file"
    
    print_status "Expiration report saved to: $report_file"
    
    # Optionally email the report
    if command -v mail &> /dev/null; then
        mail -s "Secret Manager Expiration Alert - $PROJECT_ID" "$NOTIFICATION_EMAIL" < "$report_file"
        print_success "Report emailed to $NOTIFICATION_EMAIL"
    else
        print_warning "Mail command not available. Please review the report manually: $report_file"
    fi
}

# Function to create a new secret with expiration metadata
create_sample_secret() {
    local secret_name="$1"
    local component="$2"
    local criticality="$3"
    local rotation_freq="$4"
    local expires_on="$5"
    local secret_value="$6"
    
    print_status "Creating secret: $secret_name"
    
    # Create the secret with labels
    gcloud secrets create "$secret_name" \
        --project="$PROJECT_ID" \
        --labels="environment=production,component=$component,criticality=$criticality,rotation=$rotation_freq,expires_on=$expires_on,created_by=automation" \
        --replication-policy="automatic" || {
        print_warning "Secret $secret_name may already exist or creation failed"
        return 1
    }
    
    # Add the secret value
    echo "$secret_value" | gcloud secrets versions add "$secret_name" \
        --project="$PROJECT_ID" \
        --data-file="-"
    
    print_success "Created secret: $secret_name with expiration: $expires_on"
}

# Function to update secret expiration date
update_secret_expiration() {
    local secret_name="$1"
    local new_expiry_date="$2"
    
    print_status "Updating expiration for secret: $secret_name to $new_expiry_date"
    
    # Get current labels
    current_labels=$(gcloud secrets describe "$secret_name" --project="$PROJECT_ID" --format="json" | jq -r '.labels // {}')
    
    # Update the expires_on label
    updated_labels=$(echo "$current_labels" | jq ". + {\"expires_on\": \"$new_expiry_date\"}")
    
    # Convert to gcloud format
    label_string=$(echo "$updated_labels" | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
    
    gcloud secrets update "$secret_name" \
        --project="$PROJECT_ID" \
        --update-labels="$label_string"
    
    print_success "Updated expiration for $secret_name to $new_expiry_date"
}

# Function to rotate a secret (creates new version)
rotate_secret() {
    local secret_name="$1"
    local new_value="$2"
    local new_expiry="$3"
    
    print_status "Rotating secret: $secret_name"
    
    # Create new version
    echo "$new_value" | gcloud secrets versions add "$secret_name" \
        --project="$PROJECT_ID" \
        --data-file="-"
    
    # Update expiration date
    update_secret_expiration "$secret_name" "$new_expiry"
    
    print_success "Rotated secret: $secret_name with new expiration: $new_expiry"
}

# Function to delete expired secrets (with confirmation)
cleanup_expired_secrets() {
    print_status "Checking for expired secrets to cleanup..."
    
    current_date=$(date +%s)
    expired_secrets=()
    
    secrets=$(gcloud secrets list --project="${PROJECT_ID}" --format="json")
    
    echo "$secrets" | jq -r '.[] | "\(.name)|\(.labels.expires_on // "no-expiry")"' | \
    while IFS='|' read -r secret_name expires_on; do
        if [ "$expires_on" != "no-expiry" ]; then
            expiry_timestamp=$(date -d "$expires_on" +%s 2>/dev/null || echo "0")
            
            if [ "$expiry_timestamp" -gt 0 ] && [ "$expiry_timestamp" -lt "$current_date" ]; then
                expired_secrets+=("$secret_name")
                print_warning "Found expired secret: $secret_name (expired on $expires_on)"
            fi
        fi
    done
    
    if [ ${#expired_secrets[@]} -gt 0 ]; then
        echo ""
        print_critical "Found ${#expired_secrets[@]} expired secrets!"
        echo "Expired secrets:"
        for secret in "${expired_secrets[@]}"; do
            echo "  - $secret"
        done
        echo ""
        
        read -p "Do you want to delete these expired secrets? (y/N): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for secret in "${expired_secrets[@]}"; do
                print_status "Deleting expired secret: $secret"
                gcloud secrets delete "$secret" --project="$PROJECT_ID" --quiet
                print_success "Deleted expired secret: $secret"
            done
        else
            print_status "Skipped deletion of expired secrets"
        fi
    else
        print_success "No expired secrets found for cleanup"
    fi
}

# Function to generate secret rotation schedule
generate_rotation_schedule() {
    print_status "Generating rotation schedule for all secrets..."
    
    schedule_file="/tmp/secret_rotation_schedule_$(date +%Y%m%d).json"
    
    secrets=$(gcloud secrets list --project="${PROJECT_ID}" --format="json")
    
    echo "$secrets" | jq '[
        .[] | {
            name: .name,
            expires_on: (.labels.expires_on // "no-expiry"),
            rotation_frequency: (.labels.rotation // "unknown"),
            criticality: (.labels.criticality // "unknown"),
            component: (.labels.component // "unknown"),
            next_rotation: (
                if .labels.rotation == "weekly" then 
                    (now + 604800 | strftime("%Y-%m-%d"))
                elif .labels.rotation == "monthly" then 
                    (now + 2592000 | strftime("%Y-%m-%d"))
                elif .labels.rotation == "quarterly" then 
                    (now + 7776000 | strftime("%Y-%m-%d"))
                elif .labels.rotation == "biannually" then 
                    (now + 15552000 | strftime("%Y-%m-%d"))
                elif .labels.rotation == "annually" then 
                    (now + 31536000 | strftime("%Y-%m-%d"))
                else 
                    "manual"
                end
            )
        }
    ]' > "$schedule_file"
    
    print_success "Rotation schedule saved to: $schedule_file"
    
    # Display summary
    echo ""
    echo "Rotation Schedule Summary:"
    echo "========================="
    jq -r '.[] | "\(.name) | \(.rotation_frequency) | Next: \(.next_rotation) | Expires: \(.expires_on)"' "$schedule_file" | \
    column -t -s '|' -N "Secret Name,Rotation,Next Rotation,Expiry Date"
}

# Function to show usage information
show_usage() {
    echo "Secret Manager Automation Script"
    echo "================================"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --list                List all secrets with metadata"
    echo "  --check-expiry        Check for expiring secrets"
    echo "  --create-samples      Create sample secrets with different expiration dates"
    echo "  --rotate SECRET_NAME  Rotate a specific secret"
    echo "  --cleanup-expired     Remove expired secrets (with confirmation)"
    echo "  --schedule            Generate rotation schedule"
    echo "  --help               Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  GCP_PROJECT_ID       Set the GCP project ID"
    echo "  ADMIN_EMAIL          Set the notification email address"
    echo ""
    echo "Examples:"
    echo "  $0 --check-expiry"
    echo "  $0 --create-samples"
    echo "  $0 --rotate my-secret-name"
    echo "  GCP_PROJECT_ID=my-project $0 --list"
}

# Function to create sample secrets for testing
create_sample_secrets() {
    print_status "Creating sample secrets with various expiration dates..."
    
    # Short-term secret (expires in 1 week)
    future_date_1week=$(date -d "+7 days" +%Y-%m-%d)
    create_sample_secret "test-short-term-secret" "testing" "low" "weekly" "$future_date_1week" '{"test": "short-term-value"}'
    
    # Medium-term secret (expires in 30 days)
    future_date_30days=$(date -d "+30 days" +%Y-%m-%d)
    create_sample_secret "test-medium-term-secret" "api" "medium" "monthly" "$future_date_30days" '{"api_key": "medium-term-api-key-123"}'
    
    # Long-term secret (expires in 1 year)
    future_date_1year=$(date -d "+1 year" +%Y-%m-%d)
    create_sample_secret "test-long-term-secret" "certificates" "high" "annually" "$future_date_1year" '{"cert": "long-term-certificate-data"}'
    
    # Already expired secret (for testing cleanup)
    past_date=$(date -d "-1 days" +%Y-%m-%d)
    create_sample_secret "test-expired-secret" "testing" "low" "manual" "$past_date" '{"expired": "this-secret-is-expired"}'
    
    print_success "Sample secrets created successfully!"
}

# Main script logic
main() {
    echo "🔐 Secret Manager Automation Tool"
    echo "================================="
    echo "Project: $PROJECT_ID"
    echo "Timestamp: $(date)"
    echo ""
    
    check_prerequisites
    
    case "${1:-}" in
        --list)
            list_secrets
            ;;
        --check-expiry)
            check_expiring_secrets
            ;;
        --create-samples)
            create_sample_secrets
            ;;
        --rotate)
            if [ -z "$2" ]; then
                print_error "Secret name required for rotation"
                echo "Usage: $0 --rotate SECRET_NAME"
                exit 1
            fi
            
            # Interactive rotation
            echo "Enter new secret value:"
            read -s new_value
            echo "Enter new expiration date (YYYY-MM-DD):"
            read new_expiry
            
            rotate_secret "$2" "$new_value" "$new_expiry"
            ;;
        --cleanup-expired)
            cleanup_expired_secrets
            ;;
        --schedule)
            generate_rotation_schedule
            ;;
        --help|*)
            show_usage
            ;;
    esac
    
    print_success "Secret management operation completed! 🔐"
}

# Run main function with all arguments
main "$@"