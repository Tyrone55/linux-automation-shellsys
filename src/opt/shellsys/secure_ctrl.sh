#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] secure_ctrl.sh failed at line $LINENO" >&2; exit 4' ERR
CONF="/opt/shellsys/config.ini"
[[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] config.ini missing: $CONF"; exit 1; }
MODULE="secure_ctrl"; TODAY="$(date +%F)"
LOG_FILE="${LOG_DIR:-/var/log/shellsys}/${MODULE}_${TODAY}.log"
mkdir -p "${LOG_DIR:-/var/log/shellsys}"
log_event(){ printf '%s [%s] %s\n' "$(date '+%F %T')" "$MODULE" "$*" | tee -a "$LOG_FILE"; }
check_permission(){ [[ "$(id -u)" -eq 0 ]] || { echo "Permission denied. Run as root."; exit 2; }; }
command_whitelist(){ local cmd="$1"; local wl="/etc/shellsys/whitelist.txt"; [[ -f "$wl" ]] || { log_event "whitelist not found: $wl"; exit 1; }; grep -qw -- "$cmd" "$wl" || { log_event "Unauthorized command: $cmd"; exit 3; }; }
case "${1:---check}" in --check) check_permission; log_event "sudo verified; whitelist policy active.";; --allow) shift; [[ -n "${1:-}" ]] || { echo "Usage: $0 --allow <cmd>"; exit 1; }; command_whitelist "$1"; log_event "Allowed: $1";; *) echo "Usage: $0 --check | --allow <cmd>"; exit 1;; esac
exit 0
