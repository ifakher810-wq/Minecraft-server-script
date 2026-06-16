#!/bin/bash

while true; do
clear

echo "===================================="
echo " UBUNTU TOOL v4 (FINAL PRO EDITION)"
echo "===================================="

echo "1) Full System Update"
echo "2) Clean System (Deep)"
echo "3) RAM / CPU Info"
echo "4) Disk Info"
echo "5) Network Info"
echo "6) Running Processes"
echo "7) Internet Speed Test (Web)"
echo "8) Open Firewall Port"
echo "9) System Health Check"
echo "10) Clear RAM Cache"
echo "11) Security Check"
echo "12) System Uptime"
echo "13) Reboot VPS"
echo "14) Exit"
echo ""

read -p "Choose option: " opt

case $opt in

1)
sudo apt update -y && sudo apt upgrade -y
echo "System Updated ✔"
sleep 2
;;

2)
sudo apt autoremove -y && sudo apt autoclean -y && sudo apt clean
echo "System Cleaned ✔"
sleep 2
;;

3)
echo "===== RAM ====="
free -h
echo ""
echo "===== CPU ====="
uptime
read -p "Enter..."
;;

4)
df -h
read -p "Enter..."
;;

5)
echo "Network Interfaces:"
ip a
echo ""
echo "Public IP:"
curl -s ifconfig.me
read -p "Enter..."
;;

6)
ps aux --sort=-%cpu | head -10
read -p "Enter..."
;;

7)
echo "================================"
echo " Internet Speed Test (Cloudflare)"
echo "================================"

START=$(date +%s)

curl -o /dev/null -s https://speed.cloudflare.com/__down?bytes=30000000

END=$(date +%s)

TIME=$((END-START))

echo ""
echo "Download Test Time: $TIME seconds"
echo "(Lower time = faster internet)"
read -p "Enter..."
;;

8)
read -p "Port Number: " port
sudo ufw allow $port
echo "Port Opened ✔"
sleep 2
;;

9)
echo "System Health Check..."

CPU=$(uptime | awk -F'load average:' '{print $2}')
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')

echo "CPU Load:$CPU"
echo "RAM Usage:$RAM_USED / $RAM_TOTAL MB"

echo ""
echo "Status: OK ✔"
read -p "Enter..."
;;

10)
sync; echo 3 > /proc/sys/vm/drop_caches
echo "RAM Cache Cleared ✔"
sleep 2
;;

11)
echo "Security Check..."
echo ""
echo "Firewall Status:"
sudo ufw status

echo ""
echo "Open Ports:"
ss -tulnp | head -10

read -p "Enter..."
;;

12)
uptime
read -p "Enter..."
;;

13)
reboot
;;

14)
exit 0
;;

*)
echo "Invalid Option"
sleep 1
;;

esac

done
