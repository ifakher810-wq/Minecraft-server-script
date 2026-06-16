#!/usr/bin/env bash

BASE="$HOME/mc-servers"
mkdir -p "$BASE"

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

PAPER_URL="https://api.papermc.io/v2/projects/paper/versions/1.20.4/builds/497/downloads/paper-1.20.4-497.jar"
VANILLA_URL="https://launcher.mojang.com/v1/objects/server.jar"

while true; do
clear

RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}')

echo "=================================="
echo " MINECRAFT VPS PANEL (ALL IN ONE)"
echo "=================================="
echo "RAM: $RAM_USED MB / $RAM_TOTAL MB"
echo "CPU:$CPU_LOAD"
echo "=================================="

echo "1) Create Server"
echo "2) Server List"
echo "3) Start Server"
echo "4) Stop Server"
echo "5) Restart Server"
echo "6) Install Plugin (URL)"
echo "7) Plugin Store"
echo "8) Backup Server"
echo "9) Server Settings"
echo "10) View Logs"
echo "11) Exit"
echo ""

read -p "Choose option: " opt

case $opt in

1)
read -p "Server Name: " name
read -p "RAM (MB): " ram
echo "1) PaperMC  2) Vanilla"
read -p "Type: " type

mkdir -p "$BASE/$name"
cd "$BASE/$name"

sudo apt update -y > /dev/null 2>&1
sudo apt install openjdk-17-jre wget curl -y > /dev/null 2>&1

echo "Downloading server..."

if [ "$type" == "1" ]; then
wget -q -O server.jar "$PAPER_URL"
else
wget -q -O server.jar "$VANILLA_URL"
fi

echo "eula=true" > eula.txt

cat > start.sh <<EOF
#!/bin/bash
while true; do
java -Xms${ram}M -Xmx${ram}M -jar server.jar nogui
echo "Server crashed... restarting in 5s"
sleep 5
done
EOF

chmod +x start.sh
mkdir -p plugins logs backups

echo -e "${GREEN}Server Created ✔${RESET}"
sleep 2
;;

2)
echo "Servers:"
ls "$BASE"
read -p "Press enter..."
;;

3)
read -p "Server Name: " name
cd "$BASE/$name"
nohup ./start.sh > logs/server.log 2>&1 &
echo -e "${GREEN}Server Started ✔${RESET}"
sleep 2
;;

4)
pkill -f server.jar
echo -e "${RED}Server Stopped ✔${RESET}"
sleep 2
;;

5)
pkill -f server.jar
sleep 2
read -p "Server Name: " name
cd "$BASE/$name"
nohup ./start.sh > logs/server.log 2>&1 &
echo -e "${GREEN}Restarted ✔${RESET}"
sleep 2
;;

6)
read -p "Server Name: " name
cd "$BASE/$name/plugins"
read -p "Plugin URL: " url
curl -L -o $(basename "$url") "$url"
echo -e "${GREEN}Plugin Installed ✔${RESET}"
sleep 2
;;

7)
read -p "Server Name: " name
cd "$BASE/$name/plugins"

echo "1) EssentialsX"
echo "2) LuckPerms"
echo "3) WorldEdit"
echo "4) ClearLag"

read -p "Choose: " p

if [ "$p" == "1" ]; then
wget -O EssentialsX.jar https://github.com/EssentialsX/Essentials/releases/latest/download/EssentialsX.jar
elif [ "$p" == "2" ]; then
wget -O LuckPerms.jar https://download.luckperms.net/LuckPerms.jar
elif [ "$p" == "3" ]; then
wget -O WorldEdit.jar https://dev.bukkit.org/projects/worldedit/files/latest/download
elif [ "$p" == "4" ]; then
wget -O ClearLag.jar https://dev.bukkit.org/projects/clearlagg/files/latest/download
fi

echo "Plugin Added ✔"
sleep 2
;;

8)
read -p "Server Name: " name
cd "$BASE/$name"
tar -czf backups/backup-$(date +%s).tar.gz world plugins server.jar
echo -e "${GREEN}Backup Done ✔${RESET}"
sleep 2
;;

9)
read -p "Server Name: " name
nano "$BASE/$name/server.properties"
;;

10)
read -p "Server Name: " name
tail -f "$BASE/$name/logs/server.log"
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
