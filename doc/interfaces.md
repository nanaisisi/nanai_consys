# Nanai Consys Interface Specifications

This document provides detailed specifications for all interfaces used in the Nanai Consys system. These interfaces ensure compatibility and consistency across all components.

## Overview

The system is organized into three main layers, each with well-defined interfaces:

1. **Collection Layer**: Gathers raw system metrics
2. **Evaluation Layer**: Processes metrics and provides AI-enhanced analysis  
3. **Application Layer**: Orchestrates the system and applies recommendations

## Collection Layer Interfaces

### Standard Collector Interface

All metric collectors must implement this interface:

```nu
# Collect metrics in the appropriate format for this collector type
collect-metrics [] -> record | list | null

# Validate collected metrics against the expected schema
validate-metrics [data: record | list] -> bool

# Get information about this collector
get-collector-info [] -> record

# Check if collector is available on current system
is-available [] -> bool
```

### CPU Collector Interface

**Module**: `modules/collectors/cpu-collector.nu`

**Primary Function**:
```nu
collect-metrics [] -> record
```

**Return Schema**:
```nu
{
    usage_pct: float,        # Overall CPU usage percentage (0-100)
    per_core: list<record>   # Per-core usage details (optional)
}
```

**Extended Functions**:
```nu
collect-extended-metrics [] -> record  # Additional CPU info (brand, frequency, etc.)
```

### Memory Collector Interface  

**Module**: `modules/collectors/memory-collector.nu`

**Primary Function**:
```nu
collect-metrics [] -> record
```

**Return Schema**:
```nu
{
    total: int,         # Total memory in bytes
    used: int,          # Used memory in bytes
    used_pct: float     # Usage percentage (0-100)
}
```

**Extended Functions**:
```nu
collect-extended-metrics [] -> record           # Additional memory details
calculate-memory-pressure [data: record] -> string  # "low", "medium", "high", "critical"
```

### Disk Collector Interface

**Module**: `modules/collectors/disk-collector.nu`

**Primary Function**:
```nu
collect-metrics [] -> list<record>
```

**Return Schema**:
```nu
[{
    name: string,           # Device name
    mount: string,          # Mount point
    file_system: string,    # File system type
    total: int,             # Total space in bytes
    used: int,              # Used space in bytes
    used_pct: float         # Usage percentage (0-100)
}, ...]
```

**Extended Functions**:
```nu
collect-mount-metrics [mount_point: string] -> record    # Specific mount point
get-highest-usage-disk [] -> record                     # Disk with highest usage
calculate-disk-status [data: list] -> record            # Overall disk status
```

### GPU Collector Interface

**Module**: `modules/collectors/gpu-collector.nu`

**Primary Function**:
```nu
collect-metrics [] -> list<record>
```

**Return Schema**:
```nu
[{
    vendor: string,         # "nvidia", "amd", "intel", "unknown"
    usage_pct: float,       # GPU utilization percentage (0-100, nullable)
    mem_used_mib: int,      # GPU memory used in MiB (nullable)
    mem_total_mib: int,     # GPU memory total in MiB (nullable)
    mem_used_pct: float     # GPU memory usage percentage (0-100, nullable)
}, ...]
```

**Extended Functions**:
```nu
get-available-tools [] -> list<string>       # Available vendor tools
calculate-gpu-status [data: list] -> record  # Overall GPU status
```

### Health Assessor Interface

**Module**: `modules/collectors/health-assessor.nu`

**Primary Functions**:
```nu
assess-load [cpu: record, mem: record] -> string                    # "low", "mid", "high"
assess-stability [history: list<record>] -> record                  # Stability analysis
detect-anomalies [current: record, baseline: record] -> list        # Anomaly detection
generate-health-summary [snapshot: record] -> record               # Comprehensive health summary
```

## Evaluation Layer Interfaces

### AI Integration Interface

**Module**: `modules/evaluators/ai-integration.nu`

**Primary Functions**:
```nu
evaluate-system [request: record] -> record        # Main AI evaluation function
validate-ai-response [response: record] -> bool    # Validate AI response safety
prepare-evaluation-context [current: record, history: list] -> record  # Prepare context
get-ai-info [] -> record                          # AI backend information
```

**AI Request Schema**:
```nu
{
    metrics: record,           # Current system snapshot
    history: list<record>,     # Historical data points
    context: record           # Additional context information
}
```

**AI Response Schema**:
```nu
{
    confidence: float,         # Confidence level (0.0-1.0)
    category: string,          # Primary recommendation category
    actions: list<record>,     # Recommended actions
    reasoning: string,         # Explanation of recommendations
    metadata: record          # Additional response metadata
}
```

**AI Action Schema**:
```nu
{
    type: string,           # "adjust", "notify", "schedule"
    category: string,       # "performance", "resource", "thermal", etc.
    description: string,    # Human-readable description
    parameters: record,     # Action-specific parameters
    priority: string        # "low", "medium", "high", "critical"
}
```

## Application Layer Interfaces

### Main Monitor Interface

**Module**: `monitor.nu`

**Primary Functions**:
```nu
main [
    --once              # Run once and exit
    --interval: int     # Collection interval in seconds
    --log-path: path    # Custom log path
    --ai-evaluate       # Enable AI evaluation
    --config-path: path # Configuration file path
]

snapshot []             # Convenience function for single snapshot
ai-snapshot []          # Single snapshot with AI evaluation
```

**System Snapshot Schema**:
```nu
{
    timestamp: string,     # ISO 8601 timestamp
    level: string,         # "low", "mid", "high"
    cpu: record,           # CPU metrics
    mem: record,           # Memory metrics
    disks: list<record>,   # Disk metrics
    gpu: list<record>      # GPU metrics (can be empty)
}
```

## Schema Validation

### Schema Validation Functions

**Module**: `modules/interfaces/schemas.nu`

All schemas have corresponding validation functions:

```nu
validate-cpu-metrics [data: record] -> bool
validate-memory-metrics [data: record] -> bool  
validate-system-snapshot [data: record] -> bool
validate-ai-response [data: record] -> bool
```

### Error Handling Standards

**Standard Error Response**:
```nu
{
    error: true,
    message: string,
    category: string,
    timestamp: string
}
```

**Standard Success Response**:
```nu
{
    error: false,
    data: record,
    timestamp: string
}
```

## Configuration Interface

### Configuration Schema

```nu
{
    collection: {
        interval: int,                  # Collection frequency in seconds
        enabled_collectors: list,       # Which collectors to use
        log_path: string               # Where to store metrics
    },
    evaluation: {
        ai_backend: string,            # AI service type
        history_window: int,           # Historical points to consider
        confidence_threshold: float,   # Minimum confidence for actions
        auto_evaluate: bool           # Enable automatic AI evaluation
    },
    application: {
        auto_apply: bool,              # Automatically apply recommendations
        notification_level: string,    # "all", "important", "critical"
        max_actions_per_cycle: int    # Safety limit for actions
    }
}
```

## Usage Examples

### Basic Collection

```nu
# Single snapshot
nu -c "use scripts/monitor.nu; snapshot"

# Continuous monitoring
nu -c "use scripts/monitor.nu; main --interval 10"
```

### Modular Usage

```nu
# Direct collector usage
use scripts/modules/collectors/cpu-collector.nu as cpu
let cpu_data = (cpu collect-metrics)

# Health assessment
use scripts/modules/collectors/health-assessor.nu as health
let health_summary = (health generate-health-summary $snapshot)
```

### AI Integration

```nu
# Single AI-enhanced snapshot
nu -c "use scripts/monitor.nu; ai-snapshot"

# Continuous monitoring with AI
nu -c "use scripts/monitor.nu; main --interval 30 --ai-evaluate"
```

## Migration Guide

### Migrating from Legacy monitor.nu

The refactored monitor.nu maintains backward compatibility through deprecated functions:

- `get-cpu()` → Use `cpu collect-metrics` from cpu-collector module
- `get-mem()` → Use `memory collect-metrics` from memory-collector module  
- `get-disks()` → Use `disk collect-metrics` from disk-collector module
- `get-gpu()` → Use `gpu collect-metrics` from gpu-collector module
- `assess-load()` → Use `health assess-load` from health-assessor module

### New Features Available

- **Modular Architecture**: Use individual collectors independently
- **AI Integration**: Enable with `--ai-evaluate` flag
- **Extended Metrics**: Use `collect-extended-metrics` functions
- **Health Assessment**: Comprehensive system health analysis
- **Schema Validation**: Built-in data validation for all components

## Extension Points

### Adding New Collectors

1. Implement the standard collector interface
2. Add schema validation functions  
3. Place in `modules/collectors/` directory
4. Update main monitor.nu to use new collector

### Adding New AI Backends

1. Implement evaluation functions in `modules/evaluators/`
2. Follow AI integration interface specifications
3. Add backend-specific configuration options
4. Ensure safety validation for all responses

### Adding New Applications

1. Use existing collector and evaluator modules
2. Implement application-specific orchestration
3. Follow configuration interface for user settings
4. Add appropriate error handling and logging

This interface specification ensures that all components of the Nanai Consys system work together reliably while allowing for future extension and modification.