"""Storage module for persisting threat intelligence indicators."""

import sqlite3
import json
from datetime import datetime
from typing import List, Dict, Any, Optional
from pathlib import Path


class ThreatIntelDB:
    """SQLite database for storing threat intelligence indicators."""
    
    def __init__(self, db_path: str):
        """
        Initialize database connection.
        
        Args:
            db_path: Path to SQLite database file
        """
        self.db_path = db_path
        self._init_db()
    
    def _init_db(self):
        """Initialize database schema."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Create indicators table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS indicators (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                indicator_id TEXT UNIQUE NOT NULL,
                type TEXT NOT NULL,
                value TEXT NOT NULL,
                pattern TEXT,
                source TEXT,
                confidence INTEGER,
                severity TEXT,
                labels TEXT,
                description TEXT,
                first_seen TIMESTAMP,
                last_seen TIMESTAMP,
                valid_from TIMESTAMP,
                valid_until TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                raw_data TEXT
            )
        """)
        
        # Create enrichment table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS enrichments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                indicator_id TEXT NOT NULL,
                enrichment_type TEXT NOT NULL,
                enrichment_data TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (indicator_id) REFERENCES indicators(indicator_id)
            )
        """)
        
        # Create analysis results table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS analysis_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                analysis_date DATE NOT NULL,
                indicator_type TEXT,
                total_count INTEGER,
                high_severity_count INTEGER,
                summary TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Create indexes
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_indicator_type ON indicators(type)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_indicator_value ON indicators(value)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_indicator_source ON indicators(source)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_first_seen ON indicators(first_seen)")
        
        conn.commit()
        conn.close()
    
    def insert_indicator(self, indicator: Dict[str, Any]) -> int:
        """
        Insert or update an indicator.
        
        Args:
            indicator: Dictionary containing indicator data
            
        Returns:
            Row ID of inserted/updated indicator
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute("""
                INSERT INTO indicators (
                    indicator_id, type, value, pattern, source, confidence,
                    severity, labels, description, first_seen, last_seen,
                    valid_from, valid_until, raw_data
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(indicator_id) DO UPDATE SET
                    last_seen = COALESCE(excluded.last_seen, last_seen),
                    updated_at = CURRENT_TIMESTAMP,
                    confidence = COALESCE(excluded.confidence, confidence),
                    raw_data = excluded.raw_data
            """, (
                indicator.get('indicator_id'),
                indicator.get('type'),
                indicator.get('value'),
                indicator.get('pattern'),
                indicator.get('source'),
                indicator.get('confidence'),
                indicator.get('severity'),
                json.dumps(indicator.get('labels', [])),
                indicator.get('description'),
                indicator.get('first_seen'),
                indicator.get('last_seen'),
                indicator.get('valid_from'),
                indicator.get('valid_until'),
                json.dumps(indicator.get('raw_data', {}))
            ))
            
            row_id = cursor.lastrowid
            conn.commit()
            return row_id
        finally:
            conn.close()
    
    def insert_enrichment(self, indicator_id: str, enrichment_type: str, enrichment_data: Dict):
        """Insert enrichment data for an indicator."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute("""
                INSERT INTO enrichments (indicator_id, enrichment_type, enrichment_data)
                VALUES (?, ?, ?)
            """, (indicator_id, enrichment_type, json.dumps(enrichment_data)))
            
            conn.commit()
        finally:
            conn.close()
    
    def search_indicators(self, 
                         ioc_value: Optional[str] = None,
                         ioc_type: Optional[str] = None,
                         source: Optional[str] = None,
                         min_confidence: Optional[int] = None,
                         limit: int = 100) -> List[Dict[str, Any]]:
        """
        Search for indicators.
        
        Args:
            ioc_value: IOC value to search for (partial match)
            ioc_type: Indicator type filter
            source: Source filter
            min_confidence: Minimum confidence score
            limit: Maximum number of results
            
        Returns:
            List of matching indicators
        """
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        query = "SELECT * FROM indicators WHERE 1=1"
        params = []
        
        if ioc_value:
            query += " AND value LIKE ?"
            params.append(f"%{ioc_value}%")
        
        if ioc_type:
            query += " AND type = ?"
            params.append(ioc_type)
        
        if source:
            query += " AND source = ?"
            params.append(source)
        
        if min_confidence is not None:
            query += " AND confidence >= ?"
            params.append(min_confidence)
        
        query += " ORDER BY created_at DESC LIMIT ?"
        params.append(limit)
        
        try:
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            results = []
            for row in rows:
                indicator = dict(row)
                # Parse JSON fields
                if indicator.get('labels'):
                    indicator['labels'] = json.loads(indicator['labels'])
                if indicator.get('raw_data'):
                    indicator['raw_data'] = json.loads(indicator['raw_data'])
                results.append(indicator)
            
            return results
        finally:
            conn.close()
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get database statistics."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute("SELECT COUNT(*) FROM indicators")
            total_indicators = cursor.fetchone()[0]
            
            cursor.execute("SELECT type, COUNT(*) as count FROM indicators GROUP BY type")
            type_counts = {row[0]: row[1] for row in cursor.fetchall()}
            
            cursor.execute("SELECT source, COUNT(*) as count FROM indicators GROUP BY source")
            source_counts = {row[0]: row[1] for row in cursor.fetchall()}
            
            return {
                'total_indicators': total_indicators,
                'by_type': type_counts,
                'by_source': source_counts
            }
        finally:
            conn.close()
    
    def save_analysis_result(self, analysis_date: str, indicator_type: str, 
                            total_count: int, high_severity_count: int, summary: str):
        """Save analysis results."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute("""
                INSERT INTO analysis_results 
                (analysis_date, indicator_type, total_count, high_severity_count, summary)
                VALUES (?, ?, ?, ?, ?)
            """, (analysis_date, indicator_type, total_count, high_severity_count, summary))
            
            conn.commit()
        finally:
            conn.close()
    
    def close(self):
        """Close database connection."""
        pass  # Using context managers, so connections are closed after use
