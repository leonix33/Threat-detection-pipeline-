"""Configuration management for the threat intelligence pipeline."""

import os
import yaml
from pathlib import Path
from typing import Dict, Any, Optional


class Config:
    """Manages configuration loading and access."""
    
    def __init__(self, config_path: Optional[str] = None):
        """
        Initialize configuration.
        
        Args:
            config_path: Path to config file. If None, uses default config.
        """
        self.config_dir = Path(__file__).parent.parent / "config"
        
        # Load default config
        default_config_path = self.config_dir / "default.yaml"
        with open(default_config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        # Override with local config if it exists
        local_config_path = self.config_dir / "local.yaml"
        if local_config_path.exists():
            with open(local_config_path, 'r') as f:
                local_config = yaml.safe_load(f)
                self._merge_configs(self.config, local_config)
        
        # Override with custom config if provided
        if config_path and os.path.exists(config_path):
            with open(config_path, 'r') as f:
                custom_config = yaml.safe_load(f)
                self._merge_configs(self.config, custom_config)
        
        # Override with environment variables
        self._apply_env_overrides()
    
    def _merge_configs(self, base: Dict, override: Dict):
        """Recursively merge override config into base config."""
        for key, value in override.items():
            if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                self._merge_configs(base[key], value)
            else:
                base[key] = value
    
    def _apply_env_overrides(self):
        """Apply environment variable overrides."""
        # Database path
        if os.getenv('THREAT_INTEL_DB_PATH'):
            self.config['database']['path'] = os.getenv('THREAT_INTEL_DB_PATH')
    
    def get(self, key: str, default: Any = None) -> Any:
        """
        Get a configuration value using dot notation.
        
        Args:
            key: Configuration key (e.g., 'database.path')
            default: Default value if key not found
            
        Returns:
            Configuration value
        """
        keys = key.split('.')
        value = self.config
        
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        
        return value
    
    def get_taxii_servers(self):
        """Get list of enabled TAXII servers."""
        servers = self.config.get('taxii_servers', [])
        return [s for s in servers if s.get('enabled', True)]
    
    def get_db_path(self) -> str:
        """Get database path."""
        return self.config['database']['path']


# Global config instance
_config = None

def get_config(config_path: Optional[str] = None) -> Config:
    """Get the global config instance."""
    global _config
    if _config is None:
        _config = Config(config_path)
    return _config
