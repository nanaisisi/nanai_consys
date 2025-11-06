# Nushell system metrics monitor (cross-platform) - Modular Architecture
# Main orchestrator for the Nanai Consys monitoring system
# Author: Nanai Consys Project
# Version: 2.0.0 - Refactored with modular architecture
# Dependencies: Collector modules, evaluator modules, interface schemas

source c:/Users/masak/project/rust/nanai_consys/scripts/modules/collectors/cpu-collector.nu
source c:/Users/masak/project/rust/nanai_consys/scripts/modules/collectors/memory-collector.nu
source c:/Users/masak/project/rust/nanai_consys/scripts/modules/collectors/disk-collector.nu
source c:/Users/masak/project/rust/nanai_consys/scripts/modules/collectors/gpu-collector.nu
source c:/Users/masak/project/rust/nanai_consys/scripts/modules/collectors/health-assessor.nu
source c:/Users/masak/project/rust/nanai_consys/scripts/modules/interfaces/schemas.nu

# Main monitoring orchestrator with support for AI evaluation
export def main [
  --once        # run once and print JSON to stdout (and optionally save)
  --interval:int = 5  # seconds between samples when running as a daemon
  --log-path:path     # optional: where to write NDJSON (default: $nu.data-dir/nanai_consys/metrics.ndjson)
  --ai-evaluate     # enable AI-based evaluation and recommendations
  --config-path:path  # optional: path to configuration file
] {
  let log_path = (if ($log_path | is-empty) {
    let dir = ($nu.data-dir | path join "nanai_consys")
    mkdir $dir | ignore
    $dir | path join "metrics.ndjson"
  } else { $log_path })

  if $once {
    let snap = (collect-snapshot)
    $snap | to json -r | print
    # also write a last.json for convenience
    let last_path = ($log_path | path dirname | path join "last.json")
    $snap | to json -r | save -f $last_path
    
    # Perform AI evaluation if requested
    if $ai_evaluate {
      let history = (load-recent-history $log_path 10)
      let evaluation = (evaluate-with-ai $snap $history)
      $evaluation | to json -r | print
    }
    
    return
  }

  # Main monitoring loop with modular architecture
  loop {
    let snap = (collect-snapshot)
    $snap | to json -r | save --append $log_path
    # also refresh last.json for consumers
    let last_path = ($log_path | path dirname | path join "last.json")
    $snap | to json -r | save -f $last_path
    
    # Perform periodic AI evaluation if enabled
    if $ai_evaluate {
      let history = (load-recent-history $log_path 10)
      let evaluation = (evaluate-with-ai $snap $history)
      
      # Save evaluation results
      let eval_path = ($log_path | path dirname | path join "evaluations.ndjson")
      $evaluation | to json -r | save --append $eval_path
    }
    
    sleep ($interval | into duration --unit sec)
  }
}

# Build one snapshot record using modular collectors
def collect-snapshot [] {
  let ts = (date now | format date "%+")
  let cpu_metrics = (cpu_collect_metrics)
  let mem_metrics = (memory_collect_metrics)
  let disk_metrics = (disk_collect_metrics)
  let gpu_metrics = (gpu_collect_metrics)
  let load_level = (assess-load $cpu_metrics $mem_metrics)
  
  {
    timestamp: $ts,
    level: $load_level,
    cpu: $cpu_metrics,
    mem: $mem_metrics,
    disks: $disk_metrics,
    gpu: $gpu_metrics
  }
}

# Load recent historical data for AI evaluation
def load-recent-history [log_path: string, count: int] {
  try {
    if ($log_path | path exists) {
      open $log_path | lines | each {|line| $line | from json} | last $count
    } else {
      []
    }
  } catch {
    []
  }
}

# Evaluate system with AI integration
def evaluate-with-ai [current: record, history: list] {
  try {
    source c:/Users/masak/project/rust/nanai_consys/scripts/modules/evaluators/ai-integration.nu
    
    # Prepare evaluation request
    let context = (prepare-evaluation-context $current $history)
    let request = {
      metrics: $current,
      history: $history,
      context: $context
    }
    
    # Get AI evaluation
    let evaluation = (evaluate-system $request)
    
    # Add metadata about the evaluation
    $evaluation | merge {
      metadata: ($evaluation.metadata | merge {
        evaluation_timestamp: (date now | format date "%+"),
        system_snapshot: $current.timestamp,
        history_points: ($history | length)
      })
    }
  } catch {
    # Fallback to basic health assessment if AI evaluation fails
    let health_summary = (generate-health-summary $current)
    {
      confidence: 0.5,
      category: "health_assessment_fallback",
      actions: [],
      reasoning: "AI evaluation failed, using basic health assessment",
      metadata: {
        fallback: true,
        health_summary: $health_summary
      }
    }
  }
}

# Legacy compatibility functions - Deprecated, use modular collectors instead
# These functions are kept for backward compatibility but will be removed in future versions

# @deprecated Use cpu_collect_metrics instead  
def get-cpu [] {
  cpu_collect_metrics
}

# @deprecated Use memory_collect_metrics instead
def get-mem [] {
  memory_collect_metrics
}

# @deprecated Use disk_collect_metrics instead
def get-disks [] {
  disk_collect_metrics
}

# @deprecated Use gpu_collect_metrics instead
def get-gpu [] {
  gpu_collect_metrics
}

# @deprecated Use assess-load instead
def legacy-assess-load [cpu_rec, mem_rec] {
  assess-load $cpu_rec $mem_rec
}

# Convenience function: run once and save to default path
export def snapshot [] {
  main --once
}

# New convenience function: run once with AI evaluation
export def ai-snapshot [] {
  main --once --ai-evaluate
}
