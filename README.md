# ShellSys — 集成版（数据库选择前移到 setup）

## 目录结构
- `scripts/setup.sh`：部署环境 +（可选）数据库检测/多选库/加密写入 `/opt/shellsys/config.ini`
- `src/opt/shellsys/`：主控与各模块（不改原功能，仅移除运行期的 DB 交互）
  - `main.sh`、`backup_restore.sh`、`sys_monitor.sh`、`user_mgr.sh`、`secure_ctrl.sh`、`log_manager.sh`、`cron_mode.sh`
  - `config.ini`（示例）
- `src/etc/shellsys/`：示例数据与策略（可按需修改）

## 快速开始
```bash
# 1) 安装（会拷贝到 /opt/shellsys；不改 cron）
sudo bash scripts/setup.sh

# 2) 可选：在 setup 中选择 yes，检测数据库→多选库→写入 /opt/shellsys/config.ini（密码加密）

# 3) 运行（零交互）
sudo /opt/shellsys/main.sh --all
sudo /opt/shellsys/main.sh --task backup_restore

# 4) 定时任务
sudo /opt/shellsys/main.sh --cron-mode demo     # 每2分钟
sudo /opt/shellsys/main.sh --cron-mode normal   # 每天02:00
sudo /opt/shellsys/main.sh --cron-mode status|disable
```

## 日志位置
- 主控：`/var/log/shellsys/main_YYYY-MM-DD.log`
- 模块：`/var/log/shellsys/<模块>_YYYY-MM-DD.log`
- 汇总：`/var/log/shellsys/report_YYYY-MM-DD.log`

> 说明：本集成包**仅**实现你要求的变更：把数据库检测/选择移至 `setup.sh`；`main.sh` 与 `backup_restore.sh` 运行期不再进行数据库交互，完全按 `config.ini` 执行。其余模块、目录与行为保持不变。
