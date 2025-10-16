#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] backup_restore.sh failed at line $LINENO" >&2; exit 4' ERR
CONF="/opt/shellsys/config.ini"
[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] config.ini missing: $CONF"; exit 1; }
MODULE="backup_restore"; TODAY="$(date +%F)"
LOG_FILE="${LOG_DIR:-/var/log/shellsys}/${MODULE}_${TODAY}.log"
mkdir -p "${LOG_DIR:-/var/log/shellsys}" "${BACKUP_DIR:-/opt/backup}"
log_event(){ printf '%s [%s] %s\n' "$(date '+%F %T')" "$MODULE" "$*" | tee -a "$LOG_FILE"; }
[[ "$(id -u)" -eq 0 ]] || { echo "Permission denied. Run as root."; exit 2; }
dest="${BACKUP_DIR}/${TODAY}"; mkdir -p "$dest"
backup_files(){ tar -czf "${dest}/fs.tar.gz" /etc /home /opt 2>/dev/null; log_event "File backup finished: ${dest}/fs.tar.gz"; }
backup_db(){ [[ "${DB_BACKUP:-off}" == "on" ]] || { log_event "DB backup disabled"; return 0; }; mysqldump -uroot -p"${DB_PASS:-}" --all-databases > "${dest}/db.sql"; log_event "Database backup finished: ${dest}/db.sql"; }
restore_all(){ local src="${BACKUP_DIR}/${1:-$TODAY}"; [[ -d "$src" ]] || { log_event "Backup set not found: $src"; exit 1; }; [[ -f "${src}/fs.tar.gz" ]] && tar -xzf "${src}/fs.tar.gz" -C / && log_event "FS restored from ${src}/fs.tar.gz"; [[ -f "${src}/db.sql" ]] && mysql -uroot -p"${DB_PASS:-}" < "${src}/db.sql" && log_event "DB restored from ${src}/db.sql"; log_event "Restore finished: $src"; }
case "${1:---backup}" in --backup) backup_files; backup_db;; --restore) shift; restore_all "${1:-}";; *) echo "Usage: $0 [--backup] | [--restore YYYY-MM-DD]"; exit 1;; esac
exit 0
