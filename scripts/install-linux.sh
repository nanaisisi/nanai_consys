#!/usr/bin/env bash
set -euo pipefail

# Install a user systemd service to run monitor.nu on login
NU=${NU:-$(command -v nu)}
INTERVAL=${INTERVAL:-5}
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd -P)
SCRIPT_PATH="$REPO_ROOT/scripts/monitor.nu"
SERVICE_NAME=nanai_consys_monitor

mkdir -p "$HOME/.local/share/nushell/nanai_consys"
LOG_PATH="$HOME/.local/share/nushell/nanai_consys/metrics.ndjson"

UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"
UNIT_FILE="$UNIT_DIR/${SERVICE_NAME}.service"

cat >"$UNIT_FILE" <<UNIT
[Unit]
Description=NanAI ConSys metrics monitor
After=default.target

[Service]
Type=simple
ExecStart=%h/.local/bin/nu --commands "use $SCRIPT_PATH; main --interval $INTERVAL --log-path '$LOG_PATH'"
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
UNIT

# Prefer provided NU path if set
if [[ -n "${NU:-}" ]]; then
  sed -i "s|%h/.local/bin/nu|$NU|" "$UNIT_FILE"
fi

systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE_NAME"

echo "Installed user service $SERVICE_NAME (interval=${INTERVAL}s). Logs: $LOG_PATH"
