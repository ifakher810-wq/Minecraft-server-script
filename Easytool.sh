#!/bin/bash

while true; do
clear

echo "=========================="
echo " UBUNTU PRO TOOL"
echo "=========================="

echo "1) Update System (Auto)"
echo "2) Clean System"
echo "3) RAM Info"
echo "4) CPU Info"
echo "5) Disk Info"
echo "6) Open Port (Firewall)"
echo "7) Internet Speed Test"
echo "8) Auto Script Update Check"
echo "9) Reboot VPS"
echo "10) Exit"
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
sudo apt autoremove -y && sudo apt clean
echo "Clean Done ✔"
sleep 2
;;

3)
free -h
read -p "Press Enter..."
;;

4)
uptime
read -p "Press Enter..."
;;

5)
df -h
read -p "Press Enter..."
;;

6)
read -p "Port: " port
sudo ufw allow $port
echo "Port Opened ✔"
sleep 2
;;

7)
echo "Testing Internet Speed..."
sudo apt install speedtest-cli -y > /dev/null 2>&1
speedtest-cli
read -p "Press Enter..."
;;

8)
echo "Checking updates for script..."

SCRIPT_URL="https://raw.githubusercontent.com/USER/REPO/main/ubuntu-tool.sh"

LOCAL_HASH=$(md5sum "$0" | awk '{print $1}')
REMOTE_HASH=$(curl -s "$SCRIPT_URL" | md5sum | awk '{print $1}')

if [ "$LOCAL_HASH" == "$REMOTE_HASH" ]; then
    echo "Script is up to date ✔"
else
    echo "Update available ⚡"
    echo "Run: curl -O $SCRIPT_URL"
fi

read -p "Press Enter..."
;;

9)
reboot
;;

10)
exit 0
;;

*)
echo "Invalid option"
sleep 1
;;

esac

done
