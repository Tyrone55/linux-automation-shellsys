#!/usr/bin/env bash
# user_mgr.sh — 批量用户管理
set -Eeuo pipefail
trap 'echo "[FATAL] user_mgr.sh failed at line $LINENO" >&2; exit 4' ERR

CONF="/opt/shellsys/config.ini"
[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] config.ini missing: $CONF"; exit 1; }

MODULE="user_mgr"; TODAY="$(date +%F)"
LOG_DIR="${LOG_DIR:-/var/log/shellsys}"; mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${MODULE}_${TODAY}.log"
log(){ printf '%s [%s] %s %s\n' "$(date '+%F %T')" "$MODULE" "${EXEC_ID:-NA}" "$*" | tee -a "$LOG_FILE"; }

[[ "$(id -u)" -eq 0 ]] || { echo "[user_mgr] Permission denied. Run as root." >&2; exit 2; }

ULIST="${USER_LIST:-/etc/shellsys/user_list.txt}"
[[ -f "$ULIST" ]] || { log "User list not found: $ULIST"; exit 0; }

while IFS=: read -r u g p; do
  [[ -z "$u" ]] && continue
  if id "$u" &>/dev/null; then
    log "User $u already exists."
  else
    groupadd -f "$g" || true
    useradd -m -g "$g" "$u" && echo "$u:$p" | chpasswd && log "User $u created."
  fi
done < "$ULIST"
