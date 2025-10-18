#!/usr/bin/env bash
# verify_layout.sh — 校验部署是否完整；失败返回非 0
set -Eeuo pipefail
ROOTS=(/opt/shellsys /etc/shellsys /var/log/shellsys /opt/backup)
for d in "${ROOTS[@]}"; do
  [[ -d "$d" ]] || { echo "[MISS] 目录缺失：$d"; exit 1; }
done

REQ=(/opt/shellsys/main.sh /opt/shellsys/user_mgr.sh /opt/shellsys/sys_monitor.sh /opt/shellsys/log_manager.sh /opt/shellsys/backup_restore.sh /opt/shellsys/secure_ctrl.sh /opt/shellsys/config.ini /etc/shellsys/user_list.txt /etc/shellsys/whitelist.txt)
for f in "${REQ[@]}"; do
  [[ -e "$f" ]] || { echo "[MISS] 文件缺失：$f"; exit 1; }
done
echo "[PASS] ShellSys layout verified."
