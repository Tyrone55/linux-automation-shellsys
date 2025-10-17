#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../src"
sudo mkdir -p /opt/shellsys /etc/shellsys /var/log/shellsys /opt/backup
sudo cp -r opt/shellsys/* /opt/shellsys/
sudo cp -r etc/shellsys/* /etc/shellsys/
sudo chmod +x /opt/shellsys/*.sh
echo "[+] Installed. Try: sudo /opt/shellsys/main.sh --auto"

# ===============================================
# ShellSys 系统安装与定时任务配置脚本
# 功能：
#   1. 初始化目录结构与权限
#   2. 自动部署主控及各模块
#   3. 自动配置 crond 定时任务（每2分钟执行一次）
#   4. 汇总日志到 main_YYYY-MM-DD.log
# ===============================================

set -Eeuo pipefail
trap 'echo "[FATAL] setup.sh failed at line $LINENO" >&2; exit 4' ERR

echo "[+] Installing ShellSys ..."

# === 一、初始化目录结构 ===
mkdir -p /opt/shellsys /etc/shellsys /var/log/shellsys /opt/backup /root/.cache
chmod 700 /root/.cache
chmod -R 755 /opt/shellsys
chmod -R 755 /var/log/shellsys

# === 二、创建默认配置文件 ===
CONF="/opt/shellsys/config.ini"
if [[ ! -f "$CONF" ]]; then
cat > "$CONF" <<'EOF'
BACKUP_DIR=/opt/backup
LOG_DIR=/var/log/shellsys
USER_LIST=/etc/shellsys/user_list.txt
THRESHOLD_CPU=85
THRESHOLD_MEM=80
THRESHOLD_DISK=90
DB_BACKUP=on
DB_PASS=admin1
EOF
echo "[OK] config.ini created."
else
echo "[*] config.ini already exists. Skipped."
fi

# === 三、检测并安装 crond 服务 ===
if ! rpm -q cronie >/dev/null 2>&1; then
  echo "[INFO] Installing cronie ..."
  dnf install -y cronie cronie-anacron
fi
systemctl enable --now crond

# === 四、配置 /etc/cron.d 计划任务 ===
CRON_FILE="/etc/cron.d/shellsys"
LOG_DIR="/var/log/shellsys"

cat > "$CRON_FILE" <<'EOF'
SHELL=/bin/bash
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LOGNAME=root
*/2 * * * * root /opt/shellsys/main.sh --auto >> /var/log/shellsys/main_$(date +\%F).log 2>&1 && echo "[Cron executed at $(date '+\%F %T')]" >> /var/log/shellsys/cron.log
EOF

chmod 644 "$CRON_FILE"
command -v dos2unix >/dev/null 2>&1 && dos2unix -q "$CRON_FILE" || true
systemctl reload crond

echo "[OK] Cron job installed: /etc/cron.d/shellsys"
echo "[INFO] 任务每2分钟触发一次，日志位于 /var/log/shellsys/"

# === 五、首次手动触发验证 ===
bash -lc '/opt/shellsys/main.sh --auto >> /var/log/shellsys/main_$(date +%F).log 2>&1 && echo "[Cron executed at $(date "+%F %T")]" >> /var/log/shellsys/cron.log'

echo "[+] Installed. Try: sudo /opt/shellsys/main.sh --auto"
echo "[+] Cron 已配置完成。查看任务: cat /etc/cron.d/shellsys"
echo "[+] 查看日志: tail -f /var/log/shellsys/main_$(date +%F).log"
echo "[+] 或查看触发记录: tail -f /var/log/shellsys/cron.log"
echo
echo "[DONE] ShellSys installation completed successfully."



