#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] main.sh failed at line $LINENO" >&2; exit 4' ERR
CONF="/opt/shellsys/config.ini"
[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] config.ini missing: $CONF"; exit 1; }
LOG_FILE="${LOG_DIR:-/var/log/shellsys}/main_$(date +%F).log"
mkdir -p "${LOG_DIR:-/var/log/shellsys}"
log_event(){ printf '%s [main] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"; }
run_user(){ /opt/shellsys/user_mgr.sh --config="$CONF"; }
run_monitor(){ /opt/shellsys/sys_monitor.sh --config="$CONF"; }
run_log(){ /opt/shellsys/log_manage.sh --config="$CONF"; }
run_backup(){ /opt/shellsys/backup_restore.sh --config="$CONF" --backup; }
case "${1:-}" in
  --auto) log_event "Auto run start"; run_user; run_monitor; run_log; run_backup; log_event "Auto run done";;
  --task) shift; case "$1" in user)run_user;; monitor)run_monitor;; log)run_log;; backup)run_backup;; *) exit 1;; esac ;;
  --test) log_event "Test run"; run_user; run_monitor; run_log; run_backup; log_event "Test done";;
  *) echo "Usage: $0 --auto | --task {user|monitor|log|backup} | --test"; exit 1;;
esac
