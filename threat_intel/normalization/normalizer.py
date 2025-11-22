"""Normalization module for standardizing threat intelligence indicators."""

import re
import hashlib
from typing import Dict, Any, List, Optional
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class IndicatorNormalizer:
    """Normalizes threat intelligence indicators to a standard format."""
    
    # IOC type patterns
    IOC_PATTERNS = {
        'ipv4': r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
        'ipv6': r'^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$',
        'domain': r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$',
        'url': r'^https?://',
        'md5': r'^[a-fA-F0-9]{32}$',
        'sha1': r'^[a-fA-F0-9]{40}$',
        'sha256': r'^[a-fA-F0-9]{64}$',
        'email': r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
        'cve': r'^CVE-\d{4}-\d{4,}$',
    }
    
    def normalize(self, indicator: Dict[str, Any]) -> Dict[str, Any]:
        """
        Normalize an indicator to standard format.
        
        Args:
            indicator: Raw indicator dictionary
            
        Returns:
            Normalized indicator dictionary
        """
        normalized = indicator.copy()
        
        # Extract and classify IOCs from patterns
        if normalized.get('pattern'):
            iocs = self._extract_iocs_from_pattern(normalized['pattern'])
            if iocs:
                # If we found specific IOCs, update the indicator
                normalized['extracted_iocs'] = iocs
                # Use the first IOC as the main value if not already set
                if not normalized.get('value') or normalized['value'] == normalized.get('pattern'):
                    normalized['value'] = iocs[0]['value']
                    normalized['ioc_type'] = iocs[0]['type']
        
        # Classify IOC type if not already set
        if not normalized.get('ioc_type'):
            normalized['ioc_type'] = self._classify_ioc(normalized.get('value', ''))
        
        # Normalize value based on type
        normalized['value'] = self._normalize_value(
            normalized.get('value', ''),
            normalized.get('ioc_type', 'unknown')
        )
        
        # Ensure confidence is in valid range
        if normalized.get('confidence'):
            normalized['confidence'] = max(0, min(100, int(normalized['confidence'])))
        else:
            normalized['confidence'] = 50
        
        # Standardize severity
        normalized['severity'] = self._normalize_severity(normalized.get('severity', 'medium'))
        
        # Ensure labels is a list
        if not normalized.get('labels'):
            normalized['labels'] = []
        elif not isinstance(normalized['labels'], list):
            normalized['labels'] = [normalized['labels']]
        
        # Add classification labels
        if normalized.get('ioc_type'):
            normalized['labels'].append(f"ioc-type:{normalized['ioc_type']}")
        
        # Parse and standardize timestamps
        for time_field in ['first_seen', 'last_seen', 'valid_from', 'valid_until']:
            if normalized.get(time_field):
                normalized[time_field] = self._normalize_timestamp(normalized[time_field])
        
        return normalized
    
    def _extract_iocs_from_pattern(self, pattern: str) -> List[Dict[str, str]]:
        """Extract IOCs from STIX pattern."""
        iocs = []
        
        # Common STIX pattern formats
        # e.g., [file:hashes.MD5 = 'abc123']
        # e.g., [ipv4-addr:value = '192.168.1.1']
        # e.g., [domain-name:value = 'example.com']
        
        # Extract values from patterns
        value_pattern = r"=\s*['\"]([^'\"]+)['\"]"
        matches = re.findall(value_pattern, pattern)
        
        for match in matches:
            ioc_type = self._classify_ioc(match)
            if ioc_type != 'unknown':
                iocs.append({
                    'type': ioc_type,
                    'value': match
                })
        
        return iocs
    
    def _classify_ioc(self, value: str) -> str:
        """
        Classify IOC type based on value.
        
        Args:
            value: IOC value
            
        Returns:
            IOC type string
        """
        if not value:
            return 'unknown'
        
        value = value.strip()
        
        # Check against patterns
        for ioc_type, pattern in self.IOC_PATTERNS.items():
            if re.match(pattern, value, re.IGNORECASE):
                return ioc_type
        
        return 'unknown'
    
    def _normalize_value(self, value: str, ioc_type: str) -> str:
        """
        Normalize IOC value based on type.
        
        Args:
            value: IOC value
            ioc_type: Type of IOC
            
        Returns:
            Normalized value
        """
        if not value:
            return value
        
        value = value.strip()
        
        # Normalize based on type
        if ioc_type in ['md5', 'sha1', 'sha256']:
            # Lowercase hashes
            value = value.lower()
        elif ioc_type == 'domain':
            # Lowercase domains
            value = value.lower()
            # Remove trailing dot
            value = value.rstrip('.')
        elif ioc_type == 'email':
            # Lowercase emails
            value = value.lower()
        elif ioc_type == 'url':
            # Remove trailing slash for consistency
            value = value.rstrip('/')
        
        return value
    
    def _normalize_severity(self, severity: str) -> str:
        """Normalize severity to standard values."""
        if not severity:
            return 'medium'
        
        severity_lower = str(severity).lower()
        
        if severity_lower in ['critical', 'high']:
            return 'high'
        elif severity_lower in ['medium', 'moderate']:
            return 'medium'
        elif severity_lower in ['low', 'info', 'informational']:
            return 'low'
        
        return 'medium'
    
    def _normalize_timestamp(self, timestamp: Any) -> str:
        """Normalize timestamp to ISO format string."""
        if isinstance(timestamp, str):
            return timestamp
        elif isinstance(timestamp, datetime):
            return timestamp.isoformat()
        else:
            return str(timestamp)
    
    def deduplicate(self, indicators: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Remove duplicate indicators.
        
        Args:
            indicators: List of indicators
            
        Returns:
            Deduplicated list
        """
        seen = set()
        unique_indicators = []
        
        for indicator in indicators:
            # Create a hash key from value and type
            key = self._create_indicator_key(indicator)
            
            if key not in seen:
                seen.add(key)
                unique_indicators.append(indicator)
        
        logger.info(f"Deduplicated {len(indicators)} indicators to {len(unique_indicators)}")
        return unique_indicators
    
    def _create_indicator_key(self, indicator: Dict[str, Any]) -> str:
        """Create a unique key for an indicator."""
        value = indicator.get('value', '')
        ioc_type = indicator.get('ioc_type', indicator.get('type', ''))
        key_str = f"{ioc_type}:{value}"
        return hashlib.md5(key_str.encode()).hexdigest()


def normalize_indicators(indicators: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Normalize a list of indicators.
    
    Args:
        indicators: List of raw indicators
        
    Returns:
        List of normalized indicators
    """
    normalizer = IndicatorNormalizer()
    
    normalized = []
    for indicator in indicators:
        try:
            norm_indicator = normalizer.normalize(indicator)
            normalized.append(norm_indicator)
        except Exception as e:
            logger.error(f"Error normalizing indicator: {e}")
    
    # Deduplicate
    normalized = normalizer.deduplicate(normalized)
    
    return normalized
