<<<<<<< HEAD
# コーディングルール（AI 支援前提・軽量版）

本リポジトリでは、人と AI の共同開発を前提に、具体的な細目は AI が状況に応じて提案・補完できるよう、原則・分割方針・インターフェイス規約を軽量に定義します。

## 1. 原則（Definition）

- 小さく作り、早く動かし、計測する（Small, Working, Measured）。
- 可読性>賢さ：読みやすい命名・直線的なロジックを優先。
- ローカル最適でも良い：無用な汎用化は避ける。必要時に抽象化。
- 収集 → 判断 → 適用の分離（observer/decider/applier）。
- 監査可能性：重要な入出力は NDJSON で記録。

## 2. 分割化（Modularization）

- 層分割
  - collect: 実測の取得（例：Nushell `sys`、ベンダー CLI）。
  - eval: 前処理・統計・特徴量化。
  - decide: 閾値または AI での意思決定（フォールバック必須）。
  - apply: 設定適用（環境変数/引数/設定ファイル）。
- 単一責務：モジュール/スクリプトは 1 つの責務に集中。
- ファイル構成（例）
  - `scripts/monitor.nu`（collect+軽い decide）
  - `scripts/tune_example.nu`（decide/eval）
  - `scripts/ai_adapter.nu`（decide: AI 呼び出し、将来追加）
  - `doc/*.md`（仕様と運用）

## 3. インターフェイス（Interface）

- データ交換
  - JSON/NDJSON を基本形式とする。
  - スキーマは「緩い前方互換」を原則（未知キーは無視、必要キーは既定値）。
- コマンド I/F
  - CLI は「標準入力 JSON→ 標準出力 JSON」を推奨。
  - 失敗時は非 0 終了/非 200（HTTP）。Nu 側で try-catch しフォールバック。
- 閾値フォールバック
  - level: low/mid/high（50%/80%目安）で最小限の動作を保証。
  - AI エラー時は必ずフォールバックを適用。

## 4. スタイル（Style）

- 命名：役割が分かる短く一貫した英語（e.g., collect, eval, decide, apply）。
- 関数：入力/出力の「契約」を冒頭コメントで 2〜4 行に要約。
- 例外：外部実行は`try`でガードし、null/既定値で継続。
- ログ：意思決定の入力と出力を 1 行 JSON で残す。

## 5. テスト/検証（Quality）

- Quality gates：
  - Lint/構文: スクリプトの構文エラーは即修正。
  - スモーク: 代表的 1〜2 ケースで実行確認。
  - 回帰: 入力 → 出力の固定ペアを NDJSON で残し比較可能に。

## 6. AI に委譲する細目（任意）

- しきい値の微調整、特徴量の追加、探索パラメータ（学習率/バッチ/並列度の上限など）。
- 例外時のリトライ戦略・ヒステリシス幅。
- アプリ別プロファイル（テンプレート）の提案と適用。

## 7. 変更手順（Workflow）

1. 仕様差分を`doc/`に 1 パラグラフで追記。
2. 最小の追加/変更を実装（既存 I/F を壊さない）。
3. スモークテストとログ確認。
4. 大きな変更は AI にドラフト生成 → 人がレビュー。

---

注：このドキュメントは「原則と I/F」を固定し、細目は AI が状況最適に提案・更新する運用を想定しています。
=======
# Nanai Consys Coding Rules and Standards

## Overview
This document defines the coding standards, architectural principles, and best practices for the Nanai Consys project. The goal is to create maintainable, modular, and scalable code that integrates system monitoring with AI optimization.

## Architecture Principles

### 3-Layer Architecture
The system follows a strict 3-layer architecture pattern:

1. **Collection Layer** - Responsible for gathering system metrics
2. **Evaluation Layer** - Processes metrics and integrates with AI for analysis
3. **Application Layer** - Applies optimization suggestions and manages user interactions

### Separation of Concerns
- Each module should have a single, well-defined responsibility
- Dependencies should flow in one direction (no circular dependencies)
- Interfaces should be explicit and documented

## Nushell Coding Standards

### Module Structure
```nu
# Module header with description and purpose
# Author, version, and dependencies information

# Public interface definitions (export def)
export def main [...] { }

# Public utility functions
export def function-name [...] { }

# Private implementation functions
def private-function [...] { }
```

### Naming Conventions
- **Modules**: Use kebab-case for file names (e.g., `metrics-collector.nu`)
- **Functions**: Use kebab-case for function names (e.g., `collect-cpu-metrics`)
- **Variables**: Use snake_case for variables (e.g., `cpu_usage_pct`)
- **Constants**: Use UPPER_SNAKE_CASE (e.g., `DEFAULT_INTERVAL`)

### Function Design
- Functions should be pure when possible (no side effects)
- Use explicit parameter types and documentation
- Return structured data with consistent schemas
- Handle errors gracefully with try/catch blocks

### Error Handling
```nu
# Use try/catch for error handling
let result = (try { 
    potentially-failing-operation 
} catch { 
    null  # or appropriate fallback
})

# Validate inputs at function boundaries
if ($param | is-empty) {
    error make {msg: "Parameter 'param' is required"}
}
```

### Documentation Standards
- All exported functions must have header comments
- Include parameter descriptions and return value documentation
- Provide usage examples for complex functions

```nu
# Collect CPU usage metrics across all cores
# Returns: record with usage_pct (float) and per_core (list)
# Example: let cpu_data = (get-cpu-metrics)
export def get-cpu-metrics [] {
    # implementation
}
```

## Interface Definitions

### Metrics Data Schema
All metrics must follow consistent schemas:

```nu
# CPU Metrics Schema
{
    usage_pct: float,      # Overall CPU usage percentage
    per_core: list<record> # Per-core usage details
}

# Memory Metrics Schema  
{
    total: int,      # Total memory in bytes
    used: int,       # Used memory in bytes
    used_pct: float  # Usage percentage
}

# System Snapshot Schema
{
    timestamp: string,     # ISO 8601 format
    level: string,         # "low", "mid", "high"
    cpu: record,           # CPU metrics
    mem: record,           # Memory metrics  
    disks: list<record>,   # Disk metrics
    gpu: list<record>      # GPU metrics (nullable)
}
```

### AI Integration Interface
```nu
# AI Evaluation Request Schema
{
    metrics: record,           # Current system snapshot
    history: list<record>,     # Historical data points
    context: record           # Additional context (user preferences, etc.)
}

# AI Recommendation Response Schema
{
    confidence: float,         # 0.0 to 1.0
    category: string,          # "performance", "resource", "thermal", etc.
    actions: list<record>,     # Recommended actions
    reasoning: string          # Explanation of recommendations
}
```
>>>>>>> bde486c9ab98bac79ef179cb5feb6a2af5dc7c95
