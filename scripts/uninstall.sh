#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] uninstall.sh 发生错误（行号 $LINENO）" >&2; exit 4' ERR
[[ $EUID -eq 0 ]] || { echo "[ERR] 请使用 root：sudo bash scripts/uninstall.sh"; exit 2; }
CRON_FILE="/etc/cron.d/shellsys"
TARGETS=("/opt/shellsys" "/etc/shellsys" "/var/log/shellsys" "/var/lib/shellsys")
echo "=============================================="
echo "ShellSys 卸载向导"
echo "将删除：$CRON_FILE 与 ${TARGETS[*]}"
echo "=============================================="
read -r -p "确认卸载？（yes/no）: " ans
case "${ans,,}" in y|yes) ;; *) echo "[*] 已取消。"; exit 0;; esac
[[ -f "$CRON_FILE" ]] && rm -f "$CRON_FILE" && systemctl reload crond 2>/dev/null || true
for p in "${TARGETS[@]}"; do rm -rf "$p"; done
echo "[OK] 卸载完成"
