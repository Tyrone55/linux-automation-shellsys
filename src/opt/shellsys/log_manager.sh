#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] log_manager.sh 发生错误（行号 $LINENO）" >&2; exit 4' ERR

CONF="/opt/shellsys/config.ini"; [[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] 缺少配置文件：$CONF"; exit 1; }
MODULE="log_manager"; TODAY="$(date +%F)"; LOG_DIR="${LOG_DIR:-/var/log/shellsys}"; mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/log_manager_$TODAY.log"; SEQ=0
slog(){ SEQ=$((SEQ+1)); printf '%s [log_manager #%03d] ExecID=%s | %s\n' "$(date '+%F %T')" "$SEQ" "${EXEC_ID:-NA}" "$*" | tee -a "$LOG_FILE"; echo >> "$LOG_FILE"; }

slog "开始：日志扫描与汇总"
# 简单扫描所有模块日志并生成当日报告
REPORT="$LOG_DIR/report_$(date +%F).log"
{
  echo "============= ShellSys 日志汇总报告 $(date '+%F %T') ============="
  echo
  for f in "$LOG_DIR"/*_"$(date +%F)".log; do
    [[ -f "$f" ]] || continue
    echo "[文件] $(basename "$f")"
    echo "------------------------------------------------------------"
    tail -n "${REPORT_MAX_LINES:-200}" "$f"
    echo
  done
} > "$REPORT"
slog "完成：日志扫描与汇总（输出：$REPORT）"
