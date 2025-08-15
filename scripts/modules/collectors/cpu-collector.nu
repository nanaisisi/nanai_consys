# CPU Metrics Collector Module
# Collects CPU usage metrics across all cores with cross-platform compatibility
# Author: Nanai Consys Project
# Version: 1.0.0
# Dependencies: nushell sys command

use ../interfaces/schemas.nu

# Collect CPU usage metrics across all cores
# Returns: record with usage_pct (float) and per_core (list) or null on failure
# Example: let cpu_data = (collect-metrics)
export def collect-metrics [] -> record {
    try {
        let t = (sys cpu -l)
        if (($t | length) == 0) {
            # fallback: try aggregated record if available
            let u = (try { (sys | get cpu | get usage) } catch { null })
            return { usage_pct: ($u | default null), per_core: null }
        } else {
            let per = (try { $t | select name usage } catch { $t })
            let usages = (try { $per | get usage } catch { [] })
            let avg = (if (($usages | length) > 0) { $usages | math avg } else { null })
            return { usage_pct: $avg, per_core: $per }
        }
    } catch {
        return null
    }
}

# Validate CPU metrics data against expected schema
# Parameters: data (record) - CPU metrics data to validate
# Returns: bool - true if data matches schema, false otherwise
export def validate-metrics [data: record] -> bool {
    if ($data == null) {
        return false
    }
    
    let required_fields = ["usage_pct", "per_core"]
    let has_required = ($required_fields | all {|field| $field in ($data | columns)})
    
    if (not $has_required) {
        return false
    }
    
    # Validate usage_pct is numeric or null
    let usage_valid = (
        ($data.usage_pct == null) or 
        (($data.usage_pct | describe) in ["int", "float"])
    )
    
    # Validate per_core is list or null
    let per_core_valid = (
        ($data.per_core == null) or 
        (($data.per_core | describe) == "list")
    )
    
    return ($usage_valid and $per_core_valid)
}

# Get collector information and metadata
# Returns: record with collector details
export def get-collector-info [] -> record {
    {
        name: "cpu-collector",
        version: "1.0.0",
        description: "Collects CPU usage metrics across all cores",
        dependencies: ["sys cpu"],
        supported_platforms: ["windows", "linux", "macos"],
        data_schema: "cpu-metrics-schema",
        update_frequency: "high"  # Can be updated frequently
    }
}

# Check if CPU collector is available on current system
# Returns: bool - true if collector can function
export def is-available [] -> bool {
    try {
        sys cpu -l | length
        return true
    } catch {
        return false
    }
}

# Collect extended CPU metrics with additional details
# Returns: record with extended CPU information
export def collect-extended-metrics [] -> record {
    let basic = (collect-metrics)
    if ($basic == null) {
        return null
    }
    
    try {
        let sys_info = (sys)
        let cpu_info = ($sys_info | get cpu)
        
        $basic | merge {
            cpu_count: (try { $cpu_info.cpu_count } catch { null }),
            architecture: (try { $cpu_info.arch } catch { null }),
            brand: (try { $cpu_info.brand } catch { null }),
            frequency: (try { $cpu_info.freq } catch { null })
        }
    } catch {
        return $basic
    }
}