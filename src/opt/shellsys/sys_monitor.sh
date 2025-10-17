#!/usr/bin/env bash
# sys_monitor.sh — 采集CPU/MEM/DISK
set -Eeuo pipefail
trap 'echo "[FATAL] sys_monitor.sh failed at line $LINENO" >&2; exit 4' ERR

CONF="/opt/shellsys/config.ini"
[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] config.ini missing: $CONF"; exit 1; }

MODULE="sys_monitor"; TODAY="$(date +%F)"
LOG_DIR="${LOG_DIR:-/var/log/shellsys}"; mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${MODULE}_${TODAY}.log"
log(){ printf '%s [%s] %s %s\n' "$(date '+%F %T')" "$MODULE" "${EXEC_ID:-NA}" "$*" | tee -a "$LOG_FILE"; }

CPU=$(awk -v p="${THRESHOLD_CPU:-85}" '/cpu /{u=$2+$4; t=$2+$4+$5} END{printf "%.1f", (u/t)*100}' /proc/stat 2>/dev/null || echo 0)
MEM=$(free -m | awk '/Mem:/{printf "%.1f", ($3/$2)*100}')
DISK=$(df -P / | awk 'END{gsub("%","",$5); print $5}')

log "CPU:${CPU}% MEM:${MEM}% DISK:${DISK}%"
