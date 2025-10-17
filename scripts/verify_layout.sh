#!/usr/bin/env bash
set -Eeuo pipefail
ROOTS=(/opt/shellsys /etc/shellsys /var/log/shellsys /opt/backup)
for d in "${ROOTS[@]}"; do [[ -d "$d" ]] || { echo "[MISS] $d"; exit 1; }; done
REQ=(/opt/shellsys/main.sh /opt/shellsys/user_mgr.sh /opt/shellsys/sys_monitor.sh /opt/shellsys/log_manage.sh /opt/shellsys/backup_restore.sh /opt/shellsys/secure_ctrl.sh /opt/shellsys/config.ini /etc/shellsys/user_list.txt /etc/shellsys/whitelist.txt)
for f in "${REQ[@]}"; do [[ -f "$f" ]] || { echo "[MISS] $f"; exit 1; }; done
echo "[PASS] ShellSys layout verified."
