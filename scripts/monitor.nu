# Nushell system metrics monitor (cross-platform)
# Collects CPU, memory, disk, and optional GPU metrics and writes NDJSON snapshots.
#ATDS

export def main [
  --once        # run once and print JSON to stdout (and optionally save)
  --interval:int = 5  # seconds between samples when running as a daemon
  --log-path:path     # optional: where to write NDJSON (default: $nu.data-dir/nanai_consys/metrics.ndjson)
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
    return
  }

  loop {
    let snap = (collect-snapshot)
  $snap | to json -r | save --append $log_path
  # also refresh last.json for consumers
  let last_path = ($log_path | path dirname | path join "last.json")
  $snap | to json -r | save -f $last_path
  sleep ($interval | into duration --unit sec)
  }
}

# Build one snapshot record
def collect-snapshot [] {
  let ts = (date now | format date "%+" )
  let cpu = (get-cpu)
  let mem = (get-mem)
  let disks = (get-disks)
  let gpu = (get-gpu)
  let level = (assess-load $cpu $mem)
  {
    timestamp: $ts,
    level: $level,
    cpu: $cpu,
    mem: $mem,
    disks: $disks,
    gpu: $gpu
  }
}

# Heuristic load level for quick, mechanical judgment
# - high: any of cpu/mem >= 80%
# - mid:  any of cpu/mem >= 50%
# - low:  otherwise
def assess-load [cpu_rec mem_rec] {
  let cpu_pct = ($cpu_rec.usage_pct? | default 0 | into float)
  let mem_pct = ($mem_rec.used_pct? | default 0 | into float)
  if ($cpu_pct >= 80 or $mem_pct >= 80) { "high" }
  else if ($cpu_pct >= 50 or $mem_pct >= 50) { "mid" }
  else { "low" }
}

# CPU usage: average across logical CPUs using sys cpu -l
def get-cpu [] {
  let t = (sys cpu -l)
  if (($t | length) == 0) {
    # fallback: try aggregated record if available
    let u = (try { (sys | get cpu | get usage) } catch { null })
    { usage_pct: ($u | default null), per_core: null }
  } else {
    let per = (try { $t | select name usage } catch { $t })
    let usages = (try { $per | get usage } catch { [] })
    let avg = (if (($usages | length) > 0) { $usages | math avg } else { null })
    { usage_pct: $avg, per_core: $per }
  }
}

# Memory usage percentage
def get-mem [] {
  let m = (sys mem)
  let total = (try { $m.total } catch { null })
  let used = (try { $m.used } catch { null })
  let used2 = (if ($used | describe | str contains "nothing") { try { $m.total - $m.free } catch { null } } else { $used })
  let pct = (if ($total != null and $used2 != null and $total != 0) { ($used2 / $total * 100) } else { null })
  { total: $total, used: $used2, used_pct: $pct }
}

# Disk usage per mount/drive
def get-disks [] {
  let d = (sys disks)
  $d | each {|it|
    let total = (try { $it.total } catch { null })
    let used = (try { $it.used } catch { null })
    let used2 = (if ($used | describe | str contains "nothing") { try { $it.total - $it.free } catch { null } } else { $used })
    let pct = (if ($total != null and $used2 != null and $total != 0) { ($used2 / $total * 100) } else { null })
    {
      name: (try { $it.name } catch { null }),
      mount: (try { $it.mount } catch { null }),
      file_system: (try { $it.file_system } catch { null }),
      total: $total,
      used: $used2,
      used_pct: $pct
    }
  }
}

# GPU usage via vendor tools if available. Returns null if not found.
def get-gpu [] {
  # Linux: try nvtop (generic GPU monitor)
  if ($nu.os-info.name == "linux" and (which nvtop | length) > 0) {
    let out = (try { run-external "sh" "-c" "timeout 1 nvtop 2>/dev/null | head -20" | complete } catch { null })
    if ($out != null and $out.exit_code == 0) {
      let lines = ($out.stdout | lines)
      let gpu_lines = ($lines | where {|l| $l =~ "Utilization"})
      let rows = ($gpu_lines | each {|l|
        # Example: GPU 0: NVIDIA GeForce RTX 3080 [Utilization: 45%]
        let parts = ($l | split row ":")
        if (($parts | length) >= 3) {
          let util_str = ($parts.2 | str trim | str replace "%" "" | str replace "[" "" | str replace "]" "")
          let util = (try { $util_str | into int } catch { null })
          { vendor: "nvtop", usage_pct: $util, mem_used_mib: null, mem_total_mib: null, mem_used_pct: null }
        } else { null }
      } | where {|x| $x != null })
      if (($rows | length) > 0) { return $rows }
    }
  }

  # Windows: try DXGI-P via PowerShell command
  if ($nu.os-info.name == "windows") {
    let out = (try { run-external "powershell" "-Command" "Get-Counter -Counter '\\GPU Engine(*)\\Utilization Percentage' -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop | ForEach-Object { $_.CounterSamples | Select-Object @{Name='usage_pct'; Expression={[math]::Round($_.CookedValue, 2)}}, @{Name='vendor'; Expression={'dxgi'}}, @{Name='mem_used_mib'; Expression={$null}}, @{Name='mem_total_mib'; Expression={$null}}, @{Name='mem_used_pct'; Expression={$null}} } | ConvertTo-Json -Compress" | complete } catch { null })
    if ($out != null and $out.exit_code == 0 and ($out.stdout | str trim) != "") {
      let parsed = (try { $out.stdout | from json } catch { null })
      if ($parsed != null) {
        # Ensure it's an array
        let rows = (if ($parsed | describe | str contains "record") { [$parsed] } else { $parsed })
        return $rows
      }
    }
  }

  # macOS or others without vendor tools: return null
  null
}

# Convenience: run once and save to default path
export def snapshot [] {
  main --once
}
