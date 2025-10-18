#!/usr/bin/env bash
# setup.sh —— 环境部署 +（可选）数据库检测/选择 + 加密写入配置（移至安装阶段）
set -Eeuo pipefail
trap 'echo "[FATAL] setup.sh 发生错误（行号 $LINENO）" >&2; exit 4' ERR
[[ $EUID -eq 0 ]] || { echo "[ERR] 请使用 root 执行：sudo bash scripts/setup.sh"; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OPT_DIR="/opt/shellsys"
ETC_DIR="/etc/shellsys"
LOG_DIR="/var/log/shellsys"
BK_DIR="/opt/backup"
STATE_DIR="/var/lib/shellsys"

install -d "$OPT_DIR" "$ETC_DIR" "$LOG_DIR" "$BK_DIR" "$STATE_DIR"

# 复制程序文件（不更改你的其它模块功能）
shopt -s nullglob
sh_files=("$REPO_ROOT/src/opt/shellsys/"*.sh)
((${#sh_files[@]})) && install -m 755 "${sh_files[@]}" "$OPT_DIR" || true
# 复制样例配置/素材
etc_files=("$REPO_ROOT/src/etc/shellsys/"*)
((${#etc_files[@]})) && install -m 644 "${etc_files[@]}" "$ETC_DIR" || true
[[ -f "$REPO_ROOT/src/opt/shellsys/config.ini" ]] && install -m 644 "$REPO_ROOT/src/opt/shellsys/config.ini" "$OPT_DIR/config.ini" || true

chmod +x "$OPT_DIR"/*.sh || true
touch "$STATE_DIR/installed.ok"

# 安装依赖（Rocky）
if command -v dnf >/dev/null 2>&1; then
  dnf -y install cronie cronie-anacron openssl >/dev/null 2>&1 || true
  systemctl enable --now crond >/dev/null 2>&1 || true
fi

CONF="$OPT_DIR/config.ini"
[[ -f "$CONF" ]] || { echo "LOG_DIR=/var/log/shellsys" > "$CONF"; chmod 644 "$CONF"; }

# 初始化本机加密密钥（用于加密 DB 密码，避免明文进入 config.ini）
KEYFILE="$ETC_DIR/.db_key"
if [[ ! -f "$KEYFILE" ]]; then
  install -d -m 755 "$ETC_DIR"
  openssl rand -hex 32 > "$KEYFILE"
  chmod 600 "$KEYFILE"
  chown root:root "$KEYFILE"
fi

# ---------- 函数 ----------
ask(){ local p="$1" v; read -r -p "$p" v; printf '%s' "$v"; }
ask_secret(){ local p="$1" v; read -r -s -p "$p" v; echo; printf '%s' "$v"; }
save_cfg(){
  local key="$1" val="$2" file="$3"
  cp -a "$file" "${file}.bak.$(date +%s)" 2>/dev/null || true
  if grep -qE "^[[:space:]]*${key}=" "$file"; then
    sed -i -E "s|^[[:space:]]*${key}=.*|${key}=${val}|" "$file"
  else
    printf "\n# 自动更新：%s by setup (%s)\n%s=%s\n" "$key" "$(date '+%F %T')" "$key" "$val" >> "$file"
  fi
}
enc_pass(){ printf '%s' "$1" | openssl enc -aes-256-cbc -a -pbkdf2 -salt -pass file:"$KEYFILE"; }

# ---------- 安装提示 ----------
cat <<'MSG'

==================================================
ShellSys 安装就绪（仅准备环境，不改 Cron）
==================================================
主入口：/opt/shellsys/main.sh
帮助：  /opt/shellsys/main.sh -h

可选下一步：立即配置“数据库备份”参数（检测数据库 → 选择库 → 写入 /opt/shellsys/config.ini，密码加密保存）。
MSG

# ---------- 可选：数据库检测 / 选择 / 落盘 ----------
read -r -p "是否现在配置数据库备份参数？(yes/no): " A
if [[ "${A,,}" =~ ^y ]]; then
  MYSQL_BIN="$(command -v mysql || true)"
  MARIADB_BIN="$(command -v mariadb || true)"
  DUMPCLI="$(command -v mysqldump || true)"
  DBCLI="${MYSQL_BIN:-$MARIADB_BIN}"

  if [[ -z "$DBCLI" || -z "$DUMPCLI" ]]; then
    cat <<'HINT'
[WARN] 未检测到 mysql/mariadb 客户端或 mysqldump。
Rocky（推荐）客户端安装：
  sudo dnf install -y mariadb
（可选）安装 MySQL 官方社区版：
  sudo dnf install -y https://repo.mysql.com/mysql80-community-release-el9-1.noarch.rpm
  sudo dnf install -y mysql mysql-community-server && sudo systemctl enable --now mysqld
安装后可再次执行：bash scripts/setup.sh 进行数据库配置。
HINT
    exit 0
  fi

  DB_HOST="${DB_HOST:-localhost}"
  DB_USER="${DB_USER:-root}"
  DB_PASS=""

  echo "[INFO] 请输入数据库连接信息（直接回车使用默认）："
  tmp="$(ask "DB Host [${DB_HOST}]: ")"; DB_HOST="${tmp:-$DB_HOST}"
  tmp="$(ask "DB User [${DB_USER}]: ")"; DB_USER="${tmp:-$DB_USER}"
  DB_PASS="$(ask_secret "DB Pass [不回显，可留空后再输]: " )"

  can_conn(){ local h="$1" u="$2" pw="$3"; local o=(); [[ -n "$pw" ]] && o=(-p"$pw"); "$DBCLI" -h "$h" -u "$u" "${o[@]}" -N -e "SELECT 1;" >/dev/null 2>&1; }
  if ! can_conn "$DB_HOST" "$DB_USER" "$DB_PASS"; then
    echo "[WARN] 连接失败，可再输入一次密码。"
    DB_PASS="$(ask_secret "DB Pass(再次输入): ")"
  fi
  if ! can_conn "$DB_HOST" "$DB_USER" "$DB_PASS"; then
    echo "[ERR] 仍无法连接数据库，已跳过数据库备份配置。"
    exit 0
  fi

  list_dbs(){ local h="$1" u="$2" pw="$3"; local o=(); [[ -n "$pw" ]] && o=(-p"$pw"); "$DBCLI" -h "$h" -u "$u" "${o[@]}" -N -e "SHOW DATABASES;" 2>/dev/null | grep -Ev '^(information_schema|performance_schema|mysql|sys)$' || true; }
  mapfile -t DBS < <(list_dbs "$DB_HOST" "$DB_USER" "$DB_PASS")
  if ((${#DBS[@]}==0)); then
    echo "[WARN] 未列出可用数据库（权限不足或无业务库），已跳过数据库备份配置。"
    exit 0
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
    echo "[WARN] 未选择任何库，已跳过数据库备份配置。"
    exit 0
  fi

  CSV="$(IFS=','; echo "${SELECTED[*]}")"
  ENC="$(enc_pass "$DB_PASS")"
  save_cfg "DB_BACKUP"   "on"      "$CONF"
  save_cfg "DB_HOST"     "$DB_HOST" "$CONF"
  save_cfg "DB_USER"     "$DB_USER" "$CONF"
  save_cfg "DB_NAME"     "$CSV"     "$CONF"
  save_cfg "DB_PASS_ENC" "'$ENC'"   "$CONF"
  # 兼容：清空历史明文 DB_PASS
  if grep -qE '^[[:space:]]*DB_PASS=' "$CONF"; then
    sed -i -E "s|^[[:space:]]*DB_PASS=.*|DB_PASS=''|g" "$CONF"
  fi

  cat <<EOF

[OK] 数据库备份配置已写入：$CONF
    DB_HOST=$DB_HOST
    DB_USER=$DB_USER
    DB_NAME=$CSV
    DB_PASS_ENC=<已加密>
密钥文件：$KEYFILE（600）
后续运行 main.sh / cron 将按该配置执行，无需再次交互。

EOF
fi

echo "[+] 部署完成。常用命令："
echo "   全量执行： sudo /opt/shellsys/main.sh --all"
echo "   单模块：   sudo /opt/shellsys/main.sh --task sys_monitor"
echo "   定时任务： sudo /opt/shellsys/main.sh --cron-mode demo|normal|status|disable"
