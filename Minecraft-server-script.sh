#!/bin/bash

BASE="$HOME/CraftPanel"
mkdir -p "$BASE/servers"

PAPER_URL="https://api.papermc.io/v2/projects/paper/versions/1.21.1/builds/50/downloads/paper-1.21.1-50.jar"

# =========================
# SERVER STATUS CHECK
# =========================
server_status() {
    if pgrep -f server.jar > /dev/null; then
        echo "ONLINE ✔"
    else
        echo "OFFLINE ❌"
    fi
}

# =========================
# MAIN LOOP
# =========================
while true; do
clear

echo "======================================"
echo " 🧱 CraftPanel v2 - LEVEL 2 SYSTEM"
echo "======================================"

echo "Server Status: $(server_status)"
echo ""

echo "1) Create New Server"
echo "2) Start Server"
echo "3) Stop Server"
echo "4) Server List"
echo "5) Server Info"
echo "6) Show Public IP"
echo "7) Install Plugin (URL)"
echo "8) Backup Server"
echo "9) Restore Backup"
echo "10) View Logs"
echo "11) Auto Recovery Toggle"
echo "12) Exit"
echo "======================================"

read -p "Choose option: " opt

case $opt in

# =========================
# CREATE SERVER
# =========================
1)
read -p "Server Name: " name
read -p "RAM (MB): " ram

mkdir -p "$BASE/servers/$name"
cd "$BASE/servers/$name"

echo "Installing Java..."
sudo apt update -y > /dev/null 2>&1
sudo apt install openjdk-17-jre wget curl -y > /dev/null 2>&1

echo "Downloading PaperMC..."
wget -q -O server.jar "$PAPER_URL"

echo "eula=true" > eula.txt

cat > start.sh <<EOF
#!/bin/bash
while true; do
java -Xms${ram}M -Xmx${ram}M -jar server.jar nogui
echo "Server crashed → restarting..."
sleep 5
done
EOF

chmod +x start.sh

mkdir -p plugins logs backups

echo "Server Created ✔"
sleep 2
;;

# =========================
# START SERVER
# =========================
2)
read -p "Server Name: " name
cd "$BASE/servers/$name"

nohup ./start.sh > logs/server.log 2>&1 &

IP=$(curl -s ifconfig.me)

echo ""
echo "Server Started ✔"
echo "IP: $IP:25565"
sleep 2
;;

# =========================
# STOP SERVER
# =========================
3)
pkill -f server.jar
echo "Server Stopped ✔"
sleep 2
;;

# =========================
# LIST SERVERS
# =========================
4)
ls "$BASE/servers"
read -p "Enter..."
;;

# =========================
# SERVER INFO
# =========================
5)
free -h
uptime
df -h
read -p "Enter..."
;;

# =========================
# IP SHOW
# =========================
6)
IP=$(curl -s ifconfig.me)
echo "Server IP: $IP:25565"
read -p "Enter..."
;;

# =========================
# PLUGIN INSTALL
# =========================
7)
read -p "Server Name: " name
read -p "Plugin URL: " url

cd "$BASE/servers/$name/plugins"

wget -O plugin.jar "$url"

echo "Plugin Installed ✔"
sleep 2
;;

# =========================
# BACKUP
# =========================
8)
read -p "Server Name: " name
cd "$BASE/servers/$name"

tar -czf backups/backup_$(date +%s).tar.gz world plugins server.jar 2>/dev/null

echo "Backup Created ✔"
sleep 2
;;

# =========================
# RESTORE
# =========================
9)
read -p "Server Name: " name
cd "$BASE/servers/$name/backups"

ls
read -p "Backup file name: " file

tar -xzf "$file" -C ../

echo "Backup Restored ✔"
sleep 2
;;

# =========================
# LOGS
# =========================
10)
read -p "Server Name: " name
tail -f "$BASE/servers/$name/logs/server.log"
;;

# =========================
# AUTO RECOVERY
# =========================
11)
echo "Auto Recovery Enabled ✔"
echo "If server crashes → auto restart"
sleep 2
;;

# =========================
# EXIT
# =========================
12)
exit 0
;;

*)
echo "Invalid Option"
sleep 1
;;

esac

done
