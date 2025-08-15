# Nanai Consys - Cross-Platform System Monitoring with AI Integration

A modular, cross-platform system monitoring solution built with Nushell, featuring AI-enhanced optimization recommendations and a clean architectural design.

## Features

- **Cross-Platform Monitoring**: CPU, Memory, Disk, and GPU metrics across Windows, Linux, and macOS
- **Modular Architecture**: Clean separation of collection, evaluation, and application layers
- **AI Integration**: Pluggable AI backends for intelligent system optimization
- **Automated Deployment**: Installation scripts for all supported platforms
- **Extensible Design**: Well-defined interfaces for adding new collectors and evaluators
- **Safety First**: Built-in validation and safety checks for all AI recommendations

## Quick Start

### Basic Usage

```bash
# Single system snapshot
nu -c "use scripts/monitor.nu; snapshot"

# Continuous monitoring (5-second intervals)
nu -c "use scripts/monitor.nu; main --interval 5"

# Single snapshot with AI recommendations
nu -c "use scripts/monitor.nu; ai-snapshot"

# Continuous monitoring with AI evaluation
nu -c "use scripts/monitor.nu; main --interval 30 --ai-evaluate"
```

### Installation for Background Monitoring

Choose your platform:

```bash
# Windows
powershell -ExecutionPolicy Bypass -File scripts/install-windows.ps1

# Linux  
bash scripts/install-linux.sh

# macOS
bash scripts/install-macos.sh
```

## Architecture

Nanai Consys follows a 3-layer modular architecture:

### 1. Collection Layer
- **CPU Collector**: Cross-platform CPU usage metrics
- **Memory Collector**: System memory utilization  
- **Disk Collector**: Storage usage across all mounts
- **GPU Collector**: NVIDIA/AMD GPU metrics (when available)
- **Health Assessor**: System load and stability analysis

### 2. Evaluation Layer
- **AI Integration**: Pluggable AI backends for optimization
- **Data Analysis**: Historical trend analysis and anomaly detection
- **Context Management**: Rich context for AI decision making

### 3. Application Layer
- **Orchestrator**: Main monitoring coordination
- **Configuration Management**: Multi-source configuration handling
- **Safety Systems**: Validation and filtering of AI recommendations

## Modular Usage

### Individual Collectors

```nu
# Use CPU collector directly
use scripts/modules/collectors/cpu-collector.nu as cpu
let cpu_metrics = (cpu collect-metrics)
let cpu_info = (cpu get-collector-info)

# Memory analysis
use scripts/modules/collectors/memory-collector.nu as memory
let mem_metrics = (memory collect-metrics) 
let pressure = (memory calculate-memory-pressure $mem_metrics)

# Health assessment
use scripts/modules/collectors/health-assessor.nu as health
let system_health = (health generate-health-summary $snapshot)
```

### AI Integration

```nu
# Prepare AI evaluation
use scripts/modules/evaluators/ai-integration.nu as ai
let context = (ai prepare-evaluation-context $current $history)
let ai_response = (ai evaluate-system $request)
```

## Configuration

### Default Behavior
- Metrics collected every 5 seconds
- Data stored in `$nu.data-dir/nanai_consys/metrics.ndjson`
- AI evaluation disabled by default
- All available collectors enabled

### Custom Configuration
Create `~/.nanai_consys.nu` for user-specific settings:

```nu
{
    collection: {
        interval: 10,
        enabled_collectors: ["cpu", "memory", "disk"]
    },
    evaluation: {
        ai_backend: "external_cli",
        confidence_threshold: 0.8,
        auto_evaluate: true
    },
    application: {
        auto_apply: false,
        notification_level: "important"
    }
}
```

## Data Schemas

### System Snapshot
```nu
{
    timestamp: "2024-08-15T10:58:00+00:00",
    level: "mid",  # "low", "mid", "high"
    cpu: { usage_pct: 45.2, per_core: [...] },
    mem: { total: 16777216000, used: 8388608000, used_pct: 50.0 },
    disks: [{ name: "C:", mount: "/", used_pct: 75.0, ... }],
    gpu: [{ vendor: "nvidia", usage_pct: 30.0, ... }]
}
```

### AI Recommendations
```nu
{
    confidence: 0.85,
    category: "performance",
    actions: [{
        type: "adjust",
        description: "Reduce background processes",
        priority: "medium"
    }],
    reasoning: "CPU usage consistently above optimal threshold"
}
```

## Safety and Security

### AI Safety
- All AI responses validated against safety schemas
- Confidence thresholds prevent low-quality recommendations
- Dangerous actions (shutdown, format, delete) are filtered out
- Fallback to heuristic evaluation when AI fails

### Data Security  
- No sensitive system information in logs
- Local-first approach with optional AI integration
- Input validation for all external data
- Secure handling of AI API credentials

## Extension Points

### Adding New Collectors
1. Implement the collector interface in `modules/collectors/`
2. Add schema validation functions
3. Update main monitor to use new collector

### Adding AI Backends
1. Implement evaluation functions in `modules/evaluators/`
2. Add backend-specific configuration
3. Ensure safety validation compliance

## Documentation

- [Coding Rules and Standards](doc/coding_rule.md) - Development guidelines
- [Architecture Documentation](doc/architecture.md) - System design details  
- [Interface Specifications](doc/interfaces.md) - Complete API reference
- [Metrics Documentation](doc/metrics.md) - Usage and data formats

## Development

### Building and Testing

```bash
# Validate modular architecture
nu -c "use scripts/modules/collectors/cpu-collector.nu as cpu; cpu is-available"

# Test AI integration (requires AI backend)
nu -c "use scripts/monitor.nu; ai-snapshot"

# Check all collectors
nu -c "
use scripts/modules/collectors/cpu-collector.nu as cpu;
use scripts/modules/collectors/memory-collector.nu as memory;
let cpu_data = (cpu collect-metrics);
let mem_data = (memory collect-metrics);
print ($cpu_data | to json); print ($mem_data | to json)
"
```

### Contributing

1. Follow the coding standards in [doc/coding_rule.md](doc/coding_rule.md)
2. Implement required interfaces for new components
3. Add appropriate validation and error handling
4. Update documentation for new features

## License

Licensed under either of:
- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE))
- MIT License ([LICENSE-MIT](LICENSE-MIT))

at your option.
