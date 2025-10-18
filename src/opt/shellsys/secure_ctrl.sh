#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] secure_ctrl.sh 发生错误（行号 $LINENO）" >&2; exit 4' ERR

CONF="/opt/shellsys/config.ini"; [[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] 缺少配置文件：$CONF"; exit 1; }
MODULE="secure_ctrl"; TODAY="$(date +%F)"; LOG_DIR="${LOG_DIR:-/var/log/shellsys}"; mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/secure_ctrl_$TODAY.log"; SEQ=0
slog(){ SEQ=$((SEQ+1)); printf '%s [secure_ctrl #%03d] ExecID=%s | %s\n' "$(date '+%F %T')" "$SEQ" "${EXEC_ID:-NA}" "$*" | tee -a "$LOG_FILE"; echo >> "$LOG_FILE"; }

slog "开始：系统级安全管控"

if [[ -f "${SUDO_POLICY:-/etc/shellsys/sudo_policy.conf}" ]]; then
  install -m 440 "${SUDO_POLICY:-/etc/shellsys/sudo_policy.conf}" /etc/sudoers.d/shellsys && slog "已更新 sudo 策略"
  if command -v visudo >/dev/null 2>&1; then
    visudo -cf /etc/sudoers && slog "sudoers 校验通过" || slog "sudoers 校验失败（请核对策略）"
  fi
else
  slog "未发现 sudo 策略文件（跳过）"
fi

systemctl is-active rsyslog >/dev/null 2>&1 && slog "审计：rsyslog 运行中" || slog "审计：rsyslog 未运行（可选）"

if [[ -f "${SECURE_WHITELIST:-/etc/shellsys/secure_whitelist.txt}" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" || "$f" =~ ^# ]] && continue
    [[ -e "$f" ]] && slog "存在：$f" || slog "缺失：$f"
  done < "${SECURE_WHITELIST:-/etc/shellsys/secure_whitelist.txt}"
else
  slog "未发现白名单（跳过）"
fi

slog "完成：系统级安全管控"
