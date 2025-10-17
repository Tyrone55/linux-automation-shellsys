#!/usr/bin/env bash
# log_manage.sh — 简单日志归档
set -Eeuo pipefail
trap 'echo "[FATAL] log_manage.sh failed at line $LINENO" >&2; exit 4' ERR

CONF="/opt/shellsys/config.ini"
[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] config.ini missing: $CONF"; exit 1; }

MODULE="log_manage"; TODAY="$(date +%F)"
LOG_DIR="${LOG_DIR:-/var/log/shellsys}"; mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${MODULE}_${TODAY}.log"
log(){ printf '%s [%s] %s %s\n' "$(date '+%F %T')" "$MODULE" "${EXEC_ID:-NA}" "$*" | tee -a "$LOG_FILE"; }

# 归档昨日模块日志
YESTERDAY="$(date -d 'yesterday' +%F 2>/dev/null || date +%F)"
ARCHIVE="log_archive_$(date +%F).tgz"
tar -czf "$LOG_DIR/$ARCHIVE" -C "$LOG_DIR" $(ls "$LOG_DIR" | grep -E "^(user_mgr|sys_monitor|backup_restore)_${YESTERDAY}\.log$" || true) 2>/dev/null || true
LINES=$(wc -l "$LOG_FILE" 2>/dev/null | awk '{print $1+0}')
log "Log scan completed: ${LINES} lines. Archive: ${ARCHIVE}"
