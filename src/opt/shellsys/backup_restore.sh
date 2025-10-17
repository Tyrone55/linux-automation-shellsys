#!/usr/bin/env bash
# backup_restore.sh — 文件与数据库备份/恢复
set -Eeuo pipefail
trap 'echo "[FATAL] backup_restore.sh failed at line $LINENO" >&2; exit 4' ERR

CONF="/opt/shellsys/config.ini"
[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] config.ini missing: $CONF"; exit 1; }

MODULE="backup_restore"; TODAY="$(date +%F)"
LOG_DIR="${LOG_DIR:-/var/log/shellsys}"; mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${MODULE}_${TODAY}.log"
log(){ printf '%s [%s] %s %s\n' "$(date '+%F %T')" "$MODULE" "${EXEC_ID:-NA}" "$*" | tee -a "$LOG_FILE"; }

BACKUP_DIR="${BACKUP_DIR:-/opt/backup}"; mkdir -p "$BACKUP_DIR/$TODAY"

ACTION="--backup"; RESTORE_DATE=""
for a in "$@"; do
  case "$a" in
    --backup) ACTION="--backup" ;;
    --restore) ACTION="--restore" ;;
    --config=*) ;;
    *) RESTORE_DATE="$a" ;;
  esac
done

backup_files(){
  local dst="$BACKUP_DIR/$TODAY/fs.tar.gz"
  tar -czf "$dst" /etc/shellsys /opt/shellsys 2>/dev/null && log "File backup finished: $dst"
}

backup_db(){
  [[ "${DB_BACKUP:-off}" == "on" ]] || { log "DB backup disabled"; return; }
  local dst="$BACKUP_DIR/$TODAY/db.sql"
  if command -v mysqldump >/dev/null 2>&1; then
    mysqldump -uroot -p"${DB_PASS:-}" --all-databases > "$dst" 2>>"$LOG_FILE" && log "Database backup finished: $dst"
  else
    log "mysqldump not found, skip DB backup"
  fi
}

restore_all(){
  local src="$BACKUP_DIR/${RESTORE_DATE}"
  [[ -d "$src" ]] || { log "Backup set not found: $src"; exit 1; }
  [[ -f "$src/fs.tar.gz" ]] && tar -xzf "$src/fs.tar.gz" -C / && log "FS restored from $src/fs.tar.gz"
  if [[ -f "$src/db.sql" ]] && command -v mysql >/dev/null 2>&1; then
    mysql -uroot -p"${DB_PASS:-}" < "$src/db.sql" && log "DB restored from $src/db.sql"
  fi
  log "Restore finished: $src"
}

case "$ACTION" in
  --backup) backup_files; backup_db ;;
  --restore) restore_all ;;
  *) echo "Usage: $0 [--backup] | [--restore YYYY-MM-DD]"; exit 2 ;;
esac
