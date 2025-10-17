#!/usr/bin/env bash
# ===============================================
# Module: user_mgr.sh
# Usage: ./user_mgr.sh [--config=config.ini] [--verbose]
# Description: 用户管理模块，负责创建与验证系统用户
# ===============================================

set -Eeuo pipefail
trap 'echo "[FATAL] backup_restore.sh failed at line $LINENO" >&2; exit 4' ERR

# 默认配置路径，可被 --config 覆盖
CONF="/opt/shellsys/config.ini"
ACTION="--backup"
RESTORE_DATE=""

# 解析无序参数：先吃掉 --config，再识别 --backup / --restore
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config=*)
      CONF="${1#*=}"; shift ;;
    --config)
      [[ $# -ge 2 ]] || { echo "[ERR] --config needs a value"; exit 1; }
      CONF="$2"; shift 2 ;;
    --backup|--restore)
      ACTION="$1"; shift
      if [[ "$ACTION" == "--restore" ]]; then
        RESTORE_DATE="${1:-}"
        [[ -n "$RESTORE_DATE" ]] || { echo "Usage: $0 [--backup] | [--restore YYYY-MM-DD]"; exit 1; }
        shift || true
      fi
      ;;
    *)
      # 忽略未知参数，避免因调用方额外参数导致失败
      shift ;;
  esac
done

[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] config.ini missing: $CONF"; exit 1; }

MODULE="backup_restore"; TODAY="$(date +%F)"
LOGDIR="${LOG_DIR:-/var/log/shellsys}"; mkdir -p "$LOGDIR" "${BACKUP_DIR:-/opt/backup}"
LOG_FILE="${LOGDIR}/${MODULE}_${TODAY}.log"
log(){ printf '%s [%s] %s\n' "$(date '+%F %T')" "$MODULE" "$EXEC_ID" "$*" | tee -a "$LOG_FILE"; }

[[ "$(id -u)" -eq 0 ]] || { echo "Permission denied. Run as root."; exit 2; }

backup_files() {
  local dest="${BACKUP_DIR}/${TODAY}"; mkdir -p "$dest"
  tar -czf "${dest}/fs.tar.gz" /etc /home /opt 2>/dev/null || true
  log "File backup finished: ${dest}/fs.tar.gz"
}
backup_db() {
  if [[ "${DB_BACKUP:-off}" == "on" ]]; then
    local dest="${BACKUP_DIR}/${TODAY}"; mkdir -p "$dest"
    mysqldump -uroot -p"${DB_PASS:-}" --all-databases > "${dest}/db.sql"
    log "Database backup finished: ${dest}/db.sql"
  else
    log "DB backup disabled"
  fi
}
restore_all() {
  local src="${BACKUP_DIR}/${1}"
  [[ -d "$src" ]] || { log "Backup set not found: $src"; exit 1; }
  [[ -f "${src}/fs.tar.gz" ]] && tar -xzf "${src}/fs.tar.gz" -C / && log "FS restored from ${src}/fs.tar.gz"
  [[ -f "${src}/db.sql"   ]] && mysql -uroot -p"${DB_PASS:-}" < "${src}/db.sql" && log "DB restored from ${src}/db.sql"
  log "Restore finished: $src"
}

case "$ACTION" in
  --backup)  backup_files; backup_db ;;
  --restore) restore_all "$RESTORE_DATE" ;;
esac
exit 0