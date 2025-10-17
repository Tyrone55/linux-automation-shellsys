#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] setup.sh failed at line $LINENO" >&2; exit 4' ERR

MODE="${1:-demo}"   # demo=每2分钟, normal=每天02:00
MAIN="/opt/shellsys/main.sh"
LOG_DIR="/var/log/shellsys"
CRON_FILE="/etc/cron.d/shellsys"

echo "[INFO] 安装 ShellSys（模式：$MODE）..."

# 安装与目录准备（存在则忽略）
install -d /opt/shellsys /etc/shellsys "$LOG_DIR" /opt/backup /root/.cache
install -m 755 src/opt/shellsys/*.sh /opt/shellsys/ 2>/dev/null || true
install -m 644 src/opt/shellsys/config.ini /opt/shellsys/config.ini 2>/dev/null || true
install -m 644 src/etc/shellsys/*.txt /etc/shellsys/ 2>/dev/null || true
chmod 700 /root/.cache
chmod 755 "$LOG_DIR"
chmod +x /opt/shellsys/*.sh || true

# 时间同步（chrony）
if ! rpm -q chrony >/dev/null 2>&1; then dnf install -y chrony; fi
systemctl enable --now chronyd || true
timedatectl set-ntp true || true

# cron 服务
if ! rpm -q cronie >/dev/null 2>&1; then dnf install -y cronie cronie-anacron; fi
systemctl enable --now crond

# 写入 /etc/cron.d 任务（根据模式）
case "$MODE" in
  demo)   SCHEDULE="*/2 * * * *" ;;
  normal) SCHEDULE="0 2 * * *" ;;
  *) echo "[ERR] 未知模式：$MODE（仅支持 demo|normal）" >&2; exit 2 ;;
esac

cat > "$CRON_FILE" <<EOF
SHELL=/bin/bash
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LOGNAME=root
$SCHEDULE root /opt/shellsys/main.sh --auto >> $LOG_DIR/cron_wrapper.log 2>&1
EOF
chmod 644 "$CRON_FILE"
command -v dos2unix >/dev/null 2>&1 && dos2unix -q "$CRON_FILE" || true
systemctl reload crond

# 首次手动触发一次，验证日志链路
if [[ -x "$MAIN" ]]; then
  "$MAIN" --auto || true
fi

echo "[OK] 安装完成（模式：$MODE）。"
echo "[INFO] 计划任务："; cat "$CRON_FILE"
echo "[INFO] 主控日志：$LOG_DIR/main_$(date +%F).log"
echo "[INFO] Wrapper日志：$LOG_DIR/cron_wrapper.log"
