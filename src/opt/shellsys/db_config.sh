#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[FATAL] db_config.sh 发生错误（行号 $LINENO）" >&2; exit 4' ERR

usage(){ cat <<'USAGE'
用法：db_config.sh [--config=/path/to/config.ini]

交互式更新 /opt/shellsys/config.ini 中的数据库备份参数。
USAGE
}

CONF="/opt/shellsys/config.ini"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config=*)
      CONF="${1#*=}"
      shift
      ;;
    --config)
      shift
      CONF="${1:-}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERR] 未知参数：$1" >&2
      usage
      exit 2
      ;;
  esac
done

[[ -n "$CONF" ]] || { echo "[ERR] --config 需指定路径" >&2; exit 2; }
[[ -f "$CONF" ]] || { echo "[ERR] 缺少配置文件：$CONF" >&2; exit 1; }
[[ -t 0 && -t 1 ]] || { echo "[ERR] 需在交互式终端运行以配置数据库。" >&2; exit 3; }

source "$CONF" 2>/dev/null || true

KEYFILE="/etc/shellsys/.db_key"
if [[ ! -f "$KEYFILE" ]]; then
  install -d -m 755 "$(dirname "$KEYFILE")"
  openssl rand -hex 32 > "$KEYFILE"
  chmod 600 "$KEYFILE"
  chown root:root "$KEYFILE" 2>/dev/null || true
fi

ask(){ local p="$1" v; read -r -p "$p" v; printf '%s' "$v"; }
ask_secret(){ local p="$1" v; read -r -s -p "$p" v; echo; printf '%s' "$v"; }
save_cfg(){
  local key="$1" val="$2" file="$3"
  cp -a "$file" "${file}.bak.$(date +%s)" 2>/dev/null || true
  if grep -qE "^[[:space:]]*${key}=" "$file"; then
    sed -i -E "s|^[[:space:]]*${key}=.*|${key}=${val}|" "$file"
  else
    printf "\n# 自动更新：%s by db_config (%s)\n%s=%s\n" "$key" "$(date '+%F %T')" "$key" "$val" >> "$file"
  fi
}
enc_pass(){ printf '%s' "$1" | openssl enc -aes-256-cbc -a -pbkdf2 -salt -pass file:"$KEYFILE"; }

MYSQL_BIN="$(command -v mysql || true)"
MARIADB_BIN="$(command -v mariadb || true)"
DUMPCLI="$(command -v mysqldump || true)"
DBCLI="${MYSQL_BIN:-$MARIADB_BIN}"

if [[ -z "$DBCLI" || -z "$DUMPCLI" ]]; then
  cat <<'HINT'
[WARN] 未检测到 mysql/mariadb 客户端或 mysqldump，无法配置数据库备份。
请先安装相关客户端后再运行该脚本。
HINT
  exit 5
fi

DB_HOST="${DB_HOST:-localhost}"
DB_USER="${DB_USER:-root}"
DB_PASS=""

cat <<'MSG'
==================================================
ShellSys 数据库备份配置向导
==================================================
MSG

echo "[INFO] 请输入数据库连接信息（直接回车使用默认值）："
tmp="$(ask "DB Host [${DB_HOST}]: ")"; DB_HOST="${tmp:-$DB_HOST}"
tmp="$(ask "DB User [${DB_USER}]: ")"; DB_USER="${tmp:-$DB_USER}"
DB_PASS="$(ask_secret "DB Pass [不回显，可留空再输]: ")"

can_conn(){ local h="$1" u="$2" pw="$3"; local o=(); [[ -n "$pw" ]] && o=(-p"$pw"); "$DBCLI" -h "$h" -u "$u" "${o[@]}" -N -e "SELECT 1;" >/dev/null 2>&1; }
if ! can_conn "$DB_HOST" "$DB_USER" "$DB_PASS"; then
  echo "[WARN] 初次连接失败，可再输入一次密码。"
  DB_PASS="$(ask_secret "DB Pass(再次输入): ")"
fi
if ! can_conn "$DB_HOST" "$DB_USER" "$DB_PASS"; then
  echo "[ERR] 无法连接数据库，未写入配置。"
  exit 6
fi

list_dbs(){ local h="$1" u="$2" pw="$3"; local o=(); [[ -n "$pw" ]] && o=(-p"$pw"); "$DBCLI" -h "$h" -u "$u" "${o[@]}" -N -e "SHOW DATABASES;" 2>/dev/null | grep -Ev '^(information_schema|performance_schema|mysql|sys)$' || true; }
mapfile -t DBS < <(list_dbs "$DB_HOST" "$DB_USER" "$DB_PASS")
if ((${#DBS[@]}==0)); then
  echo "[ERR] 未列出可用数据库，未写入配置。"
  exit 7
fi

echo "可备份的数据库："
for i in "${!DBS[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${DBS[$i]}"; done
read -r -p "选择编号（逗号分隔）或 all（全选）： " choice

SELECTED=()
if [[ "$choice" == "all" ]]; then
  SELECTED=("${DBS[@]}")
else
  IFS=',' read -r -a idxs <<< "$choice"
  for x in "${idxs[@]}"; do
    x="$(echo "$x" | xargs)"
    [[ "$x" =~ ^[0-9]+$ ]] || continue
    (( x>=1 && x<=${#DBS[@]} )) && SELECTED+=("${DBS[$((x-1))]}")
  done
fi

if ((${#SELECTED[@]}==0)); then
  echo "[ERR] 未选择任何数据库，未写入配置。"
  exit 8
fi

CSV="$(IFS=','; echo "${SELECTED[*]}")"
ENC="$(enc_pass "$DB_PASS")"
save_cfg "DB_BACKUP"   "on"      "$CONF"
save_cfg "DB_HOST"     "$DB_HOST" "$CONF"
save_cfg "DB_USER"     "$DB_USER" "$CONF"
save_cfg "DB_NAME"     "$CSV"     "$CONF"
save_cfg "DB_PASS_ENC" "'$ENC'"   "$CONF"
if grep -qE '^[[:space:]]*DB_PASS=' "$CONF"; then
  sed -i -E "s|^[[:space:]]*DB_PASS=.*|DB_PASS=''|g" "$CONF"
fi

echo "[OK] 已更新数据库备份配置：$CONF"
echo "    DB_HOST=$DB_HOST"
echo "    DB_USER=$DB_USER"
echo "    DB_NAME=$CSV"
echo "    DB_PASS_ENC=<已加密>"
echo "密钥文件：$KEYFILE"

exit 0
