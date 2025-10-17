#!/usr/bin/env bash
# ===============================================
# Module: user_mgr.sh
# Usage: ./user_mgr.sh [--config=config.ini] [--verbose]
# Description: 用户管理模块，负责创建与验证系统用户
# ===============================================

set -Eeuo pipefail
trap 'echo "[FATAL] log_manage.sh failed at line $LINENO" >&2; exit 4' ERR
CONF="/opt/shellsys/config.ini"
[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] config.ini missing: $CONF"; exit 1; }
MODULE="log_manage"; TODAY="$(date +%F)"
LOG_FILE="${LOG_DIR:-/var/log/shellsys}/${MODULE}_${TODAY}.log"
mkdir -p "${LOG_DIR:-/var/log/shellsys}"
log_event(){ printf '%s [%s] %s\n' "$(date '+%F %T')" "$MODULE" "$EXEC_ID" "$*" | tee -a "$LOG_FILE"; }
out="${LOG_DIR}/log_stat_${TODAY}.log"; : > "$out"
for f in /var/log/messages /var/log/syslog; do [[ -f "$f" ]] || continue; grep -Ei "error|fail|panic|critical" "$f" | awk '{print $1,$2,$3,$5}' >> "$out" || true; done
sort "$out" | uniq -c | sort -nr > "${out}.tmp" && mv "${out}.tmp" "$out"
tar -czf "${LOG_DIR}/log_archive_${TODAY}.tgz" /var/log/*.log /var/log/*log* 2>/dev/null || true
log_event "Log scan completed: $(wc -l < "$out" || echo 0) lines. Archive: log_archive_${TODAY}.tgz"
exit 0
