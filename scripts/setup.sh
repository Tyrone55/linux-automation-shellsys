#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../src"
sudo mkdir -p /opt/shellsys /etc/shellsys /var/log/shellsys /opt/backup
sudo cp -r opt/shellsys/* /opt/shellsys/
sudo cp -r etc/shellsys/* /etc/shellsys/
sudo chmod +x /opt/shellsys/*.sh
echo "[+] Installed. Try: sudo /opt/shellsys/main.sh --auto"

# ===============================================
# Cron：每2分钟执行一次，并汇总到 main_YYYY-MM-DD.log
# ===============================================
LOG_DIR="/var/log/shellsys"
mkdir -p "$LOG_DIR"

# 注意下面的转义：\\$(date +\\%F) 是为了让 crontab 里按天滚动
CRON_JOB="*/2 * * * * /opt/shellsys/main.sh --auto >> $LOG_DIR/main_\\\$(date +\\%F).log 2>&1 && echo \"[Cron executed at \$(date '+\\%F %T')]\" >> $LOG_DIR/cron.log"

echo "[INFO] 正在配置定时任务..."
echo "       $CRON_JOB"

# 1) 读取现有 crontab（可能为空），先移除旧的 shellsys 任务
TMPFILE="$(mktemp)"
crontab -l 2>/dev/null | grep -v '/opt/shellsys/main.sh' > "$TMPFILE" || true
# 2) 追加新任务再装回去
printf '%s\n' "$CRON_JOB" >> "$TMPFILE"
crontab "$TMPFILE"
rm -f "$TMPFILE"

# 3) 校验是否安装成功（不依赖 grep 成功码）
if crontab -l 2>/dev/null | sed 's/[[:space:]]\+/ /g' | grep -Fq "/opt/shellsys/main.sh --auto"; then
  echo "[OK] Cron job installed successfully."
  echo "[INFO] 查看任务: crontab -l"
  echo "[INFO] 日志: $LOG_DIR/main_YYYY-MM-DD.log 以及 $LOG_DIR/cron.log"
else
  echo "[ERR] Cron job 未写入成功。请检查 cronie 是否安装、crond 是否在运行，以及 /etc/cron.allow|deny。"
fi

