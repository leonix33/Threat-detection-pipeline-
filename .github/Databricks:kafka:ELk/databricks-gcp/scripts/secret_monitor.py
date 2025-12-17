#!/usr/bin/env python3
"""
Cloud Function for automated secret expiration monitoring and alerting.
Triggered by Cloud Scheduler to run daily checks.
"""

import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Tuple
import os

from google.cloud import secretmanager
from google.cloud import monitoring_v3
from google.cloud import pubsub_v1
import smtplib
from email.mime.text import MimeText
from email.mime.multipart import MimeMultipart

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SecretExpirationMonitor:
    """Automated secret expiration monitoring and alerting system"""
    
    def __init__(self, project_id: str):
        self.project_id = project_id
        self.secret_client = secretmanager.SecretManagerServiceClient()
        self.monitoring_client = monitoring_v3.MetricServiceClient()
        self.publisher = pubsub_v1.PublisherClient()
        
        # Configuration
        self.warning_days = int(os.getenv('WARNING_DAYS', '30'))
        self.critical_days = int(os.getenv('CRITICAL_DAYS', '7'))
        self.notification_topic = os.getenv('NOTIFICATION_TOPIC', 
                                          f'projects/{project_id}/topics/secret-expiration-alerts')
        
    def get_all_secrets(self) -> List[Dict]:
        """Retrieve all secrets with their metadata"""
        parent = f"projects/{self.project_id}"
        secrets = []
        
        try:
            for secret in self.secret_client.list_secrets(request={"parent": parent}):
                secret_info = {
                    'name': secret.name.split('/')[-1],
                    'full_name': secret.name,
                    'labels': dict(secret.labels) if secret.labels else {},
                    'create_time': secret.create_time,
                }
                secrets.append(secret_info)
                
            logger.info(f"Retrieved {len(secrets)} secrets")
            return secrets
            
        except Exception as e:
            logger.error(f"Error retrieving secrets: {e}")
            return []
    
    def parse_expiry_date(self, date_string: str) -> datetime:
        """Parse expiry date from string"""
        try:
            return datetime.strptime(date_string, '%Y-%m-%d')
        except ValueError:
            # Try alternative formats
            try:
                return datetime.strptime(date_string, '%Y/%m/%d')
            except ValueError:
                logger.warning(f"Unable to parse date: {date_string}")
                return None
    
    def check_expiring_secrets(self) -> Tuple[List[Dict], List[Dict]]:
        """Check for expiring and critical secrets"""
        secrets = self.get_all_secrets()
        now = datetime.now()
        warning_date = now + timedelta(days=self.warning_days)
        critical_date = now + timedelta(days=self.critical_days)
        
        expiring_secrets = []
        critical_secrets = []
        
        for secret in secrets:
            expires_on = secret['labels'].get('expires_on')
            if not expires_on or expires_on == 'no-expiry':
                continue
                
            expiry_date = self.parse_expiry_date(expires_on)
            if not expiry_date:
                continue
                
            days_until_expiry = (expiry_date - now).days
            
            secret_info = {
                **secret,
                'expiry_date': expiry_date,
                'days_until_expiry': days_until_expiry
            }
            
            if expiry_date <= critical_date:
                critical_secrets.append(secret_info)
                logger.warning(f"Critical: {secret['name']} expires in {days_until_expiry} days")
            elif expiry_date <= warning_date:
                expiring_secrets.append(secret_info)
                logger.info(f"Warning: {secret['name']} expires in {days_until_expiry} days")
        
        return expiring_secrets, critical_secrets
    
    def send_pubsub_notification(self, message: Dict):
        """Send notification via Pub/Sub"""
        try:
            message_json = json.dumps(message)
            future = self.publisher.publish(
                self.notification_topic, 
                message_json.encode('utf-8')
            )
            logger.info(f"Published message: {future.result()}")
        except Exception as e:
            logger.error(f"Error publishing to Pub/Sub: {e}")
    
    def generate_alert_message(self, expiring_secrets: List[Dict], 
                             critical_secrets: List[Dict]) -> Dict:
        """Generate structured alert message"""
        return {
            'timestamp': datetime.now().isoformat(),
            'project_id': self.project_id,
            'summary': {
                'critical_count': len(critical_secrets),
                'warning_count': len(expiring_secrets),
                'total_alerts': len(critical_secrets) + len(expiring_secrets)
            },
            'critical_secrets': [
                {
                    'name': s['name'],
                    'component': s['labels'].get('component', 'unknown'),
                    'criticality': s['labels'].get('criticality', 'unknown'),
                    'expiry_date': s['expiry_date'].isoformat(),
                    'days_until_expiry': s['days_until_expiry']
                }
                for s in critical_secrets
            ],
            'warning_secrets': [
                {
                    'name': s['name'],
                    'component': s['labels'].get('component', 'unknown'),
                    'criticality': s['labels'].get('criticality', 'unknown'),
                    'expiry_date': s['expiry_date'].isoformat(),
                    'days_until_expiry': s['days_until_expiry']
                }
                for s in expiring_secrets
            ]
        }
    
    def create_custom_metrics(self, critical_count: int, warning_count: int):
        """Create custom metrics for monitoring dashboard"""
        try:
            project_name = f"projects/{self.project_id}"
            
            # Create time series for critical secrets
            series = monitoring_v3.TimeSeries()
            series.metric.type = "custom.googleapis.com/secret_manager/critical_expiring_secrets"
            series.resource.type = "global"
            
            now = datetime.now()
            seconds = int(now.timestamp())
            nanos = int((now.timestamp() % 1) * 10**9)
            
            point = monitoring_v3.Point()
            point.value.int64_value = critical_count
            point.interval.end_time.seconds = seconds
            point.interval.end_time.nanos = nanos
            
            series.points = [point]
            
            self.monitoring_client.create_time_series(
                name=project_name,
                time_series=[series]
            )
            
            # Create time series for warning secrets
            series_warning = monitoring_v3.TimeSeries()
            series_warning.metric.type = "custom.googleapis.com/secret_manager/warning_expiring_secrets"
            series_warning.resource.type = "global"
            
            point_warning = monitoring_v3.Point()
            point_warning.value.int64_value = warning_count
            point_warning.interval.end_time.seconds = seconds
            point_warning.interval.end_time.nanos = nanos
            
            series_warning.points = [point_warning]
            
            self.monitoring_client.create_time_series(
                name=project_name,
                time_series=[series_warning]
            )
            
            logger.info(f"Created custom metrics: critical={critical_count}, warning={warning_count}")
            
        except Exception as e:
            logger.error(f"Error creating custom metrics: {e}")
    
    def run_monitoring_check(self):
        """Main monitoring function"""
        logger.info("Starting secret expiration monitoring check")
        
        expiring_secrets, critical_secrets = self.check_expiring_secrets()
        
        if critical_secrets or expiring_secrets:
            alert_message = self.generate_alert_message(expiring_secrets, critical_secrets)
            
            # Send Pub/Sub notification
            self.send_pubsub_notification(alert_message)
            
            # Create custom metrics
            self.create_custom_metrics(len(critical_secrets), len(expiring_secrets))
            
            logger.info(f"Sent alerts for {len(critical_secrets)} critical and {len(expiring_secrets)} warning secrets")
        else:
            logger.info("No expiring secrets found")
            # Still create metrics with zero values
            self.create_custom_metrics(0, 0)


def cloud_function_entry_point(event, context):
    """Cloud Function entry point for scheduled execution"""
    project_id = os.getenv('GCP_PROJECT_ID')
    if not project_id:
        logger.error("GCP_PROJECT_ID environment variable not set")
        return
    
    monitor = SecretExpirationMonitor(project_id)
    monitor.run_monitoring_check()
    
    return {
        'status': 'success',
        'timestamp': datetime.now().isoformat(),
        'project_id': project_id
    }


def main():
    """Main function for local testing"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Secret Manager Expiration Monitor')
    parser.add_argument('--project-id', required=True, help='GCP Project ID')
    parser.add_argument('--warning-days', type=int, default=30, help='Warning threshold in days')
    parser.add_argument('--critical-days', type=int, default=7, help='Critical threshold in days')
    
    args = parser.parse_args()
    
    # Set environment variables
    os.environ['GCP_PROJECT_ID'] = args.project_id
    os.environ['WARNING_DAYS'] = str(args.warning_days)
    os.environ['CRITICAL_DAYS'] = str(args.critical_days)
    
    monitor = SecretExpirationMonitor(args.project_id)
    monitor.run_monitoring_check()


if __name__ == '__main__':
    main()