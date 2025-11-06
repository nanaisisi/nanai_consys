# Health Assessor Module for Nanai Consys
# Assesses system load levels based on CPU and memory metrics
# Author: Nanai Consys Project
# Version: 1.0.0

# Assess load level based on CPU and memory usage
export def assess-load [cpu: record, mem: record] {
    let cpu_usage = ($cpu.usage_pct | default 0.0)
    let mem_usage = ($mem.used_pct | default 0.0)
    
    let avg_usage = (($cpu_usage + $mem_usage) / 2.0)
    
    if $avg_usage < 30.0 {
        "low"
    } else if $avg_usage < 70.0 {
        "mid"
    } else {
        "high"
    }
}

# Generate basic health summary
export def generate-health-summary [current: record] {
    let cpu = ($current.cpu | default {usage_pct: 0.0})
    let mem = ($current.mem | default {used_pct: 0.0})
    let gpu = ($current.gpu | default [])
    
    let cpu_usage = ($cpu.usage_pct | default 0.0)
    let mem_usage = ($mem.used_pct | default 0.0)
    let gpu_count = ($gpu | length)
    
    $"CPU: ($cpu_usage)%, Memory: ($mem_usage)%, GPUs: ($gpu_count)"
}