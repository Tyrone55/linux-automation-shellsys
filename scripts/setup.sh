#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../src"
sudo mkdir -p /opt/shellsys /etc/shellsys /var/log/shellsys /opt/backup
sudo cp -r opt/shellsys/* /opt/shellsys/
sudo cp -r etc/shellsys/* /etc/shellsys/
sudo chmod +x /opt/shellsys/*.sh
echo "[+] Installed. Try: sudo /opt/shellsys/main.sh --auto"
