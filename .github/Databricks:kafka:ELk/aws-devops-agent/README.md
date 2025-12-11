# AWS DevOps Agent - Autonomous Investigation Platform

A comprehensive demonstration project showcasing AWS DevOps Agent capabilities for automated incident investigation and root-cause analysis in cloud infrastructure.

## Quick Start

```bash
# One-command setup
./scripts/setup-agent-space.sh

# Custom configuration
./scripts/setup-agent-space.sh --space-name "my-investigation-space" --region "us-west-2"

# Interactive demo
./scripts/demo-scenarios.sh
```

## Overview

This project demonstrates how AWS DevOps Agent can autonomously investigate and respond to infrastructure incidents through practical scenarios including CPU spikes, Kubernetes pod failures, and performance anomalies.

**Key Features:**
- Automated incident detection and response
- Multi-service correlation analysis
- Real-time performance monitoring
- Security-compliant IAM roles
- Kubernetes integration for container investigations
- CloudFormation-based demo scenarios

## 🏗️ Architecture

### AWS DevOps Agent Space Components

The project creates a complete Agent Space environment with specialized IAM roles:

- **Execution Role**: Core AWS service access for basic investigations
- **Investigation Role**: Advanced troubleshooting with read access to CloudTrail, Config, and billing
- **EKS Role**: Kubernetes cluster access for container-level investigations

### Security Model

All components follow AWS security best practices:
- Principle of least privilege access
- Resource-specific permissions with conditions
- Comprehensive audit logging
- Cross-account access controls

## Demo Scenarios

### 1. CPU Spike Investigation
**Scenario**: EC2 instance experiencing high CPU utilization
- Automated CloudWatch alarm triggers
- Agent analyzes CPU metrics and running processes
- Provides root-cause analysis and remediation recommendations

### 2. Kubernetes Pod Failure
**Scenario**: EKS pods failing to start due to ImagePullBackOff
- Agent examines pod events and container logs
- Analyzes image registry access and resource constraints
- Suggests specific remediation steps

### 3. Performance Anomaly Detection
**Scenario**: Application response time degradation
- Multi-metric correlation analysis
- Database and network performance investigation
- Optimization recommendations

## Project Structure

```
aws-devops-agent/
├── README.md                     # Project overview and quick start
├── DOCUMENTATION.md             # Comprehensive technical guide
├── scripts/                     # Automation and demo scripts
│   ├── setup-agent-space.sh     # Complete infrastructure setup
│   ├── cleanup-resources.sh     # Resource cleanup automation
│   └── demo-scenarios.sh        # Interactive demonstration
├── terraform/                   # Infrastructure as Code
│   ├── agent-iam-roles.tf      # IAM roles and policies
│   ├── variables.tf             # Configuration variables
│   ├── outputs.tf               # Resource identifiers
│   └── data.tf                  # AWS account/region data
├── cloudformation/              # Demo environment templates
│   └── cpu-spike-demo.yaml      # CPU spike investigation scenario
└── kubernetes/                  # EKS demonstration manifests
    └── failing-workload.yaml    # Pod failure investigation demo
```

## Prerequisites

- **AWS CLI**: Configured with appropriate permissions
- **Terraform**: >= 1.0 for infrastructure deployment
- **kubectl**: Optional, required for EKS demonstrations
- **Bash**: For automation scripts (macOS/Linux/WSL)

## Installation

### Automated Setup

```bash
# Clone and navigate to project
git clone <repository-url>
cd aws-devops-agent

# Run complete setup
./scripts/setup-agent-space.sh
```

### Manual Setup

```bash
# 1. Deploy IAM infrastructure
cd terraform
terraform init
terraform plan -var-file="demo.tfvars"
terraform apply

# 2. Deploy demo scenarios
aws cloudformation deploy --template-file ../cloudformation/cpu-spike-demo.yaml --stack-name cpu-demo

# 3. Configure kubectl (if using EKS)
aws eks update-kubeconfig --name devops-agent-demo-cluster
kubectl apply -f ../kubernetes/failing-workload.yaml
```

## Configuration

### Environment Variables

```bash
export AGENT_SPACE_NAME="devops-investigation-space"
export ENVIRONMENT="demo"
export AWS_REGION="us-east-1"
export EKS_CLUSTER_NAME="devops-agent-demo-cluster"
```

### Terraform Variables

Create `terraform/demo.tfvars`:

```hcl
agent_space_name = "production-investigations"
environment = "prod"
eks_cluster_name = "production-cluster"

tags = {
  Project = "AWS-DevOps-Agent"
  Team = "DevOps"
  CostCenter = "Engineering"
}
```

## Monitoring and Observability

### CloudWatch Integration
- CPU, memory, disk, and network metrics
- Application and system log aggregation
- Custom alarm configurations
- Dashboard creation for investigation insights

### Investigation Triggers
- CloudWatch alarm integrations
- SNS topic subscriptions for real-time notifications
- Custom webhook endpoints for external system integration
- Automated incident detection patterns

## Testing and Validation

### CPU Spike Demo
```bash
# Trigger CPU spike on demo instance
aws ssm send-command \
  --instance-ids <instance-id> \
  --document-name 'AWS-RunShellScript' \
  --parameters 'commands=["/home/ec2-user/create_cpu_spike.sh"]'
```

### Kubernetes Demo Monitoring
```bash
# Watch pod failures
kubectl get pods -n devops-agent-demo -w

# Analyze failure events
kubectl describe pods -n devops-agent-demo
kubectl get events -n devops-agent-demo --sort-by='.lastTimestamp'
```

## Cost Optimization

**Estimated Monthly Costs** (us-east-1):
- EC2 t3.micro: ~$8.50
- CloudWatch metrics: ~$0.30
- EKS cluster: ~$73 (if deployed)
- Data transfer: ~$0.09/GB

**Cost-Saving Features:**
- Automatic resource cleanup scripts
- Minimal instance sizing for demos
- Resource tagging for cost tracking
- Regional optimization recommendations

## Security Considerations

### IAM Best Practices
- Least privilege access principles
- Resource-specific ARN patterns
- Condition-based access controls
- Regular permission auditing capabilities

### Network Security
- VPC isolation for demo resources
- Security group minimal access rules
- Private subnet deployment options
- Network ACL configurations

### Data Protection
- EBS volume encryption at rest
- TLS encryption for data in transit
- CloudTrail comprehensive audit logging
- SSM Parameter Store for secrets

## Integration Examples

### CI/CD Pipeline Integration
```yaml
# GitHub Actions example
- name: Trigger AWS DevOps Agent Investigation
  run: |
    aws devops-agent start-investigation \
      --space-name ${{ env.AGENT_SPACE_NAME }} \
      --trigger-type "deployment-failure" \
      --context "Build ${{ github.run_number }} failed"
```

### Slack Notification Integration
```bash
# Configure Slack webhook for investigation results
aws sns subscribe \
  --topic-arn arn:aws:sns:region:account:agent-investigations \
  --protocol https \
  --notification-endpoint https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

## Documentation

- **[DOCUMENTATION.md](DOCUMENTATION.md)**: Comprehensive technical guide
- **[scripts/demo-scenarios.sh](scripts/demo-scenarios.sh)**: Interactive demonstration walkthrough
- **AWS DevOps Agent Official Docs**: [AWS Documentation](https://docs.aws.amazon.com/devops-agent/)

## Cleanup

### Complete Resource Removal
```bash
# Remove all resources and configurations
./scripts/cleanup-resources.sh

# Selective cleanup
./scripts/cleanup-resources.sh --skip-terraform
```

### Manual Cleanup Verification
```bash
# Check for remaining resources
aws cloudformation list-stacks --stack-status-filter DELETE_COMPLETE
aws iam list-roles --query "Roles[?contains(RoleName, 'DevOpsAgent')]"
kubectl get namespaces | grep devops-agent
```

## Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/amazing-investigation`
3. **Commit changes**: `git commit -m 'Add amazing investigation capability'`
4. **Push to branch**: `git push origin feature/amazing-investigation`
5. **Submit pull request** with comprehensive description

### Development Guidelines
- Follow existing code style and structure
- Include comprehensive documentation updates
- Add appropriate error handling and logging
- Test across multiple AWS regions
- Update relevant configuration examples

## Support

### Getting Help
- Review troubleshooting section in [DOCUMENTATION.md](DOCUMENTATION.md)
- Check AWS DevOps Agent service documentation
- Examine CloudWatch logs for detailed error information
- Verify IAM permissions and resource configurations

### Common Issues
- **AWS Credentials**: Ensure proper AWS CLI configuration
- **Terraform State**: Use `terraform refresh` for state synchronization
- **EKS Access**: Update kubeconfig with `aws eks update-kubeconfig`
- **Permissions**: Review IAM policies for sufficient access

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Tags

`aws` `devops` `automation` `infrastructure` `monitoring` `incident-response` `terraform` `cloudformation` `kubernetes` `observability`

---

**Built for AWS DevOps Agent demonstrations and learning**