#!/bin/bash

while true; do
clear

echo "=============================="
echo " UBUNTU TOOL v2 (NEW UPDATE)"
echo "=============================="

echo "1) Full System Update (Safe)"
echo "2) Clean System (Deep)"
echo "3) RAM / CPU Info"
echo "4) Disk Usage"
echo "5) Running Processes"
echo "6) Open Firewall Port"
echo "7) Internet Speed Test"
echo "8) Script Auto Update Check"
echo "9) System Uptime"
echo "10) Reboot VPS"
echo "11) Exit"
echo ""

read -p "Choose option: " opt

case $opt in

1)
echo "Updating system..."
sudo apt update -y && sudo apt upgrade -y
echo "System Updated ✔"
sleep 2
;;

2)
echo "Cleaning system..."
sudo apt autoremove -y
sudo apt autoclean -y
sudo apt clean
echo "Clean Done ✔"
sleep 2
;;

3)
echo "===== RAM ====="
free -h
echo ""
echo "===== CPU LOAD ====="
uptime
read -p "Enter..."
;;

4)
df -h
read -p "Enter..."
;;

5)
echo "Top Processes:"
ps aux --sort=-%cpu | head -10
read -p "Enter..."
;;

6)
read -p "Port: " port
sudo ufw allow $port
echo "Port Opened ✔"
sleep 2
;;

7)
echo "Installing speedtest..."
sudo apt install speedtest-cli -y > /dev/null 2>&1
echo "Running speed test..."
speedtest-cli
read -p "Enter..."
;;

8)
echo "Checking script update..."

SCRIPT_URL="https://raw.githubusercontent.com/USER/REPO/main/ubuntu-tool.sh"

LOCAL=$(md5sum "$0" | awk '{print $1}')
REMOTE=$(curl -s "$SCRIPT_URL" | md5sum | awk '{print $1}')

if [ "$LOCAL" == "$REMOTE" ]; then
    echo "You are using latest version ✔"
else
    echo "Update available ⚡"
    echo "Download new version from GitHub"
fi

read -p "Enter..."
;;

9)
uptime
read -p "Enter..."
;;

10)
reboot
;;

11)
exit 0
;;

*)
echo "Invalid option"
sleep 1
;;

esac

done
