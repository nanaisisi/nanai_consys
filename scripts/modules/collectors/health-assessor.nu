# System Health Assessor Module
# Provides system health and load level assessment based on collected metrics
# Author: Nanai Consys Project
# Version: 1.0.0
# Dependencies: None (pure analysis functions)

use ../interfaces/schemas.nu

# Assess overall system load level based on CPU and memory usage
# Parameters: cpu_rec (record) - CPU metrics, mem_rec (record) - Memory metrics  
# Returns: string - load level: "low", "mid", "high"
export def assess-load [cpu_rec: record, mem_rec: record] -> string {
    let cpu_pct = ($cpu_rec.usage_pct? | default 0 | into float)
    let mem_pct = ($mem_rec.used_pct? | default 0 | into float)
    
    if ($cpu_pct >= 80 or $mem_pct >= 80) { 
        "high" 
    } else if ($cpu_pct >= 50 or $mem_pct >= 50) { 
        "mid" 
    } else { 
        "low" 
    }
}

# Assess system stability from historical metrics data
# Parameters: history (list<record>) - Historical system snapshots
# Returns: record - stability assessment and trends
export def assess-stability [history: list] -> record {
    if (($history | length) < 3) {
        return {
            stability: "insufficient_data",
            trend: "unknown",
            volatility: null,
            assessment_period: ($history | length)
        }
    }
    
    # Calculate CPU usage volatility
    let cpu_values = ($history | where cpu.usage_pct != null | get cpu.usage_pct)
    let cpu_volatility = (if (($cpu_values | length) > 1) {
        ($cpu_values | math stddev)
    } else { 
        null 
    })
    
    # Calculate memory usage trend
    let mem_values = ($history | where mem.used_pct != null | get mem.used_pct)
    let mem_trend = (if (($mem_values | length) >= 3) {
        let first_third = ($mem_values | first 3 | math avg)
        let last_third = ($mem_values | last 3 | math avg)
        ($last_third - $first_third)
    } else { 
        null 
    })
    
    # Assess overall volatility
    let volatility_level = (if ($cpu_volatility != null) {
        if ($cpu_volatility < 5.0) {
            "stable"
        } else if ($cpu_volatility < 15.0) {
            "moderate"
        } else {
            "volatile"
        }
    } else {
        "unknown"
    })
    
    # Assess trend direction
    let trend_direction = (if ($mem_trend != null) {
        if ($mem_trend > 5.0) {
            "increasing"
        } else if ($mem_trend < -5.0) {
            "decreasing"  
        } else {
            "stable"
        }
    } else {
        "unknown"
    })
    
    # Overall stability assessment
    let stability = (if ($volatility_level == "stable" and $trend_direction in ["stable", "decreasing"]) {
        "stable"
    } else if ($volatility_level == "volatile" or $trend_direction == "increasing") {
        "unstable"
    } else {
        "moderate"
    })
    
    {
        stability: $stability,
        trend: $trend_direction,
        volatility: $volatility_level,
        cpu_volatility: $cpu_volatility,
        memory_trend: $mem_trend,
        assessment_period: ($history | length)
    }
}

# Detect performance anomalies by comparing current metrics to baseline
# Parameters: current (record) - Current system snapshot, baseline (record) - Baseline metrics
# Returns: list<record> - List of detected anomalies
export def detect-anomalies [current: record, baseline: record] -> list {
    let anomalies = []
    
    # CPU anomaly detection
    if ($current.cpu.usage_pct != null and $baseline.cpu.usage_pct != null) {
        let cpu_diff = ($current.cpu.usage_pct - $baseline.cpu.usage_pct)
        if ($cpu_diff > 30.0) {
            let anomalies = ($anomalies | append {
                type: "cpu_spike",
                severity: "high", 
                current_value: $current.cpu.usage_pct,
                baseline_value: $baseline.cpu.usage_pct,
                deviation: $cpu_diff,
                description: "CPU usage significantly higher than baseline"
            })
        }
    }
    
    # Memory anomaly detection  
    if ($current.mem.used_pct != null and $baseline.mem.used_pct != null) {
        let mem_diff = ($current.mem.used_pct - $baseline.mem.used_pct)
        if ($mem_diff > 25.0) {
            let anomalies = ($anomalies | append {
                type: "memory_spike",
                severity: "high",
                current_value: $current.mem.used_pct,
                baseline_value: $baseline.mem.used_pct, 
                deviation: $mem_diff,
                description: "Memory usage significantly higher than baseline"
            })
        }
    }
    
    # Disk space anomaly detection
    if (($current.disks | length) > 0 and ($baseline.disks | length) > 0) {
        $current.disks | each {|disk|
            let baseline_disk = ($baseline.disks | where mount == $disk.mount | first)
            if ($baseline_disk != null and $disk.used_pct != null and $baseline_disk.used_pct != null) {
                let disk_diff = ($disk.used_pct - $baseline_disk.used_pct)
                if ($disk_diff > 10.0) {  # Disk usage changes more slowly
                    let anomalies = ($anomalies | append {
                        type: "disk_usage_spike",
                        severity: "medium",
                        mount_point: $disk.mount,
                        current_value: $disk.used_pct,
                        baseline_value: $baseline_disk.used_pct,
                        deviation: $disk_diff,
                        description: $"Disk usage on ($disk.mount) significantly higher than baseline"
                    })
                }
            }
        }
    }
    
    return $anomalies
}

# Generate system health summary from multiple metrics
# Parameters: snapshot (record) - Current system snapshot
# Returns: record - Comprehensive health summary
export def generate-health-summary [snapshot: record] -> record {
    let load_level = (assess-load $snapshot.cpu $snapshot.mem)
    
    # Calculate component health scores (0-100)
    let cpu_health = (if ($snapshot.cpu.usage_pct != null) {
        100 - $snapshot.cpu.usage_pct
    } else { 
        null 
    })
    
    let memory_health = (if ($snapshot.mem.used_pct != null) {
        100 - $snapshot.mem.used_pct  
    } else { 
        null 
    })
    
    # Calculate average disk health
    let disk_health = (if (($snapshot.disks | length) > 0) {
        let disk_scores = ($snapshot.disks | where used_pct != null | each {|d| 100 - $d.used_pct})
        if (($disk_scores | length) > 0) {
            $disk_scores | math avg
        } else {
            null
        }
    } else {
        null
    })
    
    # Calculate overall health score
    let valid_scores = ([$cpu_health, $memory_health, $disk_health] | where $it != null)
    let overall_health = (if (($valid_scores | length) > 0) {
        $valid_scores | math avg
    } else {
        null
    })
    
    # Determine health status
    let health_status = (if ($overall_health != null) {
        if ($overall_health >= 80) {
            "excellent"
        } else if ($overall_health >= 60) {
            "good"  
        } else if ($overall_health >= 40) {
            "fair"
        } else {
            "poor"
        }
    } else {
        "unknown"
    })
    
    {
        timestamp: $snapshot.timestamp,
        load_level: $load_level,
        health_status: $health_status,
        overall_score: $overall_health,
        component_scores: {
            cpu: $cpu_health,
            memory: $memory_health,
            disk: $disk_health
        },
        recommendations: (generate-health-recommendations $snapshot $load_level $health_status)
    }
}

# Generate basic health recommendations based on current system state
# Parameters: snapshot (record), load_level (string), health_status (string)
# Returns: list<string> - List of recommendations
def generate-health-recommendations [snapshot: record, load_level: string, health_status: string] -> list {
    let recommendations = []
    
    # Load-based recommendations
    let recommendations = (if ($load_level == "high") {
        $recommendations | append "System is under high load - consider reducing active processes"
    } else {
        $recommendations
    })
    
    # Memory-specific recommendations
    if ($snapshot.mem.used_pct != null and $snapshot.mem.used_pct > 85) {
        let recommendations = ($recommendations | append "Memory usage is high - consider closing unused applications")
    }
    
    # Disk-specific recommendations
    let critical_disks = ($snapshot.disks | where used_pct != null and used_pct > 90)
    if (($critical_disks | length) > 0) {
        $critical_disks | each {|disk|
            let recommendations = ($recommendations | append $"Disk space critical on ($disk.mount) - cleanup recommended")
        }
    }
    
    # General health recommendations
    let recommendations = (if ($health_status == "poor") {
        $recommendations | append "Overall system health is poor - comprehensive optimization recommended"
    } else {
        $recommendations
    })
    
    return $recommendations
}

# Get assessor information and metadata
# Returns: record with assessor details  
export def get-assessor-info [] -> record {
    {
        name: "system-health-assessor",
        version: "1.0.0",
        description: "Provides comprehensive system health and load assessment",
        dependencies: [],
        supported_platforms: ["windows", "linux", "macos"],
        assessment_types: ["load_level", "stability", "anomalies", "health_summary"]
    }
}