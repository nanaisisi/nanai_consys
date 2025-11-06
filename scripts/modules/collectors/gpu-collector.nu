# GPU Collector Module for Nanai Consys
# Collects GPU metrics using platform-specific tools and APIs
# Author: Nanai Consys Project
# Version: 1.0.0

# Collect GPU metrics using available tools
export def gpu_collect_metrics [] {
  # Try platform-specific collection methods
  let gpu_data = (try-collect-gpu)
  
  # Return standardized format
  if ($gpu_data | is-empty) {
    []
  } else {
    $gpu_data | each {|gpu|
      {
        vendor: ($gpu.vendor | default "unknown"),
        usage_pct: ($gpu.usage_pct | default 0.0),
        mem_used_mib: ($gpu.mem_used_mib | default null),
        mem_total_mib: ($gpu.mem_total_mib | default null),
        mem_used_pct: ($gpu.mem_used_pct | default null)
      }
    }
  }
}

# Attempt to collect GPU data using available methods
def try-collect-gpu [] {
  # Linux: try nvtop
  if ($nu.os-info.name == "linux") {
    let nvtop_data = (collect-nvtop)
    if (not ($nvtop_data | is-empty)) {
      return $nvtop_data
    }
  }
  
  # Windows: try Rust-based Windows Performance Monitor collector
  if ($nu.os-info.name == "windows") {
    let rust_data = (collect-rust-dxgi)
    if (not ($rust_data | is-empty)) {
      return $rust_data
    }
    
    # Fallback to PowerShell
    let ps_data = (collect-powershell)
    if (not ($ps_data | is-empty)) {
      return $ps_data
    }
  }
  
  # macOS or others: no GPU data
  []
}

# Collect GPU data using nvtop (Linux)
def collect-nvtop [] {
  if (which nvtop | length) == 0 {
    return []
  }
  
  try {
    let out = (run-external "sh" "-c" "timeout 1 nvtop 2>/dev/null | head -20" | complete)
    if ($out.exit_code != 0) {
      return []
    }
    
    let lines = ($out.stdout | lines)
    let gpu_lines = ($lines | where {|l| $l =~ "Utilization"})
    
    $gpu_lines | each {|line|
      # Example: GPU 0: NVIDIA GeForce RTX 3080 [Utilization: 45%]
      let parts = ($line | split row ":")
      if (($parts | length) >= 3) {
        let util_str = ($parts.2 | str trim | str replace "%" "" | str replace "[" "" | str replace "]" "")
        let util = (try { $util_str | into float } catch { 0.0 })
        {
          vendor: "nvtop",
          usage_pct: $util,
          mem_used_mib: null,
          mem_total_mib: null,
          mem_used_pct: null
        }
      } else {
        null
      }
    } | where {|x| $x != null}
  } catch {
    []
  }
}

# Collect GPU data using Rust Windows Performance Monitor collector (Windows)
def collect-rust-dxgi [] {
  let rust_exe = ("target/debug/nanai_consys.exe" | path expand)
  
  if (not ($rust_exe | path exists)) {
    return []
  }
  
  try {
    let out = (run-external $rust_exe [] | complete)
    if ($out.exit_code != 0) {
      return []
    }
    
    # Parse the output - expect "GPU X Usage: Y.ZZ%"
    let lines = ($out.stdout | lines)
    let gpu_lines = ($lines | where {|l| $l =~ "GPU.*Usage"})
    
    $gpu_lines | each {|line|
      # Example: "GPU 0 Usage: 0.14%"
      let parts = ($line | split row ":")
      if (($parts | length) >= 2) {
        let usage_str = ($parts.1 | str trim | str replace "%" "")
        let usage = (try { $usage_str | into float } catch { 0.0 })
        {
          vendor: "windows-perfmon",
          usage_pct: $usage,
          mem_used_mib: null,
          mem_total_mib: null,
          mem_used_pct: null
        }
      } else {
        null
      }
    } | where {|x| $x != null}
  } catch {
    []
  }
}

# Collect GPU data using PowerShell Get-Counter (Windows fallback)
def collect-powershell [] {
  try {
    let out = (run-external "powershell" "-Command" "Get-Counter -Counter '\\GPU Engine(*)\\Utilization Percentage' -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop | ForEach-Object { $_.CounterSamples | Select-Object @{Name='usage_pct'; Expression={[math]::Round($_.CookedValue, 2)}}, @{Name='vendor'; Expression={'windows-perfmon'}}, @{Name='mem_used_mib'; Expression={$null}}, @{Name='mem_total_mib'; Expression={$null}}, @{Name='mem_used_pct'; Expression={$null}} } | ConvertTo-Json -Compress" | complete)
    
    if ($out.exit_code != 0 or ($out.stdout | str trim) == "") {
      return []
    }
    
    let parsed = (try { $out.stdout | from json } catch { null })
    if ($parsed == null) {
      return []
    }
    
    # Ensure it's an array
    let rows = (if ($parsed | describe | str contains "record") { [$parsed] } else { $parsed })
    
    # Group by physical GPU and average utilization
    let grouped = ($rows | group-by {|r| 
      # Extract phys_X from path
      let path = ($r | get -o "Path" | default "")
      if ($path =~ "phys_(\\d+)") {
        $path | str replace -r ".*phys_(\\d+).*" "$1"
      } else {
        "unknown"
      }
    })
    
    $grouped | items {|phys_id, engines|
      let avg_usage = ($engines | get usage_pct | math avg)
      {
        vendor: "windows-perfmon",
        usage_pct: $avg_usage,
        mem_used_mib: null,
        mem_total_mib: null,
        mem_used_pct: null
      }
    } | where {|gpu| $gpu.usage_pct > 0.0}
  } catch {
    []
  }
}