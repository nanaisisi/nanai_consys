# GPU Metrics Collector Module
# Collects GPU usage metrics from available vendor tools with cross-platform support
# Author: Nanai Consys Project  
# Version: 1.0.0
# Dependencies: nvidia-smi (NVIDIA), rocm-smi (AMD)

use ../interfaces/schemas.nu

# Collect GPU usage metrics from available vendor tools
# Returns: list<record> with GPU metrics or empty list if no GPUs detected
# Example: let gpu_data = (collect-metrics)
export def collect-metrics [] -> list {
    # Try NVIDIA GPUs first
    let nvidia_gpus = (collect-nvidia-metrics)
    if (($nvidia_gpus | length) > 0) {
        return $nvidia_gpus
    }
    
    # Try AMD GPUs
    let amd_gpus = (collect-amd-metrics) 
    if (($amd_gpus | length) > 0) {
        return $amd_gpus
    }
    
    # No GPUs detected
    return []
}

# Collect NVIDIA GPU metrics using nvidia-smi
# Returns: list<record> with NVIDIA GPU metrics
def collect-nvidia-metrics [] -> list {
    if ((which nvidia-smi | length) == 0) {
        return []
    }
    
    try {
        let out = (nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits | lines)
        let rows = ($out | each {|l|
            let f = ($l | split row ",") | each {|x| $x | str trim }
            let util = (try { $f.0 | into int } catch { null })
            let mem_used = (try { $f.1 | into int } catch { null })
            let mem_total = (try { $f.2 | into int } catch { null })
            let mem_pct = (if ($mem_total != null and $mem_total != 0) { 
                ($mem_used * 100 / $mem_total) 
            } else { 
                null 
            })
            { 
                vendor: "nvidia", 
                usage_pct: $util, 
                mem_used_mib: $mem_used, 
                mem_total_mib: $mem_total, 
                mem_used_pct: $mem_pct 
            }
        })
        return $rows
    } catch {
        return []
    }
}

# Collect AMD GPU metrics using rocm-smi
# Returns: list<record> with AMD GPU metrics (best effort)
def collect-amd-metrics [] -> list {
    if ((which rocm-smi | length) == 0) {
        return []
    }
    
    try {
        let raw = (rocm-smi --showuse --json)
        let parsed = ($raw | from json)
        
        # rocm-smi JSON format varies, attempt to extract useful data
        # This is a best-effort implementation
        if ($parsed != null) {
            # Return basic AMD GPU placeholder data
            return [{
                vendor: "amd",
                usage_pct: null,
                mem_used_mib: null,
                mem_total_mib: null,
                mem_used_pct: null,
                raw_data: $parsed
            }]
        }
        
        return []
    } catch {
        return []
    }
}

# Validate GPU metrics data against expected schema
# Parameters: data (list) - GPU metrics data to validate  
# Returns: bool - true if data matches schema, false otherwise
export def validate-metrics [data: list] -> bool {
    if ($data == null) {
        return false
    }
    
    # Empty list is valid (no GPUs detected)
    if (($data | length) == 0) {
        return true
    }
    
    # Validate each GPU entry  
    $data | all {|gpu|
        let required_fields = ["vendor", "usage_pct", "mem_used_mib", "mem_total_mib", "mem_used_pct"]
        let has_required = ($required_fields | all {|field| $field in ($gpu | columns)})
        
        if (not $has_required) {
            return false
        }
        
        # Validate vendor field
        let vendor_valid = ($gpu.vendor in ["nvidia", "amd", "intel", "unknown"])
        
        # Validate numeric fields (can be null)
        let usage_valid = (
            ($gpu.usage_pct == null) or
            (($gpu.usage_pct | describe) in ["int", "float"] and
             $gpu.usage_pct >= 0.0 and $gpu.usage_pct <= 100.0)
        )
        
        let mem_used_valid = (
            ($gpu.mem_used_mib == null) or
            (($gpu.mem_used_mib | describe) == "int" and $gpu.mem_used_mib >= 0)
        )
        
        let mem_total_valid = (
            ($gpu.mem_total_mib == null) or  
            (($gpu.mem_total_mib | describe) == "int" and $gpu.mem_total_mib >= 0)
        )
        
        let mem_pct_valid = (
            ($gpu.mem_used_pct == null) or
            (($gpu.mem_used_pct | describe) in ["int", "float"] and
             $gpu.mem_used_pct >= 0.0 and $gpu.mem_used_pct <= 100.0)
        )
        
        ($vendor_valid and $usage_valid and $mem_used_valid and $mem_total_valid and $mem_pct_valid)
    }
}

# Get collector information and metadata
# Returns: record with collector details
export def get-collector-info [] -> record {
    {
        name: "gpu-collector", 
        version: "1.0.0",
        description: "Collects GPU usage metrics from available vendor tools",
        dependencies: ["nvidia-smi (optional)", "rocm-smi (optional)"],
        supported_platforms: ["windows", "linux", "macos"],
        data_schema: "gpu-metrics-schema",
        update_frequency: "medium",
        optional: true  # GPU collection is optional
    }
}

# Check if any GPU collector tools are available on current system
# Returns: bool - true if any GPU tools are available
export def is-available [] -> bool {
    ((which nvidia-smi | length) > 0) or ((which rocm-smi | length) > 0)
}

# Get available GPU vendor tools
# Returns: list<string> - list of available vendor tools  
export def get-available-tools [] -> list {
    let tools = []
    let tools = (if ((which nvidia-smi | length) > 0) { 
        $tools | append "nvidia-smi" 
    } else { 
        $tools 
    })
    let tools = (if ((which rocm-smi | length) > 0) { 
        $tools | append "rocm-smi" 
    } else { 
        $tools 
    })
    return $tools
}

# Calculate GPU utilization status across all GPUs
# Parameters: data (list) - GPU metrics data
# Returns: record - summary of GPU utilization status
export def calculate-gpu-status [data: list] -> record {
    if ($data == null or ($data | length) == 0) {
        return {
            status: "no_gpu",
            total_gpus: 0,
            high_usage_gpus: 0,
            avg_usage: null,
            avg_memory_usage: null
        }
    }
    
    let valid_usage = ($data | where usage_pct != null | get usage_pct)
    let valid_mem = ($data | where mem_used_pct != null | get mem_used_pct)
    
    let avg_usage = (if (($valid_usage | length) > 0) { 
        $valid_usage | math avg 
    } else { 
        null 
    })
    
    let avg_memory = (if (($valid_mem | length) > 0) { 
        $valid_mem | math avg 
    } else { 
        null 
    })
    
    let high_usage_count = ($valid_usage | where $it > 80.0 | length)
    
    let status = if ($avg_usage != null and $avg_usage > 80.0) {
        "high_load"
    } else if ($avg_usage != null and $avg_usage > 50.0) {
        "medium_load"
    } else if ($avg_usage != null) {
        "low_load"
    } else {
        "unknown"
    }
    
    {
        status: $status,
        total_gpus: ($data | length),
        high_usage_gpus: $high_usage_count,
        avg_usage: $avg_usage,
        avg_memory_usage: $avg_memory
    }
}