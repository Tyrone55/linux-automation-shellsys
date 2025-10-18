#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] user_mgr.sh 发生错误（行号 $LINENO）" >&2; exit 4' ERR

CONF="/opt/shellsys/config.ini"; [[ -f "$CONF" ]] && source "$CONF" || { echo "[ERR] 缺少配置文件：$CONF"; exit 1; }
MODULE="user_mgr"; TODAY="$(date +%F)"; LOG_DIR="${LOG_DIR:-/var/log/shellsys}"; mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/user_mgr_$TODAY.log"; SEQ=0
slog(){ SEQ=$((SEQ+1)); printf '%s [user_mgr #%03d] ExecID=%s | %s\n' "$(date '+%F %T')" "$SEQ" "${EXEC_ID:-NA}" "$*" | tee -a "$LOG_FILE"; echo >> "$LOG_FILE"; }

slog "开始：用户管理任务 | 任务源=${USER_TASKS:-/etc/shellsys/user_tasks.csv} / ${USER_LIST:-/etc/shellsys/user_list.txt}"

if [[ -f "${USER_TASKS:-/etc/shellsys/user_tasks.csv}" ]]; then
  tail -n +2 "${USER_TASKS:-/etc/shellsys/user_tasks.csv}" | while IFS=, read -r ACTION USER PASS GROUPS SUDOFLAG; do
    [[ -z "$ACTION" || "$ACTION" =~ ^# ]] && continue
    case "$ACTION" in
      create)
        if id "$USER" >/dev/null 2>&1; then
          slog "已存在：$USER"
        else
          useradd -m "$USER" && slog "已创建：$USER" || slog "创建失败：$USER"
          [[ -n "$PASS" ]]    && echo "$USER:$PASS" | chpasswd && slog "已设密：$USER"
          [[ -n "$GROUPS" ]]  && usermod -aG "$GROUPS" "$USER" && slog "加组：$USER->$GROUPS"
          [[ "$SUDOFLAG" == "wheel" ]] && usermod -aG wheel "$USER" && slog "授予 wheel：$USER"
        fi
        ;;
      delete)
        if id "$USER" >/dev/null 2>&1; then
          userdel -r "$USER" && slog "已删除：$USER" || slog "删除失败：$USER"
        else
          slog "不存在：$USER"
        fi
        ;;
      passwd)
        if id "$USER" >/dev/null 2>&1; then
          echo "$USER:${PASS:-}" | chpasswd && slog "改密：$USER"
        else
          slog "不存在：$USER（改密失败）"
        fi
        ;;
      mod)
        if id "$USER" >/dev/null 2>&1; then
          [[ -n "$PASS" ]]   && { echo "$USER:$PASS" | chpasswd && slog "改密：$USER"; }
          [[ -n "$GROUPS" ]] && { usermod -aG "$GROUPS" "$USER" && slog "加组：$USER->$GROUPS"; }
          slog "已修改：$USER"
        else
          slog "不存在：$USER（无法修改）"
        fi
        ;;
      addgroup)
        if id "$USER" >/dev/null 2>&1; then
          usermod -aG "$GROUPS" "$USER" && slog "加组：$USER->$GROUPS"
        else
          slog "不存在：$USER"
        fi
        ;;
      delgroup)
        if id "$USER" >/dev/null 2>&1; then
          gpasswd -d "$USER" "$GROUPS" && slog "移组：$USER -X-> $GROUPS"
        else
          slog "不存在：$USER"
        fi
        ;;
      *)
        slog "未知动作：$ACTION"
        ;;
    esac
  done
elif [[ -f "${USER_LIST:-/etc/shellsys/user_list.txt}" ]]; then
  while IFS= read -r u; do
    [[ -z "$u" || "$u" =~ ^# ]] && continue
    if id "$u" >/dev/null 2>&1; then
      slog "已存在：$u"
    else
      useradd -m "$u" && slog "已创建：$u" || slog "创建失败：$u"
    fi
  done < "${USER_LIST:-/etc/shellsys/user_list.txt}"
else
  slog "未发现用户任务定义（CSV/LIST）"
fi

slog "完成：用户管理任务"
