#!/usr/bin/env bash
set -e
PASS=1
check(){ [[ -e "$1" ]] && echo "[OK] $2 -> $1" || { echo "[!!] MISSING: $2 -> $1"; PASS=0; } }
check /opt/shellsys "Scripts dir"
check /etc/shellsys "Etc dir"
check /var/log/shellsys "Log dir"
check /opt/backup "Backup dir"
for f in /opt/shellsys/main.sh /opt/shellsys/user_mgr.sh /opt/shellsys/sys_monitor.sh /opt/shellsys/log_manage.sh /opt/shellsys/backup_restore.sh /opt/shellsys/secure_ctrl.sh /opt/shellsys/config.ini /etc/shellsys/user_list.txt /etc/shellsys/whitelist.txt; do
  [[ -f "$f" ]] && echo "[OK] $f" || { echo "[!!] Missing file: $f"; PASS=0; }
done
[[ $PASS -eq 1 ]] && echo "[PASS] Thesis directory structure is consistent." || { echo "[FAIL] Please sync files."; exit 1; }
