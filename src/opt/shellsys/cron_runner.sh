#!/usr/bin/env bash
set -Eeuo pipefail
LOG_DIR="/var/log/shellsys"; mkdir -p "$LOG_DIR"
echo "[Cron executed at $(date '+%F %T')]" >> "$LOG_DIR/cron_wrapper.log"
/opt/shellsys/main.sh --cron-run >/dev/null 2>&1 || true
