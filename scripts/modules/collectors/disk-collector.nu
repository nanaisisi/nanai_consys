# Disk Metrics Collector Module
# Collects disk usage metrics for all mounted drives with cross-platform compatibility  
# Author: Nanai Consys Project
# Version: 1.0.0
# Dependencies: nushell sys command

use ../interfaces/schemas.nu

# Collect disk usage metrics for all mounted drives
# Returns: list<record> with disk metrics or empty list on failure
# Example: let disk_data = (collect-metrics)
export def collect-metrics [] -> list {
    try {
        let d = (sys disks)
        $d | each {|it|
            let total = (try { $it.total } catch { null })
            let used = (try { $it.used } catch { null })
            let used2 = (if ($used | describe | str contains "nothing") { 
                try { $it.total - $it.free } catch { null } 
            } else { 
                $used 
            })
            let pct = (if ($total != null and $used2 != null and $total != 0) { 
                ($used2 / $total * 100) 
            } else { 
                null 
            })
            
            {
                name: (try { $it.name } catch { null }),
                mount: (try { $it.mount } catch { null }),
                file_system: (try { $it.file_system } catch { null }),
                total: $total,
                used: $used2,
                used_pct: $pct
            }
        }
    } catch {
        return []
    }
}

# Validate disk metrics data against expected schema  
# Parameters: data (list) - Disk metrics data to validate
# Returns: bool - true if data matches schema, false otherwise
export def validate-metrics [data: list] -> bool {
    if ($data == null) {
        return false
    }
    
    # Empty list is valid (no disks detected)
    if (($data | length) == 0) {
        return true
    }
    
    # Validate each disk entry
    $data | all {|disk|
        let required_fields = ["name", "mount", "file_system", "total", "used", "used_pct"]
        let has_required = ($required_fields | all {|field| $field in ($disk | columns)})
        
        if (not $has_required) {
            return false
        }
        
        # Validate numeric fields
        let total_valid = (
            ($disk.total == null) or 
            (($disk.total | describe) == "int" and $disk.total >= 0)
        )
        
        let used_valid = (
            ($disk.used == null) or 
            (($disk.used | describe) == "int" and $disk.used >= 0)  
        )
        
        let pct_valid = (
            ($disk.used_pct == null) or
            (($disk.used_pct | describe) in ["int", "float"] and
             $disk.used_pct >= 0.0 and $disk.used_pct <= 100.0)
        )
        
        ($total_valid and $used_valid and $pct_valid)
    }
}

# Get collector information and metadata
# Returns: record with collector details
export def get-collector-info [] -> record {
    {
        name: "disk-collector",
        version: "1.0.0",
        description: "Collects disk usage metrics for all mounted drives", 
        dependencies: ["sys disks"],
        supported_platforms: ["windows", "linux", "macos"],
        data_schema: "disk-metrics-schema",
        update_frequency: "medium"  # Updated less frequently than CPU/memory
    }
}

# Check if disk collector is available on current system
# Returns: bool - true if collector can function  
export def is-available [] -> bool {
    try {
        sys disks | length
        return true
    } catch {
        return false
    }
}

# Collect metrics for specific mount point
# Parameters: mount_point (string) - Specific mount point to collect
# Returns: record - disk metrics for the specified mount point or null
export def collect-mount-metrics [mount_point: string] -> record {
    let all_disks = (collect-metrics)
    $all_disks | where mount == $mount_point | first
}

# Get disk with highest usage percentage
# Returns: record - disk with highest usage or null if no disks
export def get-highest-usage-disk [] -> record {
    let disks = (collect-metrics)
    if (($disks | length) == 0) {
        return null
    }
    
    $disks 
    | where used_pct != null 
    | sort-by used_pct 
    | reverse 
    | first
}

# Calculate disk space availability status
# Parameters: data (list) - Disk metrics data
# Returns: record - summary of disk space status
export def calculate-disk-status [data: list] -> record {
    if ($data == null or ($data | length) == 0) {
        return {
            status: "unknown",
            critical_disks: [],
            warning_disks: [],
            total_disks: 0
        }
    }
    
    let critical_disks = ($data | where used_pct != null and used_pct > 95.0)
    let warning_disks = ($data | where used_pct != null and used_pct > 80.0 and used_pct <= 95.0)
    
    let status = if (($critical_disks | length) > 0) {
        "critical"
    } else if (($warning_disks | length) > 0) {
        "warning"  
    } else {
        "healthy"
    }
    
    {
        status: $status,
        critical_disks: ($critical_disks | get mount),
        warning_disks: ($warning_disks | get mount),
        total_disks: ($data | length)
    }
}