# Nanai Consys Interface Definitions
# Defines the contracts and schemas used throughout the system

# =============================================================================
# METRICS SCHEMA DEFINITIONS
# =============================================================================

# Standard CPU metrics schema
export def cpu-metrics-schema [] {
    {
        usage_pct: float,      # Overall CPU usage percentage (0.0-100.0)
        per_core: list<record> # Per-core usage details
    }
}

# Standard memory metrics schema  
export def memory-metrics-schema [] {
    {
        total: int,      # Total memory in bytes
        used: int,       # Used memory in bytes
        used_pct: float  # Usage percentage (0.0-100.0)
    }
}

# Standard disk metrics schema
export def disk-metrics-schema [] {
    {
        name: string,        # Device name
        mount: string,       # Mount point
        file_system: string, # File system type
        total: int,          # Total space in bytes
        used: int,           # Used space in bytes  
        used_pct: float      # Usage percentage (0.0-100.0)
    }
}

# Standard GPU metrics schema
export def gpu-metrics-schema [] {
    {
        vendor: string,        # "nvidia", "amd", etc.
        usage_pct: float,      # GPU utilization percentage
        mem_used_mib: int,     # GPU memory used in MiB
        mem_total_mib: int,    # GPU memory total in MiB
        mem_used_pct: float    # GPU memory usage percentage
    }
}

# Complete system snapshot schema
export def system-snapshot-schema [] {
    {
        timestamp: string,     # ISO 8601 format timestamp
        level: string,         # System load level: "low", "mid", "high"
        cpu: record,           # CPU metrics (cpu-metrics-schema)
        mem: record,           # Memory metrics (memory-metrics-schema)  
        disks: list<record>,   # Disk metrics array (disk-metrics-schema)
        gpu: list<record>      # GPU metrics array (gpu-metrics-schema, nullable)
    }
}

# =============================================================================
# AI INTEGRATION INTERFACE
# =============================================================================

# AI evaluation request schema
export def ai-request-schema [] {
    {
        metrics: record,           # Current system snapshot
        history: list<record>,     # Historical snapshots (last N points)
        context: record           # Additional context information
    }
}

# AI recommendation action schema
export def ai-action-schema [] {
    {
        type: string,           # Action type: "adjust", "notify", "schedule"
        category: string,       # Category: "performance", "resource", "thermal"
        description: string,    # Human-readable description
        parameters: record,     # Action-specific parameters
        priority: string        # "low", "medium", "high", "critical"
    }
}

# AI recommendation response schema  
export def ai-response-schema [] {
    {
        confidence: float,         # Confidence level (0.0 to 1.0)
        category: string,          # Primary recommendation category
        actions: list<record>,     # List of recommended actions
        reasoning: string,         # Explanation of recommendations
        metadata: record          # Additional AI response metadata
    }
}

# Context information schema
export def context-schema [] {
    {
        user_preferences: record,  # User configuration and preferences
        system_info: record,      # Static system information
        workload_type: string,    # Current workload type if detected
        time_of_day: string,      # Time context for recommendations
        environment: record       # Environmental factors
    }
}

# =============================================================================
# COLLECTION LAYER INTERFACES  
# =============================================================================

# Standard collector interface - all collectors must implement this
export def collector-interface [] {
    "All collectors must implement:
    
    collect-metrics []
        - Returns metrics in the appropriate schema format
        - Returns null if collection fails
        - Must handle all errors gracefully
        
    validate-metrics [data: record]
        - Validates that collected data matches expected schema
        - Returns false for invalid data
        
    get-collector-info []
        - Returns metadata about the collector
        - Includes: name, version, dependencies, supported_platforms"
}

# System health assessment interface
export def health-assessor-interface [] {
    "Health assessors must implement:
    
    assess-load [cpu: record, mem: record]
        - Returns system load level: 'low', 'mid', 'high'
        - Based on CPU and memory usage patterns
        
    assess-stability [history: list<record>]
        - Analyzes system stability from historical data
        - Returns stability metrics and trends"
}

# =============================================================================
# EVALUATION LAYER INTERFACES
# =============================================================================

# AI integration interface
export def ai-integration-interface [] {
    "AI integrations must implement:
    
    evaluate-system [request: record]
        - Takes ai-request-schema format input
        - Returns ai-response-schema format output  
        - Returns null if AI evaluation fails
        
    validate-response [response: record]
        - Validates AI response format and safety
        - Checks for malicious or unsafe recommendations
        
    get-ai-info []
        - Returns AI backend information and capabilities"
}

# Historical data analyzer interface  
export def data-analyzer-interface [] {
    "Data analyzers must implement:
    
    analyze-trends [history: list<record>]
        - Identifies patterns and trends in historical data
        - Returns trend analysis and predictions
        
    detect-anomalies [current: record, baseline: record]
        - Detects anomalous system behavior
        - Returns list of detected anomalies
        
    prepare-context [metrics: record, history: list]
        - Prepares context information for AI evaluation
        - Enriches data with derived insights"
}

# =============================================================================
# APPLICATION LAYER INTERFACES
# =============================================================================

# Orchestration engine interface
export def orchestrator-interface [] {
    "Orchestrators must implement:
    
    run-monitoring-cycle [config: record]
        - Executes one complete monitoring cycle
        - Returns cycle results and status
        
    handle-recommendations [recs: record, config: record]
        - Processes AI recommendations according to configuration
        - Returns execution results
        
    manage-system-state [current_state: record, updates: record]
        - Updates and maintains system state
        - Returns updated state information"
}

# Configuration manager interface
export def config-manager-interface [] {
    "Configuration managers must implement:
    
    load-configuration [sources: list<string>]
        - Loads configuration from multiple sources
        - Merges with appropriate precedence
        
    validate-configuration [config: record]
        - Validates configuration completeness and safety
        - Returns false for invalid configurations
        
    get-default-config []
        - Returns system default configuration
        - Includes all required fields with safe defaults"
}

# =============================================================================
# VALIDATION UTILITIES
# =============================================================================

# Validate metrics against schema
export def validate-cpu-metrics [data: record] {
    let conditions = [
        "usage_pct" in ($data | columns),
        "per_core" in ($data | columns),
        ($data.usage_pct | describe) == "float",
        ($data.per_core | describe) == "list"
    ]
    $conditions | all {|c| $c}
}

export def validate-memory-metrics [data: record] {
    let conditions = [
        "total" in ($data | columns),
        "used" in ($data | columns),
        "used_pct" in ($data | columns),
        ($data.total | describe) == "int",
        ($data.used | describe) == "int",
        ($data.used_pct | describe) == "float"
    ]
    $conditions | all {|c| $c}
}

export def validate-system-snapshot [data: record] {
    let required_fields = ["timestamp", "level", "cpu", "mem", "disks"]
    let conditions = [
        $required_fields | all {|field| $field in ($data | columns)},
        validate-cpu-metrics $data.cpu,
        validate-memory-metrics $data.mem,
        $data.level in ["low", "mid", "high"]
    ]
    $conditions | all {|c| $c}
}

export def validate-ai-response [data: record] {
    let required_fields = ["confidence", "category", "actions", "reasoning"]
    let conditions = [
        $required_fields | all {|field| $field in ($data | columns)},
        ($data.actions | describe) == "list"
    ]
    $conditions | all {|c| $c}
}

# =============================================================================
# ERROR HANDLING STANDARDS
# =============================================================================

# Standard error response format
export def error-response [message: string, category: string] {
    {
        error: true,
        message: $message,
        category: $category,
        timestamp: (date now | format date "%+")
    }
}

# Standard success response format  
export def success-response [data: record] {
    {
        error: false,
        data: $data,
        timestamp: (date now | format date "%+")
    }
}
