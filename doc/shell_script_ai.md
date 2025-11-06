# Shell script × 自作 AI × Nushell 組み合わせ設計

この文書は、Nushell で収集したシステムメトリクスを統計的に前処理し、それを自作 AI に渡して最適化提案を得て、安全に適用するための設計・実装ガイドです。実装済みのスクリプトを前提にします。

- 収集: `scripts/monitor.nu`（常駐、NDJSON と `last.json` を更新）
- 簡易チューニング例: `scripts/tune_example.nu`
- 自動起動: `scripts/install-*.{ps1,sh}`

## 全体アーキテクチャ

1. 収集器（Collector）: Nushell の `sys cpu/mem/disks` とベンダーツールで GPU を収集し、NDJSON ストリームに追記、`last.json` を更新。
2. 評価器（Evaluator）: NDJSON から必要期間のデータを読み、移動平均・分位・変化率などの特徴量を生成。
3. AI アダプタ（Adapter）: 特徴量と文脈（アプリ名、バージョンなど）を JSON で自作 AI（CLI/HTTP）に渡し、推奨設定を受け取る。
4. 適用器（Applier）: 推奨値を環境変数や引数としてアプリ起動時に適用。AI が不在/失敗なら閾値ベースのフォールバックを使う。

ポイント: Nu は「前処理とオーケストレーション」、AI は「非線形で曖昧な最適化提案」、安全化は「Nu 側のガードレール（最小/最大/閾値・ヒステリシス）」で行う。

## データ収集（実装済み）

`scripts/monitor.nu` は以下を収集します。

- CPU: `sys cpu -l` による per-core 使用率、平均を `usage_pct`
- Mem: `sys mem` から `used_pct`
- Disk: `sys disks` から各マウントの `used_pct`
- GPU: 直接 API に触るため、スクリプトファイルを除外。Linux では `nvtop` を `timeout` で実行し出力パース、Windows では `run-external` で PowerShell の `Get-Counter` を呼び出し DXGI-P から使用率を取得（メモリ情報なし）。ベンダー固有ツール（nvidia-smi, rocm-smi）は除外し、汎用ツールのみ使用。
- 機械的判定 `level`: CPU/MEM で 50%/80% を閾値に `low/mid/high`

出力ファイル

- `${nu.data-dir}/nanai_consys/metrics.ndjson`（NDJSON）
- 同ディレクトリに `last.json`（最新スナップショット）

### GPU 取得の設計理由

GPU 使用率取得では、直接 API に触ることを優先し、スクリプトファイルの依存を避ける。

- **Linux**: `nvtop` を `run-external "sh" "-c" "timeout 1 nvtop ..."` で実行し、出力から Utilization をパース。インタラクティブツールのため timeout で制御。
- **Windows**: `run-external "powershell" "-Command" "Get-Counter ..."` で DXGI-P (DirectX Graphics Infrastructure Performance) のカウンターを取得。JSON に変換してパース。
- **除外したもの**: nvidia-smi, rocm-smi などのベンダー固有ツールは、nvtop/DXGI-P でカバー可能であり、依存を減らすため除外。スクリプトファイル（.ps1 など）は、Nushell 内で直接コマンドを実行することで不要化。

## Nushell による統計前処理の例

直近 60 サンプルから平均・p95・変化率を計算する例:

```nu
let dir = ($nu.data-dir | path join "nanai_consys")
let log = ($dir | path join "metrics.ndjson")
let frames = (open $log | from ndjson | last 60)

let nonnull = {|xs| $xs | where {|x| $x != null } }
let cpu_series = ($frames | get cpu.usage_pct | do $nonnull)
let mem_series = ($frames | get mem.used_pct | do $nonnull)

let cpu_avg = ($cpu_series | math avg)
let mem_avg = ($mem_series | math avg)

let p95 = {|xs|
	let xs2 = ($xs | sort)
	if ($xs2 | is-empty) { null } else {
		let n = ($xs2 | length)
		$xs2 | get ( ($n * 95 / 100) | into int | math clamp 0 .. ($n - 1) )
	}
}
let cpu_p95 = (do $p95 $cpu_series)
let mem_p95 = (do $p95 $mem_series)

# 単純な変化率（最後-最初）/max(最初,1)
let rate = {|xs|
	if (($xs | length) < 2) { null } else {
		let fst = ($xs | first)
		let lst = ($xs | last)
		if ($fst == 0) { null } else { (($lst - $fst) / $fst * 100) }
	}
}
let cpu_rate = (do $rate $cpu_series)
let mem_rate = (do $rate $mem_series)

let features = {
	cpu_avg: $cpu_avg, cpu_p95: $cpu_p95, cpu_rate_pct: $cpu_rate,
	mem_avg: $mem_avg, mem_p95: $mem_p95, mem_rate_pct: $mem_rate
}
```

## AI インターフェイス設計（推奨）

入力 JSON（例）

```jsonc
{
  "context": { "app": "my_app", "version": "1.2.3", "os": "windows" },
  "snapshot": {
    /* last.json 全体 */
  },
  "stats": {
    "cpu_avg": 43.2,
    "cpu_p95": 88.7,
    "cpu_rate_pct": 5.0,
    "mem_avg": 51.0,
    "mem_p95": 79.4,
    "mem_rate_pct": -3.2
  }
}
```

出力 JSON（例）

```jsonc
{
  "parallelism": 8,
  "batch_size": 128,
  "mode": "balanced",
  "notes": "cpu_p95 high, cap threads"
}
```

プロトコル

- CLI: 標準入力で JSON を渡し、標準出力で JSON を受け取る。
- HTTP: `POST /suggest` で JSON、200 で JSON を返す。非 200 はエラー扱い。

## Nu からの AI 呼び出し例

CLI 実行例

```nu
let dir = ($nu.data-dir | path join "nanai_consys")
let payload = {
	context: { app: "my_app", version: "1.2.3", os: (sys host | get name) },
	snapshot: (open ($dir | path join "last.json") | from json),
	stats: $features
}
let ai = ($payload | to json -r | ^my_ai.exe --mode suggest | from json)
```

HTTP 実行例（curl）

```nu
let ai = (
	$payload | to json -r
	| ^curl -sS -X POST http://127.0.0.1:8080/suggest -H "Content-Type: application/json" --data-binary @-
	| from json
)
```

## 安全適用（フォールバック込み）

1. 閾値ベースのフォールバック（`level`）を先に決める。
2. AI 結果が妥当なら上書き。範囲チェック、最小/最大、ヒステリシスを適用。

```nu
let snap = (open ($dir | path join "last.json") | from json)
let level = ($snap.level | default "low")
let cores = (try { sys cpu -l | length } catch { 1 })

let fb = (match $level {
	"high" => { parallelism: $cores, mode: "conservative" },
	"mid"  => { parallelism: (( $cores + 1 ) / 2), mode: "balanced" },
	_      => { parallelism: $cores, mode: "aggressive" }
})

let rec = (try { $ai } catch { $fb })
let para = ([$rec.parallelism 1] | math max | into int)
let para = ([$para $cores] | math min)  # 上限は実コア数

with-env { APP_PARALLELISM: ($para | into string), APP_MODE: ($rec.mode | default "balanced") } {
	^my_app.exe
}
```

## 運用ガイド

- 常駐収集は各 OS のインストーラでセットアップ済み。
- 前処理+AI+適用は「起動前の 1 ショット」で実行するのが安全（フラッピング防止）。
- チューニングの頻度は秒〜分に抑え、移動平均やヒステリシスで安定化。
- すべての入力と出力を NDJSON で監査ログ化（再現性の担保）。

## 今後の拡張

- AI アダプタの共通ラッパー `scripts/ai_adapter.nu` を用意し、CLI/HTTP/フォールバック/ログを一体化。
- 推奨値の AB テストフレームを追加（期間限定で A/B 設定を切り替え、効果測定）。
- アプリ別の適用プロファイル（並列度、バッチ、メモリ上限、I/O 戦略）をテンプレ化。
