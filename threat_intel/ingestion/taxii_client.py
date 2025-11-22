"""STIX/TAXII ingestion module for fetching threat intelligence indicators."""

import os
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import logging

try:
    from taxii2client.v21 import Server, Collection
    from stix2 import parse
except ImportError as e:
    logging.warning(f"TAXII/STIX libraries not available: {e}")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class STIXTAXIIIngester:
    """Ingests threat intelligence from STIX/TAXII servers."""
    
    def __init__(self, server_config: Dict[str, Any]):
        """
        Initialize TAXII client.
        
        Args:
            server_config: Server configuration dictionary
        """
        self.server_config = server_config
        self.server_name = server_config.get('name', 'unknown')
        
        # Setup authentication if required
        self.auth = None
        if server_config.get('auth_required'):
            username = os.getenv('TAXII_USERNAME')
            password = os.getenv('TAXII_PASSWORD')
            if username and password:
                from requests.auth import HTTPBasicAuth
                self.auth = HTTPBasicAuth(username, password)
    
    def fetch_indicators(self, 
                        collection_name: Optional[str] = None,
                        added_after: Optional[datetime] = None,
                        limit: int = 1000) -> List[Dict[str, Any]]:
        """
        Fetch indicators from TAXII server.
        
        Args:
            collection_name: Specific collection to fetch from
            added_after: Only fetch indicators added after this date
            limit: Maximum number of indicators to fetch
            
        Returns:
            List of parsed indicator dictionaries
        """
        indicators = []
        
        try:
            # Connect to TAXII server
            discovery_url = self.server_config.get('discovery_url')
            logger.info(f"Connecting to TAXII server: {self.server_name} at {discovery_url}")
            
            server = Server(discovery_url, user=self.auth.username if self.auth else None,
                          password=self.auth.password if self.auth else None)
            
            # Get API root
            api_root_path = self.server_config.get('api_root', '')
            api_roots = server.api_roots
            
            if not api_roots:
                logger.warning(f"No API roots found for {self.server_name}")
                return indicators
            
            # Find matching API root
            api_root = None
            for root in api_roots:
                if api_root_path in root.url:
                    api_root = root
                    break
            
            if not api_root:
                api_root = api_roots[0]  # Use first available
            
            logger.info(f"Using API root: {api_root.url}")
            
            # Get collections
            collections_to_fetch = self.server_config.get('collections', [])
            if collection_name:
                collections_to_fetch = [collection_name]
            
            for coll_name in collections_to_fetch:
                try:
                    # Find collection
                    collection = None
                    for c in api_root.collections:
                        if c.title == coll_name or c.id == coll_name:
                            collection = c
                            break
                    
                    if not collection:
                        logger.warning(f"Collection '{coll_name}' not found")
                        continue
                    
                    logger.info(f"Fetching from collection: {collection.title}")
                    
                    # Fetch objects
                    filter_params = {}
                    if added_after:
                        filter_params['added_after'] = added_after.strftime('%Y-%m-%dT%H:%M:%S.%fZ')
                    
                    # Get objects from collection
                    try:
                        objects = collection.get_objects(limit=limit, **filter_params)
                        
                        if hasattr(objects, 'get'):
                            stix_objects = objects.get('objects', [])
                        else:
                            stix_objects = objects
                        
                        logger.info(f"Retrieved {len(stix_objects) if isinstance(stix_objects, list) else 'unknown'} objects")
                        
                        # Parse STIX objects
                        for obj in stix_objects:
                            parsed = self._parse_stix_object(obj)
                            if parsed:
                                indicators.extend(parsed)
                    
                    except Exception as e:
                        logger.error(f"Error fetching objects from collection {coll_name}: {e}")
                
                except Exception as e:
                    logger.error(f"Error processing collection {coll_name}: {e}")
        
        except Exception as e:
            logger.error(f"Error connecting to TAXII server {self.server_name}: {e}")
        
        logger.info(f"Total indicators fetched from {self.server_name}: {len(indicators)}")
        return indicators
    
    def _parse_stix_object(self, stix_obj: Any) -> List[Dict[str, Any]]:
        """
        Parse STIX object into normalized indicator format.
        
        Args:
            stix_obj: STIX object (dict or STIX2 object)
            
        Returns:
            List of indicator dictionaries
        """
        indicators = []
        
        try:
            # Handle both dict and STIX2 objects
            if isinstance(stix_obj, dict):
                obj_dict = stix_obj
            else:
                obj_dict = dict(stix_obj)
            
            obj_type = obj_dict.get('type')
            
            # Handle indicator objects
            if obj_type == 'indicator':
                indicator = {
                    'indicator_id': obj_dict.get('id'),
                    'type': 'indicator',
                    'value': obj_dict.get('name', obj_dict.get('pattern', '')),
                    'pattern': obj_dict.get('pattern'),
                    'source': self.server_name,
                    'description': obj_dict.get('description', ''),
                    'labels': obj_dict.get('labels', []),
                    'confidence': self._extract_confidence(obj_dict),
                    'severity': self._extract_severity(obj_dict),
                    'valid_from': obj_dict.get('valid_from'),
                    'valid_until': obj_dict.get('valid_until'),
                    'first_seen': obj_dict.get('created'),
                    'last_seen': obj_dict.get('modified'),
                    'raw_data': obj_dict
                }
                indicators.append(indicator)
            
            # Handle attack-pattern, malware, threat-actor, etc.
            elif obj_type in ['attack-pattern', 'malware', 'threat-actor', 'tool', 'campaign']:
                indicator = {
                    'indicator_id': obj_dict.get('id'),
                    'type': obj_type,
                    'value': obj_dict.get('name', ''),
                    'pattern': None,
                    'source': self.server_name,
                    'description': obj_dict.get('description', ''),
                    'labels': obj_dict.get('labels', []),
                    'confidence': self._extract_confidence(obj_dict),
                    'severity': self._extract_severity(obj_dict),
                    'valid_from': obj_dict.get('created'),
                    'valid_until': None,
                    'first_seen': obj_dict.get('created'),
                    'last_seen': obj_dict.get('modified'),
                    'raw_data': obj_dict
                }
                indicators.append(indicator)
        
        except Exception as e:
            logger.debug(f"Error parsing STIX object: {e}")
        
        return indicators
    
    def _extract_confidence(self, obj_dict: Dict) -> Optional[int]:
        """Extract confidence score from STIX object."""
        confidence = obj_dict.get('confidence')
        if confidence is not None:
            return int(confidence)
        return 50  # Default medium confidence
    
    def _extract_severity(self, obj_dict: Dict) -> str:
        """Extract severity from STIX object."""
        labels = obj_dict.get('labels', [])
        
        # Map common labels to severity
        for label in labels:
            label_lower = label.lower()
            if 'critical' in label_lower or 'high' in label_lower:
                return 'high'
            elif 'medium' in label_lower:
                return 'medium'
            elif 'low' in label_lower:
                return 'low'
        
        # Check for kill chain phase (earlier phases = higher severity)
        kill_chain = obj_dict.get('kill_chain_phases', [])
        if kill_chain:
            phase_name = kill_chain[0].get('phase_name', '').lower()
            if any(p in phase_name for p in ['reconnaissance', 'weaponization', 'delivery']):
                return 'high'
        
        return 'medium'  # Default


def fetch_from_all_servers(server_configs: List[Dict[str, Any]], 
                           added_after: Optional[datetime] = None) -> List[Dict[str, Any]]:
    """
    Fetch indicators from all configured TAXII servers.
    
    Args:
        server_configs: List of server configuration dictionaries
        added_after: Only fetch indicators added after this date
        
    Returns:
        Combined list of indicators from all servers
    """
    all_indicators = []
    
    for server_config in server_configs:
        if not server_config.get('enabled', True):
            continue
        
        try:
            ingester = STIXTAXIIIngester(server_config)
            indicators = ingester.fetch_indicators(added_after=added_after)
            all_indicators.extend(indicators)
        except Exception as e:
            logger.error(f"Error fetching from {server_config.get('name')}: {e}")
    
    return all_indicators
