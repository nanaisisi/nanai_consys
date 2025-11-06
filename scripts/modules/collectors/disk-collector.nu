# Disk Metrics Collector Module
# Collects disk/storage usage metrics with cross-platform compatibility
# Author: Nanai Consys Project
# Version: 1.0.0
# Dependencies: nushell sys command

# Collect disk usage metrics
export def disk_collect_metrics [] {
    try {
        let disks = (sys disks)
        $disks | each {|disk|
            {
                name: ($disk.name | default "unknown"),
                mount: ($disk.mount | default "unknown"),
                file_system: ($disk.file_system | default "unknown"),
                total: ($disk.total | default 0),
                used: ($disk.used | default 0),
                used_pct: (if ($disk.total | default 0) > 0 {
                    (($disk.used | default 0) / ($disk.total | default 1) * 100.0)
                } else {
                    0.0
                })
            }
        }
    } catch {
        []
    }
}

# Validate disk metrics data
export def validate-metrics [data: list] {
    if ($data | describe) != "list" {
        return false
    }
    if ($data | length) == 0 {
        return true
    }
    let first = ($data | first)
    let required_fields = ["name", "mount", "file_system", "total", "used", "used_pct"]
    $required_fields | all {|field| $field in ($first | columns)}
}

# Get collector information
export def get-collector-info [] {
    {
        name: "disk-collector",
        version: "1.0.0",
        description: "Collects disk usage metrics",
        dependencies: ["sys disks"],
        supported_platforms: ["windows", "linux", "macos"],
        data_schema: "disk-metrics-schema",
        update_frequency: "medium"
    }
}

# Check if disk collector is available
export def is-available [] {
    try {
        sys disks
        return true
    } catch {
        return false
    }
}