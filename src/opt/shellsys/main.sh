#!/usr/bin/env bash
# ===============================================
# Main controller: main.sh
# ===============================================
set -Eeuo pipefail
trap 'echo "[FATAL] main.sh failed at line $LINENO" >&2; exit 4' ERR

# ---- config ----
CONF="/opt/shellsys/config.ini"
[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] config.ini missing: $CONF"; exit 1; }

# ---- log & exec id ----
LOG_DIR="${LOG_DIR:-/var/log/shellsys}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/main_$(date +%F).log"

# single instance lock
exec 9>/var/lock/shellsys.lock
flock -n 9 || { echo "$(date '+%F %T') [main] Another run is active. Exit." >> "$LOG_FILE"; exit 0; }

EXEC_ID="${EXEC_ID:-$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)}"
export EXEC_ID

log(){ printf '%s [main] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"; }

run_user(){ /opt/shellsys/user_mgr.sh --config="$CONF" 2>&1 | tee -a "$LOG_FILE"; }
run_monitor(){ /opt/shellsys/sys_monitor.sh --config="$CONF" 2>&1 | tee -a "$LOG_FILE"; }
run_log(){ /opt/shellsys/log_manage.sh --config="$CONF" 2>&1 | tee -a "$LOG_FILE"; }
run_backup(){ /opt/shellsys/backup_restore.sh --config="$CONF" --backup 2>&1 | tee -a "$LOG_FILE"; }

case "${1:-}" in
  --auto)
    log "Execution ID: $EXEC_ID"
    log "Auto run start"
    run_user
    run_monitor
    run_log
    run_backup
    log "Auto run done"
    ;;
  --task)
    shift
    case "${1:-}" in
      user) run_user ;;
      monitor) run_monitor ;;
      log) run_log ;;
      backup) run_backup ;;
      *) echo "Usage: $0 --task {user|monitor|log|backup}"; exit 2;;
    esac ;;
  --test)
    log "Test run"
    run_user; run_monitor; run_log; run_backup
    log "Test done"
    ;;
  *)
    echo "Usage: $0 --auto | --task {user|monitor|log|backup} | --test"
    exit 1
    ;;
esac
