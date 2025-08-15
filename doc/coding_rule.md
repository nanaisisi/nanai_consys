# Nanai Consys Coding Rules and Standards

## Overview
This document defines the coding standards, architectural principles, and best practices for the Nanai Consys project. The goal is to create maintainable, modular, and scalable code that integrates system monitoring with AI optimization.

## Architecture Principles

### 3-Layer Architecture
The system follows a strict 3-layer architecture pattern:

1. **Collection Layer** - Responsible for gathering system metrics
2. **Evaluation Layer** - Processes metrics and integrates with AI for analysis
3. **Application Layer** - Applies optimization suggestions and manages user interactions

### Separation of Concerns
- Each module should have a single, well-defined responsibility
- Dependencies should flow in one direction (no circular dependencies)
- Interfaces should be explicit and documented

## Nushell Coding Standards

### Module Structure
```nu
# Module header with description and purpose
# Author, version, and dependencies information

# Public interface definitions (export def)
export def main [...] { }

# Public utility functions
export def function-name [...] { }

# Private implementation functions
def private-function [...] { }
```

### Naming Conventions
- **Modules**: Use kebab-case for file names (e.g., `metrics-collector.nu`)
- **Functions**: Use kebab-case for function names (e.g., `collect-cpu-metrics`)
- **Variables**: Use snake_case for variables (e.g., `cpu_usage_pct`)
- **Constants**: Use UPPER_SNAKE_CASE (e.g., `DEFAULT_INTERVAL`)

### Function Design
- Functions should be pure when possible (no side effects)
- Use explicit parameter types and documentation
- Return structured data with consistent schemas
- Handle errors gracefully with try/catch blocks

### Error Handling
```nu
# Use try/catch for error handling
let result = (try { 
    potentially-failing-operation 
} catch { 
    null  # or appropriate fallback
})

# Validate inputs at function boundaries
if ($param | is-empty) {
    error make {msg: "Parameter 'param' is required"}
}
```

### Documentation Standards
- All exported functions must have header comments
- Include parameter descriptions and return value documentation
- Provide usage examples for complex functions

```nu
# Collect CPU usage metrics across all cores
# Returns: record with usage_pct (float) and per_core (list)
# Example: let cpu_data = (get-cpu-metrics)
export def get-cpu-metrics [] {
    # implementation
}
```

## Interface Definitions

### Metrics Data Schema
All metrics must follow consistent schemas:

```nu
# CPU Metrics Schema
{
    usage_pct: float,      # Overall CPU usage percentage
    per_core: list<record> # Per-core usage details
}

# Memory Metrics Schema  
{
    total: int,      # Total memory in bytes
    used: int,       # Used memory in bytes
    used_pct: float  # Usage percentage
}

# System Snapshot Schema
{
    timestamp: string,     # ISO 8601 format
    level: string,         # "low", "mid", "high"
    cpu: record,           # CPU metrics
    mem: record,           # Memory metrics  
    disks: list<record>,   # Disk metrics
    gpu: list<record>      # GPU metrics (nullable)
}
```

### AI Integration Interface
```nu
# AI Evaluation Request Schema
{
    metrics: record,           # Current system snapshot
    history: list<record>,     # Historical data points
    context: record           # Additional context (user preferences, etc.)
}

# AI Recommendation Response Schema
{
    confidence: float,         # 0.0 to 1.0
    category: string,          # "performance", "resource", "thermal", etc.
    actions: list<record>,     # Recommended actions
    reasoning: string          # Explanation of recommendations
}
```
