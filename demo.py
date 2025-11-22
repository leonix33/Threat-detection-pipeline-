#!/usr/bin/env python3
"""
Demo script to showcase the threat intelligence pipeline functionality.
This script simulates fetching indicators and demonstrates the ETL process.
"""

import sys
import json
from datetime import datetime, timedelta
from pathlib import Path

# Add the package to path
sys.path.insert(0, str(Path(__file__).parent))

from threat_intel.storage import ThreatIntelDB
from threat_intel.normalization import normalize_indicators
from threat_intel.enrichment import enrich_indicators
from threat_intel.config import get_config

# Mock STIX indicators (simulating what would come from TAXII)
MOCK_INDICATORS = [
    {
        'indicator_id': 'indicator--01234567-89ab-cdef-0123-456789abcdef',
        'type': 'indicator',
        'value': '192.168.1.100',
        'pattern': "[ipv4-addr:value = '192.168.1.100']",
        'source': 'demo_feed',
        'description': 'Malicious IP address associated with botnet C2',
        'labels': ['malicious-activity', 'botnet'],
        'confidence': 85,
        'severity': 'high',
        'first_seen': datetime.now().isoformat(),
        'last_seen': datetime.now().isoformat(),
        'valid_from': datetime.now().isoformat(),
        'raw_data': {}
    },
    {
        'indicator_id': 'indicator--11234567-89ab-cdef-0123-456789abcdef',
        'type': 'indicator',
        'value': 'malicious-domain.com',
        'pattern': "[domain-name:value = 'malicious-domain.com']",
        'source': 'demo_feed',
        'description': 'Phishing domain targeting financial institutions',
        'labels': ['phishing', 'credential-theft'],
        'confidence': 90,
        'severity': 'high',
        'first_seen': (datetime.now() - timedelta(days=2)).isoformat(),
        'last_seen': datetime.now().isoformat(),
        'valid_from': (datetime.now() - timedelta(days=2)).isoformat(),
        'raw_data': {}
    },
    {
        'indicator_id': 'indicator--21234567-89ab-cdef-0123-456789abcdef',
        'type': 'indicator',
        'value': 'http://evil-site.net/payload.exe',
        'pattern': "[url:value = 'http://evil-site.net/payload.exe']",
        'source': 'demo_feed',
        'description': 'Malware download URL',
        'labels': ['malware-distribution'],
        'confidence': 75,
        'severity': 'medium',
        'first_seen': (datetime.now() - timedelta(days=1)).isoformat(),
        'last_seen': datetime.now().isoformat(),
        'valid_from': (datetime.now() - timedelta(days=1)).isoformat(),
        'raw_data': {}
    },
    {
        'indicator_id': 'indicator--31234567-89ab-cdef-0123-456789abcdef',
        'type': 'indicator',
        'value': 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6',
        'pattern': "[file:hashes.MD5 = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6']",
        'source': 'demo_feed',
        'description': 'Ransomware binary MD5 hash',
        'labels': ['ransomware', 'malware'],
        'confidence': 95,
        'severity': 'high',
        'first_seen': (datetime.now() - timedelta(days=3)).isoformat(),
        'last_seen': datetime.now().isoformat(),
        'valid_from': (datetime.now() - timedelta(days=3)).isoformat(),
        'raw_data': {}
    },
    {
        'indicator_id': 'indicator--41234567-89ab-cdef-0123-456789abcdef',
        'type': 'attack-pattern',
        'value': 'Spearphishing Attachment',
        'pattern': None,
        'source': 'demo_feed',
        'description': 'T1566.001 - Adversaries may send spearphishing emails with a malicious attachment',
        'labels': ['initial-access'],
        'confidence': 70,
        'severity': 'medium',
        'first_seen': (datetime.now() - timedelta(days=5)).isoformat(),
        'last_seen': datetime.now().isoformat(),
        'valid_from': (datetime.now() - timedelta(days=5)).isoformat(),
        'raw_data': {}
    },
    {
        'indicator_id': 'indicator--51234567-89ab-cdef-0123-456789abcdef',
        'type': 'indicator',
        'value': '10.0.0.50',
        'pattern': "[ipv4-addr:value = '10.0.0.50']",
        'source': 'demo_feed',
        'description': 'Internal IP showing lateral movement behavior',
        'labels': ['lateral-movement', 'internal-threat'],
        'confidence': 60,
        'severity': 'medium',
        'first_seen': datetime.now().isoformat(),
        'last_seen': datetime.now().isoformat(),
        'valid_from': datetime.now().isoformat(),
        'raw_data': {}
    },
]


def main():
    print("=" * 70)
    print("THREAT INTELLIGENCE ETL PIPELINE DEMO")
    print("=" * 70)
    print()
    
    # Get configuration
    config = get_config()
    db_path = config.get_db_path()
    
    print(f"📁 Database: {db_path}")
    print(f"📊 Mock indicators to process: {len(MOCK_INDICATORS)}")
    print()
    
    # Step 1: Normalization
    print("🔧 Step 1: NORMALIZING indicators...")
    print("-" * 70)
    normalized = normalize_indicators(MOCK_INDICATORS)
    print(f"✓ Normalized {len(normalized)} indicators")
    print(f"  Sample normalized indicator:")
    sample = normalized[0]
    print(f"    - Type: {sample.get('ioc_type', sample.get('type'))}")
    print(f"    - Value: {sample.get('value')}")
    print(f"    - Confidence: {sample.get('confidence')}")
    print(f"    - Severity: {sample.get('severity')}")
    print()
    
    # Step 2: Enrichment
    print("✨ Step 2: ENRICHING indicators...")
    print("-" * 70)
    enriched = enrich_indicators(normalized)
    print(f"✓ Enriched {len(enriched)} indicators")
    
    # Show enrichment examples
    for indicator in enriched[:3]:
        print(f"\n  📌 {indicator.get('value')}")
        print(f"     Risk Score: {indicator.get('risk_score')}")
        print(f"     Risk Level: {indicator.get('risk_level')}")
        if indicator.get('enrichments'):
            for enr in indicator['enrichments']:
                print(f"     Enrichment: {enr.get('type')} - {enr.get('data', {}).get('note', 'N/A')}")
    print()
    
    # Step 3: Storage
    print("💾 Step 3: STORING indicators in database...")
    print("-" * 70)
    db = ThreatIntelDB(db_path)
    
    stored_count = 0
    for indicator in enriched:
        try:
            db.insert_indicator(indicator)
            stored_count += 1
            
            # Store enrichments
            if indicator.get('enrichments'):
                for enrichment in indicator['enrichments']:
                    db.insert_enrichment(
                        indicator['indicator_id'],
                        enrichment.get('type', 'unknown'),
                        enrichment.get('data', {})
                    )
        except Exception as e:
            print(f"  ⚠ Error storing indicator: {e}")
    
    print(f"✓ Stored {stored_count} indicators in database")
    print()
    
    # Step 4: Statistics
    print("📊 Step 4: DATABASE STATISTICS")
    print("-" * 70)
    stats = db.get_statistics()
    print(f"Total indicators: {stats['total_indicators']}")
    
    if stats['by_type']:
        print(f"\nBy type:")
        for ioc_type, count in sorted(stats['by_type'].items(), key=lambda x: x[1], reverse=True):
            print(f"  • {ioc_type}: {count}")
    
    if stats['by_source']:
        print(f"\nBy source:")
        for source, count in sorted(stats['by_source'].items(), key=lambda x: x[1], reverse=True):
            print(f"  • {source}: {count}")
    print()
    
    # Step 5: Search examples
    print("🔍 Step 5: SEARCH EXAMPLES")
    print("-" * 70)
    
    # Search for high-confidence indicators
    high_conf = db.search_indicators(min_confidence=80, limit=10)
    print(f"High-confidence indicators (≥80): {len(high_conf)}")
    for ind in high_conf[:3]:
        print(f"  • {ind.get('value')} ({ind.get('type')}) - Confidence: {ind.get('confidence')}")
    print()
    
    # Search for specific IOC type
    domains = db.search_indicators(ioc_type='domain', limit=10)
    print(f"Domain indicators: {len(domains)}")
    for ind in domains:
        print(f"  • {ind.get('value')} - Severity: {ind.get('severity')}")
    print()
    
    # Search for private IPs
    private_ips = db.search_indicators(ioc_value='10.0', limit=10)
    print(f"Private IP indicators (10.0.x.x): {len(private_ips)}")
    for ind in private_ips:
        print(f"  • {ind.get('value')} - {ind.get('description')}")
    print()
    
    print("=" * 70)
    print("✅ DEMO COMPLETE!")
    print("=" * 70)
    print()
    print("Try these CLI commands:")
    print("  threat-intel search --confidence 80")
    print("  threat-intel search --type domain")
    print("  threat-intel analyze")
    print("  threat-intel export --output demo_export.json --format json")
    print()


if __name__ == '__main__':
    main()
