#!/usr/bin/env bash
# 非交互：按 config.ini 执行文件/数据库备份
set -Eeuo pipefail
trap 'echo "[FATAL] backup_restore.sh 发生错误（行号 $LINENO）" >&2; exit 4' ERR

CONF="/opt/shellsys/config.ini"
[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] 缺少配置文件：$CONF"; exit 1; }

MODULE="backup_restore"; TODAY="$(date +%F)"; LOG_DIR="${LOG_DIR:-/var/log/shellsys}"; mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/backup_restore_$TODAY.log"; SEQ=0
slog(){ SEQ=$((SEQ+1)); printf '%s [backup_restore #%03d] ExecID=%s | %s\n' "$(date '+%F %T')" "$SEQ" "${EXEC_ID:-NA}" "$*" | tee -a "$LOG_FILE"; echo >> "$LOG_FILE"; }

DST_DIR="${BACKUP_DIR:-/opt/backup}/$TODAY"; install -d "$DST_DIR"

slog "开始：文件系统备份"
if tar -czf "$DST_DIR/fs.tar.gz" /etc/shellsys /opt/shellsys >/dev/null 2>&1; then
  slog "文件备份完成：$DST_DIR/fs.tar.gz"
else
  slog "文件备份警告：tar 返回非零，已跳过或部分失败"
fi

MYSQL_BIN="$(command -v mysql || true)"; MARIADB_BIN="$(command -v mariadb || true)"
DBCLI="${MYSQL_BIN:-$MARIADB_BIN}"
DUMPCLI="$(command -v mysqldump || true)"
KEYFILE="/etc/shellsys/.db_key"

dec_pass(){ local enc="$1"; [[ -f "$KEYFILE" ]] || { echo ""; return 1; }; printf '%s' "$enc" | openssl enc -aes-256-cbc -a -d -pbkdf2 -pass file:"$KEYFILE" 2>/dev/null || true; }

if [[ "${DB_BACKUP:-off}" != "on" ]]; then slog "数据库备份：DB_BACKUP=${DB_BACKUP:-off}，跳过"; exit 0; fi
if [[ -z "$DBCLI" || -z "$DUMPCLI" ]]; then slog "数据库备份：未检测到 mysql/mariadb 客户端或 mysqldump，跳过"; exit 0; fi
if [[ -z "${DB_NAME:-}" ]]; then slog "数据库备份：未在 config.ini 设置 DB_NAME，跳过"; exit 0; fi

DB_HOST_E="${DB_HOST:-localhost}"; DB_USER_E="${DB_USER:-root}"
DB_PASS_E=""; if [[ -n "${DB_PASS:-}" ]]; then DB_PASS_E="$DB_PASS"; elif [[ -n "${DB_PASS_ENC:-}" ]]; then DB_PASS_E="$(dec_pass "$DB_PASS_ENC")"; fi

o=(); [[ -n "$DB_PASS_E" ]] && o=(-p"$DB_PASS_E")
if ! "$DBCLI" -h "$DB_HOST_E" -u "$DB_USER_E" "${o[@]}" -N -e "SELECT 1;" >/dev/null 2>&1; then
  slog "数据库备份：连接失败，跳过"
  exit 0
fi

IFS=',' read -r -a DBS <<< "$DB_NAME"
for db in "${DBS[@]}"; do
  db="$(echo "$db" | xargs)"; [[ -z "$db" ]] && continue
  out="$DST_DIR/${db}.sql"
  if "$DUMPCLI" -h "$DB_HOST_E" -u "$DB_USER_E" "${o[@]}" "$db" > "$out" 2>>"$LOG_FILE"; then
    slog "数据库备份完成：$out"
  else
    slog "数据库备份失败：$db（见日志）"
  fi
done

slog "完成：备份任务（包含文件 + 数据库）"
