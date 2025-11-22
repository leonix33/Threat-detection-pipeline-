"""Enrichment module for enhancing threat intelligence indicators."""

import re
from typing import Dict, Any, List, Optional
import logging
import ipaddress

logger = logging.getLogger(__name__)


class IndicatorEnricher:
    """Enriches threat intelligence indicators with additional context."""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        """
        Initialize enricher.
        
        Args:
            config: Enrichment configuration
        """
        self.config = config or {}
    
    def enrich(self, indicator: Dict[str, Any]) -> Dict[str, Any]:
        """
        Enrich an indicator with additional context.
        
        Args:
            indicator: Normalized indicator dictionary
            
        Returns:
            Enriched indicator dictionary with additional fields
        """
        enriched = indicator.copy()
        
        # Add enrichment metadata
        enriched['enrichments'] = []
        
        # Enrich based on IOC type
        ioc_type = indicator.get('ioc_type', indicator.get('type', ''))
        
        if ioc_type in ['ipv4', 'ipv6']:
            self._enrich_ip(enriched)
        elif ioc_type == 'domain':
            self._enrich_domain(enriched)
        elif ioc_type in ['md5', 'sha1', 'sha256']:
            self._enrich_hash(enriched)
        elif ioc_type == 'url':
            self._enrich_url(enriched)
        elif ioc_type == 'cve':
            self._enrich_cve(enriched)
        
        # Add contextual enrichments
        self._add_risk_score(enriched)
        self._add_tags(enriched)
        
        return enriched
    
    def _enrich_ip(self, indicator: Dict[str, Any]):
        """Enrich IP address indicators."""
        ip_value = indicator.get('value', '')
        
        enrichment = {
            'type': 'ip_analysis',
            'data': {}
        }
        
        # Check if private IP
        is_private = self._is_private_ip(ip_value)
        enrichment['data']['is_private'] = is_private
        
        if is_private:
            enrichment['data']['note'] = 'Private IP address - may indicate internal threat'
            # Increase severity for private IPs (potential lateral movement)
            if indicator.get('severity') == 'low':
                indicator['severity'] = 'medium'
        
        # Basic geolocation context (would integrate with real GeoIP service in production)
        if not is_private:
            enrichment['data']['note'] = 'Public IP address - external threat'
        
        indicator['enrichments'].append(enrichment)
    
    def _enrich_domain(self, indicator: Dict[str, Any]):
        """Enrich domain indicators."""
        domain = indicator.get('value', '')
        
        enrichment = {
            'type': 'domain_analysis',
            'data': {}
        }
        
        # Extract TLD
        tld = domain.split('.')[-1] if '.' in domain else ''
        enrichment['data']['tld'] = tld
        
        # Check for suspicious patterns
        if self._is_suspicious_domain(domain):
            enrichment['data']['suspicious_pattern'] = True
            enrichment['data']['note'] = 'Domain contains suspicious patterns'
            # Increase confidence for suspicious domains
            if indicator.get('confidence', 0) < 70:
                indicator['confidence'] = 70
        
        # Check for newly registered domain indicators
        if re.search(r'\d{4,}', domain):
            enrichment['data']['contains_numbers'] = True
            enrichment['data']['note'] = 'Domain contains numeric sequences (possible DGA)'
        
        indicator['enrichments'].append(enrichment)
    
    def _enrich_hash(self, indicator: Dict[str, Any]):
        """Enrich file hash indicators."""
        hash_type = indicator.get('ioc_type', '')
        
        enrichment = {
            'type': 'hash_analysis',
            'data': {
                'hash_algorithm': hash_type.upper(),
                'note': f'{hash_type.upper()} hash of potentially malicious file'
            }
        }
        
        # File hashes are generally high confidence IOCs
        if indicator.get('confidence', 0) < 80:
            indicator['confidence'] = 80
        
        indicator['enrichments'].append(enrichment)
    
    def _enrich_url(self, indicator: Dict[str, Any]):
        """Enrich URL indicators."""
        url = indicator.get('value', '')
        
        enrichment = {
            'type': 'url_analysis',
            'data': {}
        }
        
        # Check for HTTPS
        is_https = url.startswith('https://')
        enrichment['data']['is_https'] = is_https
        
        if not is_https:
            enrichment['data']['note'] = 'HTTP URL - potential for MitM attacks'
        
        # Check for suspicious URL patterns
        if self._is_suspicious_url(url):
            enrichment['data']['suspicious_pattern'] = True
            enrichment['data']['note'] = 'URL contains suspicious patterns'
            if indicator.get('severity') == 'low':
                indicator['severity'] = 'medium'
        
        # Extract domain from URL
        domain_match = re.search(r'://([^/]+)', url)
        if domain_match:
            enrichment['data']['domain'] = domain_match.group(1)
        
        indicator['enrichments'].append(enrichment)
    
    def _enrich_cve(self, indicator: Dict[str, Any]):
        """Enrich CVE indicators."""
        cve_id = indicator.get('value', '')
        
        enrichment = {
            'type': 'cve_analysis',
            'data': {
                'cve_id': cve_id,
                'note': 'Known vulnerability identifier'
            }
        }
        
        # Extract year from CVE
        year_match = re.search(r'CVE-(\d{4})', cve_id)
        if year_match:
            year = int(year_match.group(1))
            enrichment['data']['year'] = year
            
            # Recent CVEs may be higher priority
            from datetime import datetime
            current_year = datetime.now().year
            if current_year - year <= 1:
                enrichment['data']['note'] = 'Recent vulnerability (last 1 year)'
                if indicator.get('severity') == 'low':
                    indicator['severity'] = 'medium'
        
        indicator['enrichments'].append(enrichment)
    
    def _add_risk_score(self, indicator: Dict[str, Any]):
        """Calculate and add risk score."""
        # Simple risk scoring algorithm
        risk_score = 0
        
        # Base score from confidence
        confidence = indicator.get('confidence', 50)
        risk_score += confidence * 0.4
        
        # Severity contribution
        severity = indicator.get('severity', 'medium')
        severity_scores = {'low': 20, 'medium': 50, 'high': 80}
        risk_score += severity_scores.get(severity, 50) * 0.6
        
        # Normalize to 0-100
        risk_score = max(0, min(100, int(risk_score)))
        
        indicator['risk_score'] = risk_score
        
        # Add risk level
        if risk_score >= 70:
            indicator['risk_level'] = 'high'
        elif risk_score >= 40:
            indicator['risk_level'] = 'medium'
        else:
            indicator['risk_level'] = 'low'
    
    def _add_tags(self, indicator: Dict[str, Any]):
        """Add contextual tags."""
        tags = []
        
        # Add risk level tag
        if indicator.get('risk_level'):
            tags.append(f"risk:{indicator['risk_level']}")
        
        # Add IOC type tag
        if indicator.get('ioc_type'):
            tags.append(f"type:{indicator['ioc_type']}")
        
        # Add severity tag
        if indicator.get('severity'):
            tags.append(f"severity:{indicator['severity']}")
        
        # Add to existing labels
        existing_labels = indicator.get('labels', [])
        indicator['labels'] = list(set(existing_labels + tags))
    
    def _is_private_ip(self, ip: str) -> bool:
        """Check if IP is in private range using ipaddress module."""
        try:
            ip_obj = ipaddress.ip_address(ip)
            return ip_obj.is_private or ip_obj.is_loopback
        except ValueError:
            # Invalid IP address format
            return False
    
    def _is_suspicious_domain(self, domain: str) -> bool:
        """Check for suspicious domain patterns."""
        # Multiple subdomains
        if domain.count('.') > 3:
            return True
        
        # Very long domain
        if len(domain) > 50:
            return True
        
        # Many consecutive consonants (possible DGA)
        if re.search(r'[bcdfghjklmnpqrstvwxyz]{6,}', domain, re.IGNORECASE):
            return True
        
        # IP address in domain
        if re.search(r'\d{1,3}[-.]\d{1,3}[-.]\d{1,3}[-.]\d{1,3}', domain):
            return True
        
        return False
    
    def _is_suspicious_url(self, url: str) -> bool:
        """Check for suspicious URL patterns."""
        # Multiple @ symbols (potential phishing)
        if url.count('@') > 0:
            return True
        
        # IP address instead of domain
        if re.search(r'://\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}', url):
            return True
        
        # Very long URL
        if len(url) > 200:
            return True
        
        # Suspicious file extensions in URL
        suspicious_exts = ['.exe', '.scr', '.bat', '.cmd', '.vbs', '.js']
        if any(ext in url.lower() for ext in suspicious_exts):
            return True
        
        return False


def enrich_indicators(indicators: List[Dict[str, Any]], 
                     config: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    """
    Enrich a list of indicators.
    
    Args:
        indicators: List of normalized indicators
        config: Enrichment configuration
        
    Returns:
        List of enriched indicators
    """
    enricher = IndicatorEnricher(config)
    
    enriched = []
    for indicator in indicators:
        try:
            enriched_indicator = enricher.enrich(indicator)
            enriched.append(enriched_indicator)
        except Exception as e:
            logger.error(f"Error enriching indicator: {e}")
            # Still add the indicator, just without enrichment
            enriched.append(indicator)
    
    logger.info(f"Enriched {len(enriched)} indicators")
    return enriched
