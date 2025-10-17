#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../src"
sudo mkdir -p /opt/shellsys /etc/shellsys /var/log/shellsys /opt/backup
sudo cp -r opt/shellsys/* /opt/shellsys/
sudo cp -r etc/shellsys/* /etc/shellsys/
sudo chmod +x /opt/shellsys/*.sh
echo "[+] Installed. Try: sudo /opt/shellsys/main.sh --auto"

# ===============================================
# === 自动配置定时任务（演示模式：每2分钟触发一次） ===
# ===============================================

LOG_DIR="/var/log/shellsys"
mkdir -p "$LOG_DIR"

# 定时任务命令（注意转义符号，保证 crontab 能解析）
CRON_JOB="*/2 * * * * /opt/shellsys/main.sh --auto >> $LOG_DIR/main_\\\$(date +\\%F).log 2>&1 && echo \"[Cron executed at \$(date '+\\%F %T')]\" >> $LOG_DIR/cron.log"

echo "[INFO] 正在配置定时任务..."
echo "[INFO] Cron Job 内容如下："
echo "       $CRON_JOB"
echo

# 检查是否已存在旧任务（防止重复）
if crontab -l 2>/dev/null | grep -q "/opt/shellsys/main.sh"; then
    echo "[WARN] 已检测到旧的 ShellSys 定时任务，正在移除..."
    crontab -l 2>/dev/null | grep -v "/opt/shellsys/main.sh" | crontab -
fi

# 添加新的任务
( crontab -l 2>/dev/null; echo "$CRON_JOB" ) | crontab -

if crontab -l 2>/dev/null | grep -q "/opt/shellsys/main.sh"; then
    echo "[OK] 已成功安装 ShellSys 定时任务！"
    echo "[INFO] 你可以运行 'crontab -l' 查看当前任务。"
    echo "[INFO] 执行日志将汇总到："
    echo "       → $LOG_DIR/main_YYYY-MM-DD.log"
    echo "       → $LOG_DIR/cron.log"
else
    echo "[ERR] 未能成功安装定时任务，请手动检查 crontab 权限。"
fi

echo

