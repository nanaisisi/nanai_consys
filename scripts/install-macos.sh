#!/usr/bin/env bash
set -euo pipefail

# Install a launchd plist to run monitor.nu at login
NU=${NU:-$(command -v nu)}
INTERVAL=${INTERVAL:-5}
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd -P)
SCRIPT_PATH="$REPO_ROOT/scripts/monitor.nu"
LABEL=com.nanai.consys.monitor
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
LOG_DIR="$HOME/Library/Application Support/nushell/nanai_consys"
mkdir -p "$LOG_DIR"
LOG_PATH="$LOG_DIR/metrics.ndjson"

mkdir -p "$PLIST_DIR"
cat >"$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$NU</string>
    <string>--commands</string>
    <string>use $SCRIPT_PATH; main --interval $INTERVAL --log-path '$LOG_PATH'</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
PLIST

launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl load "$PLIST_PATH"

echo "Installed launch agent $LABEL (interval=${INTERVAL}s). Logs: $LOG_PATH"
