"""Command-line interface for the threat intelligence pipeline."""

import click
import json
import csv
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional
import logging
from tabulate import tabulate
from colorama import init, Fore, Style

# Initialize colorama for cross-platform colored output
init(autoreset=True)

from threat_intel.config import get_config
from threat_intel.storage import ThreatIntelDB
from threat_intel.ingestion import fetch_from_all_servers
from threat_intel.normalization import normalize_indicators
from threat_intel.enrichment import enrich_indicators

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@click.group()
@click.option('--config', type=click.Path(exists=True), help='Path to custom config file')
@click.pass_context
def cli(ctx, config):
    """
    Threat Intelligence ETL Pipeline CLI
    
    A comprehensive tool for ingesting, analyzing, and managing threat intelligence
    indicators from STIX/TAXII sources.
    """
    ctx.ensure_object(dict)
    ctx.obj['config'] = get_config(config)


@cli.command()
@click.option('--days', default=7, help='Number of days to look back (default: 7)')
@click.option('--server', help='Specific server name to fetch from')
@click.option('--collection', help='Specific collection to fetch from')
@click.option('--limit', default=1000, help='Maximum indicators to fetch (default: 1000)')
@click.pass_context
def fetch(ctx, days, server, collection, limit):
    """
    Fetch threat intelligence indicators from TAXII servers.
    
    This command ingests indicators from configured TAXII servers, normalizes them,
    enriches them with additional context, and stores them in the local database.
    """
    click.echo(f"{Fore.CYAN}=== Threat Intelligence Fetch ==={Style.RESET_ALL}\n")
    
    config = ctx.obj['config']
    
    # Get TAXII servers
    servers = config.get_taxii_servers()
    
    if server:
        servers = [s for s in servers if s['name'] == server]
        if not servers:
            click.echo(f"{Fore.RED}Error: Server '{server}' not found{Style.RESET_ALL}")
            return
    
    if not servers:
        click.echo(f"{Fore.YELLOW}No TAXII servers configured{Style.RESET_ALL}")
        return
    
    click.echo(f"Fetching from {len(servers)} server(s)...\n")
    
    # Calculate lookback date
    added_after = datetime.now() - timedelta(days=days)
    
    # Fetch indicators
    click.echo(f"{Fore.YELLOW}Ingesting indicators...{Style.RESET_ALL}")
    indicators = fetch_from_all_servers(servers, added_after=added_after)
    click.echo(f"Fetched {len(indicators)} raw indicators\n")
    
    if not indicators:
        click.echo(f"{Fore.YELLOW}No indicators fetched{Style.RESET_ALL}")
        return
    
    # Normalize indicators
    click.echo(f"{Fore.YELLOW}Normalizing indicators...{Style.RESET_ALL}")
    normalized = normalize_indicators(indicators)
    click.echo(f"Normalized to {len(normalized)} unique indicators\n")
    
    # Enrich indicators
    click.echo(f"{Fore.YELLOW}Enriching indicators...{Style.RESET_ALL}")
    enrichment_config = config.get('enrichment', {})
    enriched = enrich_indicators(normalized, enrichment_config)
    click.echo(f"Enriched {len(enriched)} indicators\n")
    
    # Store indicators
    click.echo(f"{Fore.YELLOW}Storing indicators...{Style.RESET_ALL}")
    db_path = config.get_db_path()
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
            logger.error(f"Error storing indicator: {e}")
    
    click.echo(f"{Fore.GREEN}Successfully stored {stored_count} indicators{Style.RESET_ALL}\n")
    
    # Display statistics
    stats = db.get_statistics()
    click.echo(f"{Fore.CYAN}=== Database Statistics ==={Style.RESET_ALL}")
    click.echo(f"Total indicators: {stats['total_indicators']}")
    
    if stats['by_type']:
        click.echo(f"\nBy type:")
        for ioc_type, count in sorted(stats['by_type'].items(), key=lambda x: x[1], reverse=True):
            click.echo(f"  {ioc_type}: {count}")
    
    if stats['by_source']:
        click.echo(f"\nBy source:")
        for source, count in sorted(stats['by_source'].items(), key=lambda x: x[1], reverse=True):
            click.echo(f"  {source}: {count}")


@cli.command()
@click.option('--ioc', help='IOC value to search for')
@click.option('--type', 'ioc_type', help='Filter by IOC type (e.g., ipv4, domain, hash)')
@click.option('--source', help='Filter by source')
@click.option('--confidence', type=int, help='Minimum confidence score (0-100)')
@click.option('--limit', default=50, help='Maximum results to return (default: 50)')
@click.option('--format', 'output_format', type=click.Choice(['table', 'json', 'csv']), default='table', 
              help='Output format (default: table)')
@click.pass_context
def search(ctx, ioc, ioc_type, source, confidence, limit, output_format):
    """
    Search for threat intelligence indicators in the local database.
    
    Use various filters to find specific IOCs or patterns.
    """
    config = ctx.obj['config']
    db_path = config.get_db_path()
    db = ThreatIntelDB(db_path)
    
    # Search indicators
    results = db.search_indicators(
        ioc_value=ioc,
        ioc_type=ioc_type,
        source=source,
        min_confidence=confidence,
        limit=limit
    )
    
    if not results:
        click.echo(f"{Fore.YELLOW}No indicators found{Style.RESET_ALL}")
        return
    
    click.echo(f"{Fore.GREEN}Found {len(results)} indicator(s){Style.RESET_ALL}\n")
    
    # Format output
    if output_format == 'json':
        click.echo(json.dumps(results, indent=2, default=str))
    
    elif output_format == 'csv':
        if results:
            # Get all unique keys
            keys = ['indicator_id', 'type', 'value', 'source', 'confidence', 
                   'severity', 'first_seen', 'description']
            
            writer = csv.DictWriter(click.get_text_stream('stdout'), fieldnames=keys)
            writer.writeheader()
            for result in results:
                row = {k: result.get(k, '') for k in keys}
                writer.writerow(row)
    
    else:  # table format
        # Prepare table data
        table_data = []
        for result in results:
            table_data.append([
                result.get('type', 'N/A')[:20],
                result.get('value', 'N/A')[:50],
                result.get('source', 'N/A')[:15],
                result.get('confidence', 'N/A'),
                result.get('severity', 'N/A'),
                str(result.get('first_seen', 'N/A'))[:10]
            ])
        
        headers = ['Type', 'Value', 'Source', 'Confidence', 'Severity', 'First Seen']
        click.echo(tabulate(table_data, headers=headers, tablefmt='grid'))


@cli.command()
@click.option('--output', required=True, help='Output file path')
@click.option('--format', 'output_format', type=click.Choice(['json', 'csv', 'stix']), 
              required=True, help='Export format')
@click.option('--type', 'ioc_type', help='Filter by IOC type')
@click.option('--source', help='Filter by source')
@click.option('--confidence', type=int, help='Minimum confidence score')
@click.option('--limit', default=1000, help='Maximum indicators to export (default: 1000)')
@click.pass_context
def export(ctx, output, output_format, ioc_type, source, confidence, limit):
    """
    Export threat intelligence indicators to a file.
    
    Supports JSON, CSV, and STIX formats.
    """
    config = ctx.obj['config']
    db_path = config.get_db_path()
    db = ThreatIntelDB(db_path)
    
    # Search indicators with filters
    results = db.search_indicators(
        ioc_type=ioc_type,
        source=source,
        min_confidence=confidence,
        limit=limit
    )
    
    if not results:
        click.echo(f"{Fore.YELLOW}No indicators to export{Style.RESET_ALL}")
        return
    
    click.echo(f"{Fore.YELLOW}Exporting {len(results)} indicator(s)...{Style.RESET_ALL}")
    
    output_path = Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Export based on format
    if output_format == 'json':
        with open(output_path, 'w') as f:
            json.dump(results, f, indent=2, default=str)
    
    elif output_format == 'csv':
        if results:
            keys = ['indicator_id', 'type', 'value', 'source', 'confidence', 
                   'severity', 'labels', 'description', 'first_seen', 'last_seen']
            
            with open(output_path, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=keys)
                writer.writeheader()
                for result in results:
                    row = {k: result.get(k, '') for k in keys}
                    # Convert lists to strings
                    if isinstance(row.get('labels'), list):
                        row['labels'] = ','.join(row['labels'])
                    writer.writerow(row)
    
    elif output_format == 'stix':
        # Simple STIX bundle export
        stix_bundle = {
            "type": "bundle",
            "id": f"bundle--{datetime.now().strftime('%Y%m%d%H%M%S')}",
            "objects": []
        }
        
        for result in results:
            if result.get('raw_data'):
                stix_bundle['objects'].append(result['raw_data'])
        
        with open(output_path, 'w') as f:
            json.dump(stix_bundle, f, indent=2, default=str)
    
    click.echo(f"{Fore.GREEN}Exported to {output_path}{Style.RESET_ALL}")


@cli.command()
@click.option('--days', default=1, help='Days to analyze (default: 1 - today)')
@click.pass_context
def analyze(ctx, days):
    """
    Perform daily analysis on threat intelligence indicators.
    
    Generates statistics and insights about recent indicators.
    """
    click.echo(f"{Fore.CYAN}=== Threat Intelligence Analysis ==={Style.RESET_ALL}\n")
    
    config = ctx.obj['config']
    db_path = config.get_db_path()
    db = ThreatIntelDB(db_path)
    
    # Get statistics
    stats = db.get_statistics()
    
    click.echo(f"{Fore.CYAN}Overall Statistics:{Style.RESET_ALL}")
    click.echo(f"Total indicators in database: {stats['total_indicators']}\n")
    
    # Analyze by type
    if stats['by_type']:
        click.echo(f"{Fore.CYAN}Indicators by Type:{Style.RESET_ALL}")
        table_data = []
        for ioc_type, count in sorted(stats['by_type'].items(), key=lambda x: x[1], reverse=True):
            percentage = (count / stats['total_indicators'] * 100) if stats['total_indicators'] > 0 else 0
            table_data.append([ioc_type, count, f"{percentage:.1f}%"])
        
        click.echo(tabulate(table_data, headers=['Type', 'Count', 'Percentage'], tablefmt='grid'))
        click.echo()
    
    # Analyze by source
    if stats['by_source']:
        click.echo(f"{Fore.CYAN}Indicators by Source:{Style.RESET_ALL}")
        table_data = []
        for source, count in sorted(stats['by_source'].items(), key=lambda x: x[1], reverse=True):
            percentage = (count / stats['total_indicators'] * 100) if stats['total_indicators'] > 0 else 0
            table_data.append([source, count, f"{percentage:.1f}%"])
        
        click.echo(tabulate(table_data, headers=['Source', 'Count', 'Percentage'], tablefmt='grid'))
        click.echo()
    
    # Recent high-severity indicators
    high_severity = db.search_indicators(min_confidence=70, limit=10)
    
    if high_severity:
        click.echo(f"{Fore.RED}Top High-Confidence Indicators:{Style.RESET_ALL}")
        table_data = []
        for indicator in high_severity[:5]:
            table_data.append([
                indicator.get('type', 'N/A')[:15],
                indicator.get('value', 'N/A')[:40],
                indicator.get('confidence', 'N/A'),
                indicator.get('severity', 'N/A')
            ])
        
        click.echo(tabulate(table_data, headers=['Type', 'Value', 'Confidence', 'Severity'], tablefmt='grid'))
        click.echo()
    
    # Save analysis result
    analysis_date = datetime.now().strftime('%Y-%m-%d')
    total_count = stats['total_indicators']
    high_sev_count = len([i for i in high_severity if i.get('severity') == 'high'])
    
    summary = f"Total: {total_count}, High Severity: {high_sev_count}"
    db.save_analysis_result(analysis_date, 'all', total_count, high_sev_count, summary)
    
    click.echo(f"{Fore.GREEN}Analysis complete!{Style.RESET_ALL}")


@cli.command()
@click.pass_context
def stats(ctx):
    """
    Display database statistics and health information.
    """
    config = ctx.obj['config']
    db_path = config.get_db_path()
    
    # Check if database exists
    if not Path(db_path).exists():
        click.echo(f"{Fore.YELLOW}Database not initialized. Run 'threat-intel fetch' first.{Style.RESET_ALL}")
        return
    
    db = ThreatIntelDB(db_path)
    stats = db.get_statistics()
    
    click.echo(f"{Fore.CYAN}=== Database Statistics ==={Style.RESET_ALL}\n")
    click.echo(f"Database path: {db_path}")
    click.echo(f"Total indicators: {stats['total_indicators']}\n")
    
    if stats['by_type']:
        click.echo("Indicators by type:")
        for ioc_type, count in sorted(stats['by_type'].items(), key=lambda x: x[1], reverse=True):
            click.echo(f"  {ioc_type}: {count}")
        click.echo()
    
    if stats['by_source']:
        click.echo("Indicators by source:")
        for source, count in sorted(stats['by_source'].items(), key=lambda x: x[1], reverse=True):
            click.echo(f"  {source}: {count}")


def main():
    """Main entry point for the CLI."""
    cli(obj={})


if __name__ == '__main__':
    main()
