# AI Integration Interface Module
# Provides standardized interface for AI backend integration and evaluation
# Author: Nanai Consys Project
# Version: 1.0.0
# Dependencies: External AI tools/APIs (configurable)

use ../interfaces/schemas.nu

# Default AI backend configuration
const DEFAULT_AI_CONFIG = {
    backend_type: "external_cli",  # "external_cli", "http_api", "local_model"  
    command: "my_ai.exe",          # CLI command for external_cli type
    mode: "suggest",               # Default mode parameter
    timeout: 30,                   # Timeout in seconds
    retry_count: 2,                # Number of retries on failure
    confidence_threshold: 0.7      # Minimum confidence for recommendations
}

# Evaluate system metrics using configured AI backend
# Parameters: request (record) - AI evaluation request matching ai-request-schema
# Returns: record - AI response matching ai-response-schema or null on failure
export def evaluate-system [request: record] -> record {
    # Validate input request
    if (not (validate-ai-request $request)) {
        return (create-error-response "Invalid AI request format")
    }
    
    let config = (get-ai-config)
    
    # Try evaluation with retries
    mut attempt = 1
    mut result = null
    
    while ($attempt <= $config.retry_count and $result == null) {
        $result = (try-ai-evaluation $request $config)
        $attempt = ($attempt + 1)
    }
    
    if ($result == null) {
        return (get-fallback-evaluation $request)
    }
    
    # Validate and filter response
    if (validate-ai-response $result) {
        return (filter-safe-response $result $config)
    } else {
        return (get-fallback-evaluation $request)
    }
}

# Attempt AI evaluation with specific backend
def try-ai-evaluation [request: record, config: record] -> record {
    match $config.backend_type {
        "external_cli" => (evaluate-with-cli $request $config),
        "http_api" => (evaluate-with-api $request $config),
        "local_model" => (evaluate-with-local $request $config),
        _ => null
    }
}

# Evaluate using external CLI tool
def evaluate-with-cli [request: record, config: record] -> record {
    try {
        let json_input = ($request | to json -r)
        let result = ($json_input | ^$config.command --mode $config.mode)
        return ($result | from json)
    } catch {
        return null
    }
}

# Evaluate using HTTP API (placeholder implementation)
def evaluate-with-api [request: record, config: record] -> record {
    # Placeholder for HTTP API integration
    # In real implementation, this would make HTTP requests
    try {
        # let response = (curl -X POST $config.api_endpoint -d ($request | to json))
        # return ($response | from json)
        return null  # Not implemented in this version
    } catch {
        return null
    }
}

# Evaluate using local model (placeholder implementation)  
def evaluate-with-local [request: record, config: record] -> record {
    # Placeholder for local model integration
    # In real implementation, this would interface with local AI models
    return null  # Not implemented in this version
}

# Get fallback evaluation using heuristic rules when AI fails
def get-fallback-evaluation [request: record] -> record {
    let current = $request.metrics
    let cpu_usage = ($current.cpu.usage_pct | default 0)
    let mem_usage = ($current.mem.used_pct | default 0)
    
    # Simple heuristic-based recommendations
    let recommendations = []
    
    # CPU-based recommendations
    let recommendations = (if ($cpu_usage > 80) {
        $recommendations | append {
            type: "adjust",
            category: "performance", 
            description: "Reduce CPU-intensive processes",
            parameters: { suggested_action: "process_management" },
            priority: "high"
        }
    } else {
        $recommendations
    })
    
    # Memory-based recommendations
    let recommendations = (if ($mem_usage > 80) {
        $recommendations | append {
            type: "adjust",
            category: "resource",
            description: "Free up memory by closing unused applications", 
            parameters: { suggested_action: "memory_cleanup" },
            priority: "high"
        }
    } else {
        $recommendations
    })
    
    # General performance recommendations
    let recommendations = (if ($cpu_usage > 50 or $mem_usage > 50) {
        $recommendations | append {
            type: "notify",
            category: "performance",
            description: "System performance could be optimized",
            parameters: { suggested_action: "general_optimization" },
            priority: "medium"
        }
    } else {
        $recommendations
    })
    
    {
        confidence: 0.6,  # Lower confidence for heuristic evaluation
        category: "heuristic_fallback",
        actions: $recommendations,
        reasoning: "AI evaluation unavailable, using heuristic fallback",
        metadata: {
            evaluation_type: "fallback",
            timestamp: (date now | format date "%+")
        }
    }
}

# Validate AI request format
def validate-ai-request [request: record] -> bool {
    let required_fields = ["metrics", "history", "context"]
    ($required_fields | all {|field| $field in ($request | columns)})
}

# Validate AI response format and content safety
export def validate-ai-response [response: record] -> bool {
    if ($response == null) {
        return false
    }
    
    # Check required fields
    let required_fields = ["confidence", "category", "actions", "reasoning"]
    let has_required = ($required_fields | all {|field| $field in ($response | columns)})
    
    if (not $has_required) {
        return false
    }
    
    # Validate confidence range
    if ($response.confidence < 0.0 or $response.confidence > 1.0) {
        return false
    }
    
    # Validate actions format
    if (($response.actions | describe) != "list") {
        return false
    }
    
    # Validate each action
    let actions_valid = ($response.actions | all {|action|
        let action_fields = ["type", "category", "description", "parameters", "priority"]
        ($action_fields | all {|field| $field in ($action | columns)}) and
        ($action.type in ["adjust", "notify", "schedule"]) and
        ($action.priority in ["low", "medium", "high", "critical"])
    })
    
    return $actions_valid
}

# Filter response for safety and apply confidence threshold
def filter-safe-response [response: record, config: record] -> record {
    # Apply confidence threshold
    if ($response.confidence < $config.confidence_threshold) {
        return {
            confidence: $response.confidence,
            category: "low_confidence",
            actions: [],
            reasoning: $"AI confidence ($response.confidence) below threshold ($config.confidence_threshold)",
            metadata: ($response.metadata | default {})
        }
    }
    
    # Filter out potentially unsafe actions
    let safe_actions = ($response.actions | where {|action|
        # Only allow safe action types and categories
        ($action.type in ["notify", "adjust"]) and
        ($action.category in ["performance", "resource", "thermal", "maintenance"]) and
        (not ($action.description | str contains "delete")) and
        (not ($action.description | str contains "format")) and
        (not ($action.description | str contains "shutdown"))
    })
    
    return ($response | merge { actions: $safe_actions })
}

# Create error response in standard format
def create-error-response [message: string] -> record {
    {
        confidence: 0.0,
        category: "error",
        actions: [],
        reasoning: $message,
        metadata: {
            error: true,
            timestamp: (date now | format date "%+")
        }
    }
}

# Get AI configuration from various sources
def get-ai-config [] -> record {
    # In real implementation, this would load from config files
    # For now, return default configuration
    return $DEFAULT_AI_CONFIG
}

# Prepare AI evaluation context from metrics and history
export def prepare-evaluation-context [current: record, history: list] -> record {
    let context = {
        user_preferences: {
            performance_priority: "balanced",  # "performance", "efficiency", "balanced"
            auto_apply_threshold: 0.8,         # Only auto-apply high-confidence recommendations
            notification_level: "important"    # "all", "important", "critical"
        },
        system_info: {
            os: (sys | get os_info.name),
            cpu_count: (try { sys cpu | get cpu_count } catch { null }),
            total_memory: ($current.mem.total | default null)
        },
        workload_type: (detect-workload-type $current $history),
        time_of_day: (date now | format date "%H:%M"),
        environment: {
            monitoring_duration: ($history | length),
            avg_cpu_usage: (calculate-average-usage $history "cpu"),
            avg_mem_usage: (calculate-average-usage $history "mem")
        }
    }
    
    return $context
}

# Detect current workload type from system patterns
def detect-workload-type [current: record, history: list] -> string {
    let cpu_usage = ($current.cpu.usage_pct | default 0)
    let mem_usage = ($current.mem.used_pct | default 0)
    
    # Simple workload detection heuristics
    if ($cpu_usage > 70 and $mem_usage < 50) {
        "cpu_intensive"
    } else if ($cpu_usage < 30 and $mem_usage > 70) {
        "memory_intensive"  
    } else if ($cpu_usage > 50 and $mem_usage > 50) {
        "mixed_workload"
    } else {
        "light_usage"
    }
}

# Calculate average usage from historical data
def calculate-average-usage [history: list, metric_type: string] -> float {
    let values = (match $metric_type {
        "cpu" => ($history | where cpu.usage_pct != null | get cpu.usage_pct),
        "mem" => ($history | where mem.used_pct != null | get mem.used_pct),
        _ => []
    })
    
    if (($values | length) > 0) {
        $values | math avg
    } else {
        null
    }
}

# Get AI integration information and capabilities
export def get-ai-info [] -> record {
    let config = (get-ai-config)
    
    {
        name: "ai-integration-interface",
        version: "1.0.0",
        description: "Standardized interface for AI backend integration",
        backend_type: $config.backend_type,
        capabilities: [
            "system_optimization",
            "performance_analysis", 
            "resource_management",
            "anomaly_detection"
        ],
        supported_actions: ["adjust", "notify", "schedule"],
        confidence_threshold: $config.confidence_threshold,
        fallback_available: true
    }
}