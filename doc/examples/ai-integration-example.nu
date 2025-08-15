# Example AI Integration Implementation
# Demonstrates how to integrate the monitoring system with AI for optimization
# This is a complete working example showing the 3-layer architecture in action

use ../modules/collectors/cpu-collector.nu as cpu
use ../modules/collectors/memory-collector.nu as memory  
use ../modules/collectors/disk-collector.nu as disk
use ../modules/collectors/gpu-collector.nu as gpu
use ../modules/collectors/health-assessor.nu as health
use ../modules/evaluators/ai-integration.nu as ai
use ../modules/interfaces/schemas.nu as schemas

# Example 1: Basic System Analysis with AI Recommendations
export def analyze-system-with-ai [] {
    print "🔍 Collecting system metrics..."
    
    # Collection Layer - Gather metrics from all collectors
    let cpu_metrics = (cpu collect-metrics)
    let memory_metrics = (memory collect-metrics)
    let disk_metrics = (disk collect-metrics)
    let gpu_metrics = (gpu collect-metrics)
    
    # Create system snapshot
    let snapshot = {
        timestamp: (date now | format date "%+"),
        level: (health assess-load $cpu_metrics $memory_metrics),
        cpu: $cpu_metrics,
        mem: $memory_metrics,
        disks: $disk_metrics,
        gpu: $gpu_metrics
    }
    
    print $"📊 System Status: ($snapshot.level) load"
    print $"   CPU Usage: ($snapshot.cpu.usage_pct)%"
    print $"   Memory Usage: ($snapshot.mem.used_pct)%"
    print $"   Disks: ($snapshot.disks | length) monitored"
    print $"   GPUs: ($snapshot.gpu | length) detected"
    
    # Evaluation Layer - Prepare for AI analysis
    print "\n🤖 Preparing AI evaluation..."
    
    let context = (ai prepare-evaluation-context $snapshot [])
    let ai_request = {
        metrics: $snapshot,
        history: [],  # In real usage, load from metrics.ndjson
        context: $context
    }
    
    # Get AI recommendations
    let ai_response = (ai evaluate-system $ai_request)
    
    # Application Layer - Present results and recommendations  
    print "\n💡 AI Analysis Results:"
    print $"   Confidence: ($ai_response.confidence * 100)%"
    print $"   Category: ($ai_response.category)"
    print $"   Reasoning: ($ai_response.reasoning)"
    
    if (($ai_response.actions | length) > 0) {
        print "\n📋 Recommended Actions:"
        $ai_response.actions | each {|action|
            print $"   • [$($action.priority)] $($action.description)"
        } | ignore
    } else {
        print "   No specific actions recommended - system appears optimal"
    }
    
    return $ai_response
}

# Example 2: Historical Trend Analysis
export def analyze-historical-trends [log_path?: string] {
    let log_file = ($log_path | default ($nu.data-dir | path join "nanai_consys" | path join "metrics.ndjson"))
    
    if (not ($log_file | path exists)) {
        print $"⚠️  No historical data found at ($log_file)"
        print "   Run the monitor for a while to collect data first"
        return null
    }
    
    print "📈 Loading historical data..."
    let history = (open $log_file | from ndjson | last 50)  # Last 50 data points
    
    print $"   Loaded ($history | length) data points"
    
    # Analyze stability trends
    let stability = (health assess-stability $history)
    print $"\n📊 System Stability Analysis:"
    print $"   Overall Stability: ($stability.stability)"
    print $"   Trend Direction: ($stability.trend)"
    print $"   Volatility: ($stability.volatility)"
    
    # Current vs baseline anomaly detection
    if (($history | length) >= 2) {
        let current = ($history | last)
        let baseline = ($history | first (($history | length) / 2) | last)  # Mid-point as baseline
        
        let anomalies = (health detect-anomalies $current $baseline)
        if (($anomalies | length) > 0) {
            print "\n⚠️  Detected Anomalies:"
            $anomalies | each {|anomaly|
                print $"   • $($anomaly.type): $($anomaly.description)"
                print $"     Severity: $($anomaly.severity), Deviation: ($anomaly.deviation)"
            } | ignore
        } else {
            print "\n✅ No significant anomalies detected"
        }
    }
    
    return $stability
}

# Example 3: Comprehensive System Health Report
export def generate-health-report [] {
    print "🏥 Generating Comprehensive Health Report..."
    
    # Collect current metrics
    let snapshot = {
        timestamp: (date now | format date "%+"),
        level: (health assess-load (cpu collect-metrics) (memory collect-metrics)),
        cpu: (cpu collect-metrics),
        mem: (memory collect-metrics),
        disks: (disk collect-metrics),
        gpu: (gpu collect-metrics)
    }
    
    # Generate health summary
    let health_summary = (health generate-health-summary $snapshot)
    
    print $"\n📋 System Health Report - ($snapshot.timestamp)"
    print "=" * 50
    
    print $"Overall Health: ($health_summary.health_status) ($health_summary.overall_score)%"
    print $"Load Level: ($health_summary.load_level)"
    
    print "\n📊 Component Health Scores:"
    print $"   CPU Health: ($health_summary.component_scores.cpu)%"
    print $"   Memory Health: ($health_summary.component_scores.memory)%"
    if ($health_summary.component_scores.disk != null) {
        print $"   Disk Health: ($health_summary.component_scores.disk)%"
    }
    
    # Detailed component analysis
    print "\n🔍 Detailed Analysis:"
    
    # CPU Analysis
    if ($snapshot.cpu.usage_pct != null) {
        let cpu_status = if ($snapshot.cpu.usage_pct < 20) { "💚 Excellent" 
        } else if ($snapshot.cpu.usage_pct < 50) { "💛 Good"
        } else if ($snapshot.cpu.usage_pct < 80) { "🧡 Moderate"
        } else { "🔴 High" }
        print $"   CPU: ($cpu_status) - ($snapshot.cpu.usage_pct)% utilization"
    }
    
    # Memory Analysis  
    if ($snapshot.mem.used_pct != null) {
        let mem_status = if ($snapshot.mem.used_pct < 30) { "💚 Excellent"
        } else if ($snapshot.mem.used_pct < 60) { "💛 Good"  
        } else if ($snapshot.mem.used_pct < 85) { "🧡 Moderate"
        } else { "🔴 High" }
        print $"   Memory: ($mem_status) - ($snapshot.mem.used_pct)% used"
    }
    
    # Disk Analysis
    let disk_status = (disk calculate-disk-status $snapshot.disks)
    let disk_emoji = match $disk_status.status {
        "healthy" => "💚",
        "warning" => "💛", 
        "critical" => "🔴",
        _ => "❓"
    }
    print $"   Disks: ($disk_emoji) ($disk_status.status) - ($disk_status.total_disks) disks monitored"
    
    # GPU Analysis (if available)
    if (($snapshot.gpu | length) > 0) {
        let gpu_status = (gpu calculate-gpu-status $snapshot.gpu)
        let gpu_emoji = match $gpu_status.status {
            "low_load" => "💚",
            "medium_load" => "💛",
            "high_load" => "🔴", 
            _ => "❓"
        }
        print $"   GPU: ($gpu_emoji) ($gpu_status.status) - ($gpu_status.total_gpus) GPUs detected"
    }
    
    # Recommendations
    if (($health_summary.recommendations | length) > 0) {
        print "\n💡 Health Recommendations:"
        $health_summary.recommendations | each {|rec|
            print $"   • $rec"
        } | ignore
    }
    
    return $health_summary
}

# Example 4: Collector Diagnostics
export def diagnose-collectors [] {
    print "🔧 Diagnosing System Collectors..."
    
    # Test each collector
    let collectors = [
        {name: "CPU", test: {|| cpu collect-metrics}, validate: {|data| cpu validate-metrics $data}, info: {|| cpu get-collector-info}, available: {|| cpu is-available}},
        {name: "Memory", test: {|| memory collect-metrics}, validate: {|data| memory validate-metrics $data}, info: {|| memory get-collector-info}, available: {|| memory is-available}},
        {name: "Disk", test: {|| disk collect-metrics}, validate: {|data| disk validate-metrics $data}, info: {|| disk get-collector-info}, available: {|| disk is-available}},
        {name: "GPU", test: {|| gpu collect-metrics}, validate: {|data| gpu validate-metrics $data}, info: {|| gpu get-collector-info}, available: {|| gpu is-available}}
    ]
    
    $collectors | each {|collector|
        print $"\n📋 Testing ($collector.name) Collector:"
        
        # Check availability
        let available = (try { 
            do $collector.available
        } catch { 
            false 
        })
        print $"   Available: ($available)"
        
        if $available {
            # Test data collection
            let data = (try { 
                do $collector.test 
            } catch { 
                null 
            })
            
            if ($data != null) {
                print "   ✅ Collection: Success"
                
                # Test validation
                let valid = (try {
                    do $collector.validate $data
                } catch {
                    false
                })
                print $"   ✅ Validation: ($valid)"
                
                # Show sample data
                print $"   📊 Sample: ($data | to json -r | str substring 0..100)..."
            } else {
                print "   ❌ Collection: Failed"
            }
            
            # Get collector info
            let info = (try {
                do $collector.info
            } catch {
                null
            })
            
            if ($info != null) {
                print $"   ℹ️  Version: ($info.version)"
                print $"   ℹ️  Update Frequency: ($info.update_frequency)"
            }
        } else {
            print "   ⚠️  Collector not available on this system"
        }
    } | ignore
    
    print "\n🏁 Diagnostics completed!"
}

# Usage examples in comments:
# 
# Run basic AI analysis:
# nu -c "use doc/examples/ai-integration-example.nu; analyze-system-with-ai"
#
# Generate health report:  
# nu -c "use doc/examples/ai-integration-example.nu; generate-health-report"
#
# Diagnose all collectors:
# nu -c "use doc/examples/ai-integration-example.nu; diagnose-collectors"