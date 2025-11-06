# AI Integration Module for Nanai Consys
# Provides AI-powered evaluation and recommendations
# Author: Nanai Consys Project
# Version: 1.0.0

# Prepare evaluation context from current metrics and history
export def prepare-evaluation-context [current: record, history: list] {
    {
        system_load: $current.level,
        cpu_usage: ($current.cpu.usage_pct | default 0.0),
        mem_usage: ($current.mem.used_pct | default 0.0),
        gpu_count: ($current.gpu | length),
        historical_trend: (if ($history | length) > 0 {
            let avg_cpu = ($history | get cpu.usage_pct | math avg)
            let avg_mem = ($history | get mem.used_pct | math avg)
            $"Historical averages: CPU (" + ($avg_cpu | string) + "%), Memory (" + ($avg_mem | string) + "%)"
        } else {
            "No historical data available"
        }),
        timestamp: (date now | format date "%+")
    }
}

# Evaluate system and provide AI recommendations
export def evaluate-system [request: record] {
    let metrics = $request.metrics
    let context = $request.context
    
    # Simple rule-based AI simulation
    let cpu_usage = ($metrics.cpu.usage_pct | default 0.0)
    let mem_usage = ($metrics.mem.used_pct | default 0.0)
    
    let recommendations = if ($cpu_usage > 80.0) {
        [{
            type: "performance",
            category: "resource",
            description: "High CPU usage detected. Consider optimizing running processes.",
            parameters: {action: "analyze_processes"},
            priority: "high"
        }]
    } else if ($mem_usage > 85.0) {
        [{
            type: "resource",
            category: "memory",
            description: "High memory usage detected. Consider closing unused applications.",
            parameters: {action: "free_memory"},
            priority: "high"
        }]
    } else if (($cpu_usage > 50.0) or ($mem_usage > 60.0)) {
        [{
            type: "optimization",
            category: "performance", 
            description: "Moderate system load. Consider background optimizations.",
            parameters: {action: "optimize_background"},
            priority: "medium"
        }]
    } else {
        [{
            type: "maintenance",
            category: "general",
            description: "System running normally. Regular maintenance recommended.",
            parameters: {action: "routine_check"},
            priority: "low"
        }]
    }
    
    {
        confidence: 0.8,
        category: "system_optimization",
        actions: $recommendations,
        reasoning: $"Analysis based on current CPU {$cpu_usage}% and memory {$mem_usage}% usage",
        metadata: {
            evaluation_method: "rule_based_simulation",
            evaluated_at: (date now | format date "%+")
        }
    }
}

# Validate AI response format
export def validate-response [response: record] {
    let required_fields = ["confidence", "category", "actions", "reasoning", "metadata"]
    let has_required = $required_fields | all {|field| $field in ($response | columns)}
    let actions_valid = ($response.actions | describe) == "list"
    let confidence_valid = ($response.confidence | describe) in ["float", "int"]
    $has_required and $actions_valid and $confidence_valid
}

# Check privacy compliance for data handling
export def check-privacy-compliance [data: record] {
    # Ensure no personally identifiable information (PII) is included
    let sensitive_fields = ["user_id", "username", "email", "ip_address", "location"]
    let has_pii = $sensitive_fields | any {|field| $field in ($data | columns)}
    if $has_pii {
        error make {msg: "Privacy violation: PII detected in data"}
    } else {
        {compliant: true, message: "Data is privacy-compliant"}
    }
}

# Get AI backend information
export def get-ai-info [] {
    {
        backend: "rule_based_simulation",
        version: "1.0.0",
        capabilities: ["system_evaluation", "resource_optimization", "performance_analysis"],
        supported_platforms: ["windows", "linux", "macos"],
        description: "Simple rule-based AI simulation for system monitoring and optimization",
        privacy_features: ["PII detection", "data anonymization"]
    }
}