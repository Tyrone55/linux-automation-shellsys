#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] user_mgr.sh failed at line $LINENO" >&2; exit 4' ERR
CONF="/opt/shellsys/config.ini"
[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] config.ini missing: $CONF"; exit 1; }
MODULE="user_mgr"; TODAY="$(date +%F)"
LOG_FILE="${LOG_DIR:-/var/log/shellsys}/${MODULE}_${TODAY}.log"
mkdir -p "${LOG_DIR:-/var/log/shellsys}"
log_event(){ printf '%s [%s] %s\n' "$(date '+%F %T')" "$MODULE" "$*" | tee -a "$LOG_FILE"; }
[[ "$(id -u)" -eq 0 ]] || { echo "Permission denied. Run as root."; exit 2; }
[[ -n "${USER_LIST:-}" && -f "$USER_LIST" ]] || { log_event "USER_LIST not found: ${USER_LIST:-unset}"; exit 1; }
add_user(){ local user="$1" group="$2" pass="$3"; if id "$user" &>/dev/null; then log_event "User $user already exists."; else getent group "$group" >/dev/null || groupadd "$group"; useradd -m -g "$group" "$user"; [[ -n "$pass" ]] && echo "$user:$pass" | chpasswd; log_event "User $user created."; fi; }
while IFS=':' read -r user group pass; do [[ -z "$user" ]] && continue; add_user "$user" "$group" "$pass"; done < "$USER_LIST"
exit 0
