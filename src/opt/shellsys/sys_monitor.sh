#!/usr/bin/env bash
# ===============================================
# Module: user_mgr.sh
# Usage: ./user_mgr.sh [--config=config.ini] [--verbose]
# Description: 用户管理模块，负责创建与验证系统用户
# ===============================================

set -Eeuo pipefail
trap 'echo "[FATAL] sys_monitor.sh failed at line $LINENO" >&2; exit 4' ERR
CONF="/opt/shellsys/config.ini"
[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] config.ini missing: $CONF"; exit 1; }
MODULE="sys_monitor"; TODAY="$(date +%F)"
LOG_FILE="${LOG_DIR:-/var/log/shellsys}/${MODULE}_${TODAY}.log"
mkdir -p "${LOG_DIR:-/var/log/shellsys}"
log_event(){ printf '%s [%s] %s\n' "$(date '+%F %T')" "$MODULE" "$EXEC_ID" "$*" | tee -a "$LOG_FILE"; }
cpu_usage(){ top -bn1 | awk -F'[, ]+' '/Cpu/ {print 100-$8}' | awk '{printf("%.1f",$1)}'; }
mem_usage(){ free -m | awk '/Mem/ {printf("%.1f", $3/$2*100)}'; }
disk_usage(){ df -P / | awk 'NR==2{gsub("%","",$5);print $5}'; }
cpu="$(cpu_usage)"; mem="$(mem_usage)"; disk="$(disk_usage)"
log_event "CPU:${cpu}% MEM:${mem}% DISK:${disk}%"
[[ ${cpu%.*}  -gt ${THRESHOLD_CPU:-85}  ]] && log_event "Warning: CPU>${THRESHOLD_CPU:-85}%"
[[ ${mem%.*}  -gt ${THRESHOLD_MEM:-80}  ]] && log_event "Warning: MEM>${THRESHOLD_MEM:-80}%"
[[ ${disk%.*} -gt ${THRESHOLD_DISK:-90} ]] && log_event "Warning: DISK>${THRESHOLD_DISK:-90}%"
exit 0
