#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] main.sh 发生错误（行号 $LINENO）" >&2; exit 4' ERR

usage(){ cat <<'USAGE'
ShellSys 主控 — 用法（必须输入参数）
  main.sh --all
  main.sh --task <模块>    # backup_restore|log_manager|secure_ctrl|user_mgr|sys_monitor
  main.sh --cron-run       # 仅执行 log_manager + sys_monitor + backup_restore（非交互）
  main.sh --cron-mode <t>  # demo|normal|status|disable
  main.sh -h|--help

说明：数据库检测/库选择已在 setup.sh 完成；运行期不再交互。
USAGE
}

[[ $# -eq 0 ]] && { echo "[ERR] 未输入参数。"; usage; exit 2; }
CONF="/opt/shellsys/config.ini"; [[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] 缺少配置文件：$CONF"; exit 1; }

LOG_DIR="${LOG_DIR:-/var/log/shellsys}"; mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/main_$(date +%F).log"

exec 9>/var/lock/shellsys.lock
flock -n 9 || { printf '%s [main] ExecID=%s | 已有任务在运行，自动退出。\n\n' "$(date '+%F %T')" "${EXEC_ID:-NA}" >> "$LOG_FILE"; exit 0; }

EXEC_ID="${EXEC_ID:-$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)}"; export EXEC_ID

log(){ printf '%s [main] ExecID=%s | %s\n\n' "$(date '+%F %T')" "${EXEC_ID:-NA}" "$*" | tee -a "$LOG_FILE"; }
pipe_to_main(){ awk '{print; print ""}'; }

run_user(){        /opt/shellsys/user_mgr.sh       --config="$CONF" 2>&1 | pipe_to_main | tee -a "$LOG_FILE"; printf '\n' >> "$LOG_FILE"; }
run_monitor(){     /opt/shellsys/sys_monitor.sh    --config="$CONF" 2>&1 | pipe_to_main | tee -a "$LOG_FILE"; printf '\n' >> "$LOG_FILE"; }
run_log_manager(){ /opt/shellsys/log_manager.sh    --config="$CONF" 2>&1 | pipe_to_main | tee -a "$LOG_FILE"; printf '\n' >> "$LOG_FILE"; }
run_backup(){      /opt/shellsys/backup_restore.sh --config="$CONF" 2>&1 | pipe_to_main | tee -a "$LOG_FILE"; printf '\n' >> "$LOG_FILE"; }

confirm(){ local p="$1"; local a; read -r -p "$p（yes/no）： " a; case "${a,,}" in y|yes) return 0;; *) echo "[*] 已取消。"; return 1;; esac; }
generate_report(){ /opt/shellsys/log_manager.sh --report-only --config="$CONF" >/dev/null 2>&1 || true; }

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --all)
    log "执行ID：$EXEC_ID | 开始：全量执行"
    run_user
    run_monitor
    run_log_manager
    run_backup
    /opt/shellsys/secure_ctrl.sh --config="$CONF" 2>&1 | pipe_to_main | tee -a "$LOG_FILE"; printf '\n' >> "$LOG_FILE"
    log "执行ID：$EXEC_ID | 完成：全量执行"
    generate_report
    ;;
  --task)
    shift; m="${1:-}"; [[ -z "$m" ]] && { echo "[ERR] 缺少模块名"; usage; exit 2; }
    log "执行ID：$EXEC_ID | 开始：单模块 | $m"
    case "$m" in
      backup_restore) run_backup ;;
      log_manager|log_manage) run_log_manager ;;
      secure_ctrl) confirm "即将执行安全管控" && /opt/shellsys/secure_ctrl.sh --config="$CONF" 2>&1 | pipe_to_main | tee -a "$LOG_FILE"; printf '\n' >> "$LOG_FILE" ;;
      user_mgr)    confirm "即将批量变更用户" && run_user || log "取消 user_mgr" ;;
      sys_monitor) run_monitor ;;
      *) echo "[ERR] 未知模块：$m"; usage; exit 2;;
    esac
    log "执行ID：$EXEC_ID | 完成：单模块 | $m"
    generate_report
    ;;
  --cron-run)
    log "执行ID：$EXEC_ID | 开始：定时任务子集（log_manager + sys_monitor + backup_restore）"
    run_log_manager
    run_monitor
    run_backup
    log "执行ID：$EXEC_ID | 完成：定时任务子集"
    generate_report
    ;;
  --cron-mode)
    shift; t="${1:-}"; [[ -z "$t" ]] && { echo "[ERR] 缺少类型"; usage; exit 2; }
    /opt/shellsys/cron_mode.sh "$t"
    ;;
  *) echo "[ERR] 未知参数：$1"; usage; exit 2;;
esac
