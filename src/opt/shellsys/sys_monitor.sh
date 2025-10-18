#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] sys_monitor.sh 发生错误（行号 $LINENO）" >&2; exit 4' ERR

CONF="/opt/shellsys/config.ini"; [[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] 缺少配置文件：$CONF"; exit 1; }
MODULE="sys_monitor"; TODAY="$(date +%F)"; LOG_DIR="${LOG_DIR:-/var/log/shellsys}"; mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/sys_monitor_$TODAY.log"; SEQ=0
slog(){ SEQ=$((SEQ+1)); printf '%s [sys_monitor #%03d] ExecID=%s | %s\n' "$(date '+%F %T')" "$SEQ" "${EXEC_ID:-NA}" "$*" | tee -a "$LOG_FILE"; echo >> "$LOG_FILE"; }

slog "开始：系统监控采集"

cpu_usage=$(awk -v FS=" " '/^cpu /{u=$2;n=$3;s=$4;i=$5;w=$6;irq=$7;sirq=$8;sum=u+n+s+i+w+irq+sirq; printf("%.1f", (sum-i)/sum*100)}' /proc/stat 2>/dev/null | head -n1)
mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
mem_free=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
mem_used=$((mem_total - mem_free))
mem_pct=$(awk -v u="$mem_used" -v t="$mem_total" 'BEGIN{if(t>0) printf("%.1f", u*100/t); else print "0.0"}')
disk_pct=$(df -P / | awk 'NR==2{gsub("%","",$5); print $5}')

warns=()
[[ ${cpu_usage%.*} -ge ${THRESHOLD_CPU:-999} ]] && warns+=("CPU≥${THRESHOLD_CPU}%")
[[ ${mem_pct%.*} -ge ${THRESHOLD_MEM:-999} ]] && warns+=("内存≥${THRESHOLD_MEM}%")
[[ ${disk_pct%.*} -ge ${THRESHOLD_DISK:-999} ]] && warns+=("磁盘≥${THRESHOLD_DISK}%")

slog "资源占用 | CPU=${cpu_usage:-N/A}% | 内存=${mem_pct}% | 根分区磁盘=${disk_pct}%"
(( ${#warns[@]} )) && slog "预警：$(IFS='; '; echo "${warns[*]}")"
slog "完成：系统监控采集"
