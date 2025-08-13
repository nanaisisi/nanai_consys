# Nushell メトリクス収集と常駐

本リポジトリには、Nushell で CPU/GPU/メモリ/ディスク使用率を収集する `scripts/monitor.nu` が含まれます。

- CPU: `sys cpu -l` の各コア使用率の平均を `usage_pct` に格納
- MEM: `sys mem` から使用率 `used_pct` を計算
- DISK: `sys disks` から各マウントの `used_pct` を計算
- GPU: `nvidia-smi` または `rocm-smi` があれば利用、無ければ `null`

簡易な負荷判定 `level`:

- high: CPU/MEM どちらかが 80%以上
- mid: CPU/MEM どちらかが 50%以上
- low: それ以外

## 使い方

- 1 回だけ取得: `nu --commands "use scripts/monitor.nu; snapshot"`
- 常駐(前景): `nu --commands "use scripts/monitor.nu; main --interval 5"`

## 自動起動インストール

- Windows: `scripts/install-windows.ps1`
- Linux: `bash scripts/install-linux.sh`
- macOS: `bash scripts/install-macos.sh`

既定保存先: `${nu.data-dir}/nanai_consys/metrics.ndjson` と `last.json`
