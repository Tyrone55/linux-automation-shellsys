#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] cron_mode.sh 发生错误（行号 $LINENO）" >&2; exit 4' ERR

MODE="${1:-}"
[[ -z "$MODE" ]] && { echo "用法：cron_mode.sh demo|normal|status|disable"; exit 2; }

LINE_DEMO="*/2 * * * * /bin/bash -lc '/opt/shellsys/main.sh --cron-run >> /var/log/shellsys/main_\\$(date +\\%F).log 2>&1; echo \"[Cron executed at \\$(date +\\%F\\ %T)]\" >> /var/log/shellsys/cron.log'"
LINE_NORMAL="0 2 * * * /bin/bash -lc '/opt/shellsys/main.sh --cron-run >> /var/log/shellsys/main_\\$(date +\\%F).log 2>&1; echo \"[Cron executed at \\$(date +\\%F\\ %T)]\" >> /var/log/shellsys/cron.log'"

case "$MODE" in
  demo)
    (crontab -l 2>/dev/null | grep -v '/opt/shellsys/main.sh --cron-run' || true; echo "$LINE_DEMO") | crontab -
    echo "[OK] 已设置为演示模式（每 2 分钟执行一次）。"
    ;;
  normal)
    (crontab -l 2>/dev/null | grep -v '/opt/shellsys/main.sh --cron-run' || true; echo "$LINE_NORMAL") | crontab -
    echo "[OK] 已设置为正式模式（每天 02:00 执行）。"
    ;;
  disable)
    crontab -l 2>/dev/null | grep -v '/opt/shellsys/main.sh --cron-run' | crontab - || true
    echo "[OK] 已移除定时任务。"
    ;;
  status)
    echo "[INFO] 当前 crontab："
    crontab -l 2>/dev/null || echo "(为空)"
    ;;
  *)
    echo "用法：cron_mode.sh demo|normal|status|disable"; exit 2;;
esac
