# Simple heuristic-based tuning advisor using metrics collected by monitor.nu

export def main [
  --metrics:path  # optional path to last.json; defaults to $nu.data-dir/nanai_consys/last.json
  --max-threads:int = 16  # an upper bound for thread suggestions
] {
  let path = (if ($metrics | is-empty) { ($nu.data-dir | path join "nanai_consys" | path join "last.json") } else { $metrics })
  if (not ($path | path exists)) {
    error make {msg: $"metrics file not found: ($path)"}
  }
  let snap = (open $path | from json)
  let level = ($snap.level | default "low")

  let cores = (try { sys cpu -l | length } catch { 1 })

  let half = ( ( ($cores + 1) / 2 ) )
  let recommend = (match $level {
    "high" => { parallelism: (min [$max_threads  $cores ]), mode: "conservative", notes: "system busy: cap threads, prefer I/O-bound batching" },
    "mid"  => { parallelism: (min [$max_threads  $half ]), mode: "balanced", notes: "moderate load: use ~half cores" },
    _      => { parallelism: (min [$max_threads  $cores ]), mode: "aggressive", notes: "low load: you can use most cores" }
  })

  {
    level: $level,
    cpu_pct: ($snap.cpu.usage_pct? | default null),
    mem_pct: ($snap.mem.used_pct? | default null),
    recommend: $recommend
  } | to json -r | print
}
