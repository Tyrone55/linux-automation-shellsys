#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] cron_switch.sh failed at line $LINENO" >&2; exit 4' ERR

MODE="${1:-status}"
CRON_FILE="/etc/cron.d/shellsys"
LOG_DIR="/var/log/shellsys"
MAIN="/opt/shellsys/main.sh"

ensure_cron(){
  if ! rpm -q cronie >/dev/null 2>&1; then dnf install -y cronie cronie-anacron; fi
  systemctl enable --now crond
  mkdir -p "$LOG_DIR"
  chmod 755 "$LOG_DIR"
}

write_cron(){
  local sched="$1"
  cat > "$CRON_FILE" <<EOF
SHELL=/bin/bash
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LOGNAME=root
$sched root /opt/shellsys/main.sh --auto >> $LOG_DIR/cron_wrapper.log 2>&1
EOF
  chmod 644 "$CRON_FILE"
  command -v dos2unix >/dev/null 2>&1 && dos2unix -q "$CRON_FILE" || true
  systemctl reload crond
  echo "[OK] 已切换为：$sched"
  cat "$CRON_FILE"
}

run_now(){
  bash -lc "$MAIN --auto >> $LOG_DIR/main_\$(date +%F).log 2>&1"
  echo "[OK] 已手动触发一次。"
  tail -n 5 "$LOG_DIR/main_$(date +%F).log" 2>/dev/null || true
}

status(){
  echo "=== /etc/cron.d/shellsys ==="
  [[ -f "$CRON_FILE" ]] && cat "$CRON_FILE" || echo "(not installed)"
  echo "=== crond ==="
  systemctl is-active crond || true
  echo "=== recent logs ==="
  tail -n 3 "$LOG_DIR/cron_wrapper.log" 2>/dev/null || echo "(no wrapper logs)"
  tail -n 3 "$LOG_DIR/main_$(date +%F).log" 2>/dev/null || echo "(no main logs)"
}

ensure_cron

case "$MODE" in
  demo)   write_cron "*/2 * * * *" ;;
  normal) write_cron "0 2 * * *" ;;
  run-now) run_now ;;
  status) status ;;
  *) echo "用法：$0 {demo|normal|status|run-now}" ; exit 2 ;;
esac
