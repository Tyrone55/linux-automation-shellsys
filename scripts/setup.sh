#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] setup.sh failed at line $LINENO" >&2; exit 4' ERR
MODE="${1:-demo}"
echo "[INFO] 安装 ShellSys（模式：$MODE）..."

#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] setup.sh failed at line $LINENO" >&2; exit 4' ERR

echo "[INFO] 安装 ShellSys 到 /opt/shellsys ..."

# 安装文件
install -d /opt/shellsys /etc/shellsys /var/log/shellsys /opt/backup /root/.cache
install -m 755 src/opt/shellsys/*.sh /opt/shellsys/
install -m 644 src/opt/shellsys/config.ini /opt/shellsys/config.ini
install -m 644 src/etc/shellsys/*.txt /etc/shellsys/

# 时间同步（chrony）
if ! rpm -q chrony >/dev/null 2>&1; then dnf install -y chrony; fi
systemctl enable --now chronyd || true
timedatectl set-ntp true || true

# cron 服务
if ! rpm -q cronie >/dev/null 2>&1; then dnf install -y cronie cronie-anacron; fi
systemctl enable --now crond

# 写入 /etc/cron.d 任务（每2分钟），只做 wrapper 日志，主日志由 main.sh 写入
cat >/etc/cron.d/shellsys <<'EOF'
SHELL=/bin/bash
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LOGNAME=root
*/2 * * * * root /opt/shellsys/main.sh --auto >> /var/log/shellsys/cron_wrapper.log 2>&1
EOF
chmod 644 /etc/cron.d/shellsys
systemctl reload crond

# 首次触发一次
/opt/shellsys/main.sh --auto || true

echo "[OK] Installed. Try: sudo /opt/shellsys/main.sh --auto"
