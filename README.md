# Threat Intelligence ETL Pipeline

A Python-based threat intelligence ETL (Extract, Transform, Load) pipeline that ingests STIX/TAXII indicators, normalizes them, enriches them with contextual data, and stores them for analysis. This project provides a lightweight CLI for security analysts to fetch threat data, search for IOCs (Indicators of Compromise), and export results with simple commands.

## Features

- 🔄 **STIX/TAXII Ingestion**: Automatically fetch threat intelligence from TAXII 2.1 servers
- 🔧 **Normalization**: Standardize indicators from multiple sources into a consistent format
- 🎯 **Enrichment**: Enhance indicators with additional context, risk scores, and metadata
- 💾 **SQLite Storage**: Lightweight database for storing and querying indicators
- 🖥️ **CLI Interface**: Simple command-line tools for analysts
- 📊 **Daily Analysis**: Generate statistics and insights about threat landscape
- 📤 **Export**: Export indicators in JSON, CSV, or STIX formats

## Architecture

```
threat_intel/
├── ingestion/      # STIX/TAXII data fetching
├── normalization/  # Indicator standardization
├── enrichment/     # Context and risk scoring
├── storage/        # SQLite database operations
└── cli.py          # Command-line interface
```

## Installation

### Prerequisites

- Python 3.8 or higher
- pip package manager

### Setup

1. Clone the repository:
```bash
git clone https://github.com/leonix33/Threat-detection-pipeline-.git
cd Threat-detection-pipeline-
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Install the package:
```bash
pip install -e .
```

## Usage

The CLI provides several commands for working with threat intelligence data:

### 1. Fetch Indicators

Fetch threat intelligence from configured TAXII servers:

```bash
# Fetch indicators from the last 7 days
threat-intel fetch

# Fetch from a specific server
threat-intel fetch --server mitre_attack

# Fetch from the last 30 days with custom limit
threat-intel fetch --days 30 --limit 5000
```

### 2. Search for IOCs

Search your local database for specific indicators:

```bash
# Search for a specific IOC value
threat-intel search --ioc "192.168.1.1"

# Filter by type
threat-intel search --type ipv4

# Search with minimum confidence threshold
threat-intel search --confidence 70 --limit 100

# Output as JSON
threat-intel search --type domain --format json

# Output as CSV
threat-intel search --source mitre_attack --format csv
```

### 3. Export Data

Export indicators to a file:

```bash
# Export to JSON
threat-intel export --output indicators.json --format json

# Export to CSV with filters
threat-intel export --output high_confidence.csv --format csv --confidence 80

# Export as STIX bundle
threat-intel export --output bundle.json --format stix --type indicator
```

### 4. Analyze Indicators

Generate daily analysis and statistics:

```bash
# Run analysis
threat-intel analyze

# Analyze specific time period
threat-intel analyze --days 7
```

### 5. View Statistics

Display database statistics:

```bash
threat-intel stats
```

## Configuration

### Default Configuration

The default configuration is located in `config/default.yaml`. It includes:

- TAXII server configurations (MITRE ATT&CK by default)
- Database settings
- Enrichment options
- Analysis parameters

### Custom Configuration

Create a local configuration file to override defaults:

1. Copy the default config:
```bash
cp config/default.yaml config/local.yaml
```

2. Edit `config/local.yaml` with your settings

3. Use custom config:
```bash
threat-intel --config config/local.yaml fetch
```

### Environment Variables

Sensitive data can be set via environment variables:

```bash
export TAXII_USERNAME="your_username"
export TAXII_PASSWORD="your_password"
export THREAT_INTEL_DB_PATH="custom_path.db"
```

## Supported IOC Types

The pipeline automatically detects and classifies various IOC types:

- **Network**: IPv4, IPv6, domains, URLs
- **File Hashes**: MD5, SHA1, SHA256
- **Email**: Email addresses
- **Vulnerabilities**: CVE identifiers
- **STIX Objects**: Indicators, attack patterns, malware, threat actors

## Data Sources

### Default TAXII Server

- **MITRE ATT&CK**: Public TAXII 2.1 server with enterprise attack patterns
  - URL: https://cti-taxii.mitre.org/taxii/

### Adding Custom Sources

Edit `config/local.yaml` to add additional TAXII servers:

```yaml
taxii_servers:
  - name: "custom_feed"
    url: "https://your-taxii-server.com/taxii/"
    api_root: "api1"
    collections:
      - "threat-intel"
    discovery_url: "https://your-taxii-server.com/taxii/"
    enabled: true
    auth_required: false
```

## Examples

### Daily Threat Intelligence Workflow

```bash
# Morning: Fetch latest indicators
threat-intel fetch --days 1

# Search for specific threats
threat-intel search --type ipv4 --confidence 80

# Export high-confidence indicators for sharing
threat-intel export --output daily_iocs.json --format json --confidence 75

# Generate daily analysis report
threat-intel analyze
```

### Investigate a Specific IOC

```bash
# Search for domain
threat-intel search --ioc "malicious-domain.com" --format table

# Get detailed JSON output
threat-intel search --ioc "malicious-domain.com" --format json
```

### Bulk Export for SIEM Integration

```bash
# Export all indicators as CSV for SIEM
threat-intel export --output all_indicators.csv --format csv --limit 10000

# Export only high-confidence IOCs as STIX
threat-intel export --output high_conf.json --format stix --confidence 85
```

## ETL Pipeline Details

### 1. Ingestion (Extract)
- Connects to TAXII 2.1 servers
- Authenticates if required
- Fetches STIX 2.1 objects
- Supports pagination and filtering

### 2. Normalization (Transform)
- Parses STIX objects
- Extracts IOCs from patterns
- Classifies indicator types
- Standardizes formats (lowercase hashes, normalized domains)
- Removes duplicates

### 3. Enrichment (Transform)
- Adds risk scores
- Performs IP analysis (public/private detection)
- Domain reputation checks
- URL pattern analysis
- CVE metadata extraction
- Contextual tagging

### 4. Storage (Load)
- Stores in SQLite database
- Indexes for fast searching
- Maintains relationships between indicators and enrichments
- Tracks analysis history

## Database Schema

### Indicators Table
- Core indicator data (value, type, source)
- Confidence and severity scores
- Temporal data (first seen, last seen)
- STIX metadata

### Enrichments Table
- Links to indicators
- Enrichment type and data
- Multiple enrichments per indicator

### Analysis Results Table
- Historical analysis records
- Aggregated statistics
- Trend tracking

## Development

### Project Structure

```
Threat-detection-pipeline-/
├── config/
│   └── default.yaml          # Default configuration
├── threat_intel/
│   ├── __init__.py
│   ├── cli.py                # CLI interface
│   ├── config.py             # Configuration management
│   ├── ingestion/
│   │   ├── __init__.py
│   │   └── taxii_client.py   # TAXII client
│   ├── normalization/
│   │   ├── __init__.py
│   │   └── normalizer.py     # Indicator normalization
│   ├── enrichment/
│   │   ├── __init__.py
│   │   └── enricher.py       # Indicator enrichment
│   └── storage/
│       ├── __init__.py
│       └── database.py       # SQLite operations
├── requirements.txt
├── setup.py
└── README.md
```

### Running Tests

```bash
# Install dev dependencies
pip install pytest pytest-cov

# Run tests (when available)
pytest
```

## Use Cases

This pipeline reflects real-world cybersecurity R&D workflows:

1. **Threat Hunting**: Search for specific IOCs across your threat intelligence database
2. **Daily Briefings**: Generate analysis reports on new threats
3. **SIEM Integration**: Export indicators for integration with security tools
4. **Incident Response**: Quickly lookup IOCs during investigations
5. **Threat Intelligence Sharing**: Export indicators in standard formats (STIX)

## Limitations & Future Enhancements

Current limitations:
- SQLite database (suitable for small-medium deployments)
- Basic enrichment (can integrate external APIs)
- No real-time monitoring

Potential enhancements:
- PostgreSQL/MySQL support for larger deployments
- Integration with VirusTotal, AbuseIPDB, etc.
- Real-time indicator matching
- Web dashboard
- Automated threat reports
- Machine learning-based threat scoring

## Security Considerations

- Store credentials in environment variables, not in config files
- Use HTTPS for TAXII connections
- Regularly update indicators
- Validate data sources
- Implement proper access controls for production deployments

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Contact

For questions or issues, please open an issue on GitHub.

## Acknowledgments

- MITRE ATT&CK for providing public threat intelligence
- OASIS for STIX/TAXII standards
- The open-source security community
