#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../src"
sudo mkdir -p /opt/shellsys /etc/shellsys /var/log/shellsys /opt/backup
sudo cp -r opt/shellsys/* /opt/shellsys/
sudo cp -r etc/shellsys/* /etc/shellsys/
sudo chmod +x /opt/shellsys/*.sh
echo "[+] Installed. Try: sudo /opt/shellsys/main.sh --auto"

# ===============================================
# ShellSys 系统安装与自动任务配置脚本
# （含系统时间自动同步 + 定时任务自动安装）
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

# === 三、检测并同步系统时间（NTP） ===
echo "[INFO] 检查系统时间同步状态..."
if ! rpm -q chrony >/dev/null 2>&1; then
  echo "[INFO] Installing chrony ..."
  dnf install -y chrony
fi

systemctl enable --now chronyd

# 启用 NTP 自动同步
timedatectl set-ntp true

# 等待同步完成
sleep 2

if timedatectl status | grep -q "System clock synchronized: yes"; then
  echo "[OK] 系统时间已同步。"
else
  echo "[WARN] 系统时间尚未同步，尝试强制校时..."
  chronyc makestep || true
fi

# 打印当前时间
timedatectl status | grep -E "Time zone|Local time|System clock"

# === 四、安装并启动 crond 服务 ===
echo "[INFO] 检查 crond 服务..."
if ! rpm -q cronie >/dev/null 2>&1; then
  echo "[INFO] Installing cronie ..."
  dnf install -y cronie cronie-anacron
fi
systemctl enable --now crond

# === 五、配置 /etc/cron.d 定时任务 ===
CRON_FILE="/etc/cron.d/shellsys"
LOG_DIR="/var/log/shellsys"

cat > "$CRON_FILE" <<'EOF'
SHELL=/bin/bash
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LOGNAME=root
*/2 * * * * root bash -lc '/opt/shellsys/main.sh --auto >> /var/log/shellsys/main_$(date +%F).log 2>&1 && echo "[Cron executed at $(date "+%F %T")]" >> /var/log/shellsys/cron.log'
EOF

chmod 644 "$CRON_FILE"
command -v dos2unix >/dev/null 2>&1 && dos2unix -q "$CRON_FILE" || true
systemctl reload crond

echo "[OK] Cron job installed: /etc/cron.d/shellsys"
echo "[INFO] 任务每2分钟触发一次，日志位于 /var/log/shellsys/"

# === 六、首次手动触发验证 ===
bash -lc '/opt/shellsys/main.sh --auto >> /var/log/shellsys/main_$(date +%F).log 2>&1 && echo "[Cron executed at $(date "+%F %T")]" >> /var/log/shellsys/cron.log'

echo "[+] Installed. Try: sudo /opt/shellsys/main.sh --auto"
echo "[+] Cron 已配置完成。查看任务: cat /etc/cron.d/shellsys"
echo "[+] 查看日志: tail -f /var/log/shellsys/main_$(date +%F).log"
echo "[+] 或查看触发记录: tail -f /var/log/shellsys/cron.log"
echo
echo "[DONE] ShellSys installation completed successfully."
