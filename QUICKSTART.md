# Quick Start Guide

## Installation

```bash
# Clone the repository
git clone https://github.com/leonix33/Threat-detection-pipeline-.git
cd Threat-detection-pipeline-

# Install dependencies
pip install -r requirements.txt

# Install the package
pip install -e .
```

## First Steps

### 1. Run the Demo

```bash
python demo.py
```

This demonstrates the ETL pipeline with mock data.

### 2. Fetch Real Threat Intelligence

```bash
# Fetch from MITRE ATT&CK (default)
threat-intel fetch --days 7 --limit 500

# This will:
# - Connect to MITRE's TAXII server
# - Download threat indicators
# - Normalize them
# - Enrich with context
# - Store in local database
```

### 3. Search for Indicators

```bash
# Search for all indicators with high confidence
threat-intel search --confidence 80

# Search for specific IOC
threat-intel search --ioc "192.168"

# Filter by type
threat-intel search --type domain --limit 20

# Export results
threat-intel search --type ipv4 --format csv > ips.csv
```

### 4. Analyze Your Data

```bash
# Generate analysis report
threat-intel analyze

# Shows statistics by:
# - Indicator type
# - Source
# - Severity
# - Confidence
```

### 5. Export Data

```bash
# Export to JSON
threat-intel export --output indicators.json --format json

# Export high-confidence IOCs to CSV
threat-intel export --output high_conf.csv --format csv --confidence 85

# Export as STIX bundle
threat-intel export --output bundle.json --format stix
```

## Configuration

### Using Default Configuration

The default config (`config/default.yaml`) includes MITRE ATT&CK.

### Custom Configuration

```bash
# Copy example config
cp config/example.yaml config/local.yaml

# Edit with your settings
nano config/local.yaml

# Use custom config
threat-intel --config config/local.yaml fetch
```

### Environment Variables

For sensitive data (API keys, passwords):

```bash
export TAXII_USERNAME="your_username"
export TAXII_PASSWORD="your_password"
export THREAT_INTEL_DB_PATH="/path/to/custom.db"
```

## Common Use Cases

### Daily Threat Intelligence Update

```bash
#!/bin/bash
# daily_update.sh

# Fetch latest indicators
threat-intel fetch --days 1

# Run analysis
threat-intel analyze

# Export high-priority IOCs
threat-intel export \
  --output daily_iocs_$(date +%Y%m%d).json \
  --format json \
  --confidence 75
```

### Incident Response - IOC Lookup

```bash
# Check if an IP is in your threat database
threat-intel search --ioc "203.0.113.42"

# Check a domain
threat-intel search --ioc "suspicious-domain.com"

# Get detailed JSON output
threat-intel search --ioc "malware.exe" --format json
```

### Integration with SIEM

```bash
# Export all IOCs for SIEM ingestion
threat-intel export \
  --output siem_feed.csv \
  --format csv \
  --limit 50000

# Export only recent high-confidence indicators
threat-intel search \
  --confidence 80 \
  --format csv \
  --limit 10000 > recent_threats.csv
```

### Threat Hunting

```bash
# Find all malware-related indicators
threat-intel search --ioc "malware" --limit 100

# Find recent high-severity threats
threat-intel search --confidence 75 --limit 50

# Export for analysis
threat-intel export --output hunt_results.json --format json --confidence 70
```

## Troubleshooting

### Database not initialized

```bash
# Error: Database not initialized
# Solution: Run fetch first
threat-intel fetch
```

### TAXII connection fails

```bash
# Check your internet connection
# Verify TAXII server URL in config
# Check authentication credentials
```

### No indicators fetched

```bash
# Try increasing the time range
threat-intel fetch --days 30

# Check if server is enabled in config
# Verify collection names are correct
```

## Development

### Project Structure

```
threat_intel/
├── ingestion/      # TAXII/STIX data fetching
├── normalization/  # Indicator standardization
├── enrichment/     # Context and risk scoring
├── storage/        # Database operations
└── cli.py          # Command-line interface
```

### Adding Custom Enrichment

Edit `threat_intel/enrichment/enricher.py` to add custom enrichment logic.

### Adding New IOC Types

Edit `threat_intel/normalization/normalizer.py` to add detection patterns.

## Tips

1. **Start Small**: Use `--limit` parameter when testing
2. **Filter Results**: Use confidence and type filters to narrow searches
3. **Regular Updates**: Schedule daily fetches for fresh intelligence
4. **Export Often**: Keep backups of your indicator database
5. **Monitor Stats**: Run `threat-intel stats` regularly

## Getting Help

```bash
# Main help
threat-intel --help

# Command-specific help
threat-intel fetch --help
threat-intel search --help
threat-intel export --help
threat-intel analyze --help
```
