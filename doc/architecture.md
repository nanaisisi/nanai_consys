# Nanai Consys Architecture Documentation

## System Overview

Nanai Consys is a cross-platform system monitoring solution with AI integration capabilities. The system follows a layered architecture that separates data collection, analysis, and application concerns.

## Architectural Layers

### 1. Collection Layer
**Purpose**: Gather raw system metrics from various sources
**Components**:
- CPU metrics collector
- Memory metrics collector  
- Disk metrics collector
- GPU metrics collector
- System health assessor

**Key Characteristics**:
- Minimal dependencies (only system APIs)
- Consistent data schemas
- Error-resilient collection
- Cross-platform compatibility

### 2. Evaluation Layer
**Purpose**: Process collected metrics and integrate with AI for analysis
**Components**:
- Historical data analyzer
- AI integration interface
- Recommendation engine
- Context manager

**Key Characteristics**:
- Stateless processing where possible
- Pluggable AI backends
- Fallback mechanisms for AI failures
- Rich context handling

### 3. Application Layer
**Purpose**: Apply recommendations and manage user interactions
**Components**:
- Orchestration engine
- Configuration manager
- User interface
- Action executor

**Key Characteristics**:
- User-centric design
- Safe action execution
- Comprehensive logging
- Multiple interaction modes

## Component Interaction Flow

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Collection      │    │ Evaluation      │    │ Application     │
│ Layer           │    │ Layer           │    │ Layer           │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • CPU Collector │    │ • Data Analyzer │    │ • Orchestrator  │
│ • Mem Collector │───▶│ • AI Interface  │───▶│ • Config Mgr    │
│ • Disk Collector│    │ • Recommender   │    │ • UI Handler    │
│ • GPU Collector │    │ • Context Mgr   │    │ • Action Exec   │
│ • Health Assess │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Data Flow

### 1. Collection Phase
1. System metrics are collected by specialized collectors
2. Raw data is normalized to standard schemas  
3. Basic health assessment is performed
4. Data is persisted for evaluation

### 2. Evaluation Phase
1. Current metrics are combined with historical data
2. Context information is gathered (user preferences, system state)
3. AI evaluation request is constructed
4. Recommendations are received and validated
5. Results are prepared for application

### 3. Application Phase
1. Recommendations are presented to user or system
2. Actions are executed based on configuration
3. Results are logged and fed back to evaluation
4. System state is updated

## Interface Contracts

### Collection Interface
```nu
export def collect-metrics [] -> record {
    # Returns standardized metrics snapshot
}

export def assess-system-health [metrics: record] -> string {
    # Returns: "low", "mid", "high"
}
```

### Evaluation Interface
```nu
export def evaluate-system [
    current: record,     # Current metrics
    history: list,       # Historical data
    context: record      # User/system context
] -> record {
    # Returns AI recommendations
}

export def validate-recommendations [recs: record] -> bool {
    # Validates AI response format and safety
}
```

### Application Interface  
```nu
export def orchestrate-monitoring [config: record] {
    # Main monitoring loop
}

export def execute-recommendations [
    recs: record,
    config: record
] -> record {
    # Safely applies recommendations
}
```

## Module Dependencies

### Dependency Graph
```
Application Layer
    ↓ depends on
Evaluation Layer
    ↓ depends on  
Collection Layer
    ↓ depends on
System APIs
```

### Specific Dependencies
- **monitor.nu**: Orchestrates all layers
- **collectors/**: Only depend on system APIs (sys, nvidia-smi, etc.)
- **evaluators/**: Depend on collectors and AI interfaces
- **interfaces/**: Define contracts, no dependencies
- **applications/**: Depend on evaluators for recommendations

## Configuration Management

### Configuration Schema
```nu
{
    collection: {
        interval: int,           # Collection frequency in seconds
        enabled_collectors: list # Which collectors to use
    },
    evaluation: {
        ai_backend: string,      # AI service endpoint or command
        history_window: int,     # Historical data points to consider
        confidence_threshold: float  # Minimum AI confidence for action
    },
    application: {
        auto_apply: bool,        # Automatically apply recommendations
        notification_level: string,  # "all", "important", "critical"
        max_actions_per_cycle: int   # Safety limit
    }
}
```

### Configuration Sources
1. Default configuration (embedded in modules)
2. System configuration file ($nu.config-dir/nanai_consys/config.nu)
3. User configuration file (~/.nanai_consys.nu)
4. Runtime parameters (command line flags)

## Error Handling Strategy

### Collection Layer Errors
- Individual collector failures are isolated
- Null values used for unavailable metrics
- System continues with partial data
- Errors logged but not propagated

### Evaluation Layer Errors  
- AI failures trigger fallback to heuristic evaluation
- Invalid responses are rejected with validation
- Historical data corruption is handled gracefully
- Context errors fall back to minimal context

### Application Layer Errors
- Unsafe recommendations are blocked
- Action execution failures are logged and reported
- System state corruption triggers safe mode
- User notification of critical failures

## Security Considerations

### Data Security
- No sensitive system information in persistent logs
- Metrics data is anonymized where possible
- AI communication uses secure channels
- Local data is protected with appropriate permissions

### AI Security
- AI responses are validated before application
- Rate limiting prevents API abuse
- Fallback mechanisms ensure availability
- Input sanitization prevents injection attacks

## Performance Characteristics

### Resource Usage Targets
- **CPU**: <1% average utilization
- **Memory**: <10MB baseline, <50MB peak
- **Disk I/O**: <1MB/hour for logging
- **Network**: <100KB/hour for AI communication

### Scalability Design
- Modular collectors can be enabled/disabled
- Historical data is automatically pruned
- AI evaluation can be batched for efficiency
- Multiple collection intervals supported

## Testing Strategy

### Unit Testing
- Each collector tested with mock system data
- Interface contracts validated with schema tests
- Error handling paths explicitly tested
- Cross-platform compatibility verified

### Integration Testing
- End-to-end workflows tested
- AI integration tested with mock responses
- Configuration management tested
- Platform-specific installation tested

### Performance Testing
- Resource usage monitored under load
- Long-running stability validated
- Memory leak detection
- Platform performance comparisons

## Future Extensibility

### Plugin Architecture
- New collectors can be added as modules
- Multiple AI backends can be supported
- Custom evaluation logic can be plugged in
- User-defined actions can be integrated

### API Evolution
- Interface versioning for backward compatibility
- Schema migration support
- Feature flags for gradual rollouts
- Deprecated feature warnings