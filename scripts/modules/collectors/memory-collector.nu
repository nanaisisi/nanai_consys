# Memory Metrics Collector Module  
# Collects system memory usage metrics with cross-platform compatibility
# Author: Nanai Consys Project
# Version: 1.0.0
# Dependencies: nushell sys command

use ../interfaces/schemas.nu

# Collect memory usage metrics
# Returns: record with total, used, used_pct fields or null on failure
# Example: let mem_data = (collect-metrics)
export def collect-metrics [] -> record {
    try {
        let m = (sys mem)
        let total = (try { $m.total } catch { null })
        let used = (try { $m.used } catch { null })
        let used2 = (if ($used | describe | str contains "nothing") { 
            try { $m.total - $m.free } catch { null } 
        } else { 
            $used 
        })
        let pct = (if ($total != null and $used2 != null and $total != 0) { 
            ($used2 / $total * 100) 
        } else { 
            null 
        })
        
        return { total: $total, used: $used2, used_pct: $pct }
    } catch {
        return null
    }
}

# Validate memory metrics data against expected schema
# Parameters: data (record) - Memory metrics data to validate
# Returns: bool - true if data matches schema, false otherwise  
export def validate-metrics [data: record] -> bool {
    if ($data == null) {
        return false
    }
    
    let required_fields = ["total", "used", "used_pct"]
    let has_required = ($required_fields | all {|field| $field in ($data | columns)})
    
    if (not $has_required) {
        return false
    }
    
    # Validate numeric fields
    let total_valid = (
        ($data.total == null) or 
        (($data.total | describe) == "int" and $data.total >= 0)
    )
    
    let used_valid = (
        ($data.used == null) or 
        (($data.used | describe) == "int" and $data.used >= 0)
    )
    
    let pct_valid = (
        ($data.used_pct == null) or 
        (($data.used_pct | describe) in ["int", "float"] and 
         $data.used_pct >= 0.0 and $data.used_pct <= 100.0)
    )
    
    return ($total_valid and $used_valid and $pct_valid)
}

# Get collector information and metadata
# Returns: record with collector details
export def get-collector-info [] -> record {
    {
        name: "memory-collector",
        version: "1.0.0", 
        description: "Collects system memory usage metrics",
        dependencies: ["sys mem"],
        supported_platforms: ["windows", "linux", "macos"],
        data_schema: "memory-metrics-schema",
        update_frequency: "high"
    }
}

# Check if memory collector is available on current system
# Returns: bool - true if collector can function
export def is-available [] -> bool {
    try {
        sys mem | length
        return true
    } catch {
        return false  
    }
}

# Collect extended memory metrics with additional details
# Returns: record with extended memory information
export def collect-extended-metrics [] -> record {
    let basic = (collect-metrics)
    if ($basic == null) {
        return null
    }
    
    try {
        let m = (sys mem)
        
        $basic | merge {
            free: (try { $m.free } catch { null }),
            available: (try { $m.available } catch { null }),
            buffers: (try { $m.buffers } catch { null }),
            cached: (try { $m.cached } catch { null }),
            swap_total: (try { $m.swap_total } catch { null }),
            swap_used: (try { $m.swap_used } catch { null }),
            swap_free: (try { $m.swap_free } catch { null })
        }
    } catch {
        return $basic
    }
}

# Calculate memory pressure indicator
# Parameters: data (record) - Memory metrics data
# Returns: string - pressure level: "low", "medium", "high", "critical"
export def calculate-memory-pressure [data: record] -> string {
    if ($data == null or $data.used_pct == null) {
        return "unknown"
    }
    
    let usage = $data.used_pct
    if ($usage < 50.0) {
        "low"
    } else if ($usage < 75.0) {
        "medium"  
    } else if ($usage < 90.0) {
        "high"
    } else {
        "critical"
    }
}