#!/usr/bin/env bash
set -e
rm -f /etc/cron.d/shellsys || true
systemctl reload crond || true
rm -f /opt/shellsys/main.sh /opt/shellsys/user_mgr.sh /opt/shellsys/sys_monitor.sh /opt/shellsys/log_manage.sh /opt/shellsys/backup_restore.sh /opt/shellsys/secure_ctrl.sh /opt/shellsys/config.ini
rm -f /etc/shellsys/user_list.txt /etc/shellsys/whitelist.txt
echo "[+] Uninstalled (kept backups/logs)."
