#!/usr/bin/env bash

BASE="$HOME/mc-servers"
mkdir -p "$BASE"

PAPER_URL="https://api.papermc.io/v2/projects/paper/versions/1.20.4/builds/497/downloads/paper-1.20.4-497.jar"
VANILLA_URL="https://launcher.mojang.com/v1/objects/server.jar"

# =========================
# CREATE SERVER (FULL AUTO)
# =========================
create_server() {
    read -p "Server Name: " name
    read -p "RAM (MB): " ram

    echo "1) PaperMC"
    echo "2) Vanilla"
    read -p "Choose Type: " type

    mkdir -p "$BASE/$name"
    cd "$BASE/$name"

    echo "Starting FULL AUTO installation in background..."

    (
        sudo apt update -y > /dev/null 2>&1
        sudo apt install openjdk-17-jre wget curl -y > /dev/null 2>&1

        if [ "$type" == "1" ]; then
            wget -q -O server.jar "$PAPER_URL"
        else
            wget -q -O server.jar "$VANILLA_URL"
        fi

        echo "eula=true" > eula.txt

        mkdir -p plugins logs backups

        cat > start.sh <<EOF
#!/bin/bash
while true; do
java -Xms${ram}M -Xmx${ram}M -jar server.jar nogui
echo "Server crashed... restarting"
sleep 5
done
EOF

        chmod +x start.sh

    ) &

    echo ""
    echo "=============================="
    echo " INSTALLATION RUNNING IN BACKGROUND ✔"
    echo " PLEASE WAIT 1-2 MINUTES"
    echo "=============================="
}

# =========================
# LIST SERVER
# =========================
list_servers() {
    echo "Servers:"
    ls "$BASE"
}

# =========================
# START SERVER + AUTO IP
# =========================
start_server() {
    read -p "Server Name: " name
    cd "$BASE/$name"

    nohup ./start.sh > logs/server.log 2>&1 &

    IP=$(curl -s ifconfig.me)

    echo ""
    echo "=========================="
    echo " SERVER STARTED ✔"
    echo " IP: $IP:25565"
    echo "=========================="
}

# =========================
# STOP SERVER
# =========================
stop_server() {
    pkill -f server.jar
    echo "Server Stopped ✔"
}

# =========================
# RESTART SERVER
# =========================
restart_server() {
    pkill -f server.jar
    sleep 2
    echo "Restarting..."
}

# =========================
# PLUGIN INSTALL
# =========================
install_plugin() {
    read -p "Server Name: " name
    cd "$BASE/$name/plugins"

    read -p "Plugin URL: " url
    curl -L -o $(basename "$url") "$url"

    echo "Plugin Installed ✔"
}

# =========================
# BACKUP
# =========================
backup_server() {
    read -p "Server Name: " name
    cd "$BASE/$name"

    tar -czf backups/backup-$(date +%s).tar.gz world plugins server.jar

    echo "Backup Created ✔"
}

# =========================
# SERVER INFO
# =========================
server_info() {
    echo "RAM:"
    free -m | awk '/Mem:/ {print $3 "/" $2 " MB"}'

    echo "CPU:"
    uptime | awk -F'load average:' '{print $2}'
}

# =========================
# LOGS
# =========================
view_logs() {
    read -p "Server Name: " name
    tail -f "$BASE/$name/logs/server.log"
}

# =========================
# MENU
# =========================
while true; do
    clear

    echo "=================================="
    echo " MINECRAFT VPS PANEL (AUTO PRO)"
    echo "=================================="

    server_info

    echo ""
    echo "1) Create Server (AUTO)"
    echo "2) Server List"
    echo "3) Start Server"
    echo "4) Stop Server"
    echo "5) Restart Server"
    echo "6) Install Plugin"
    echo "7) Backup Server"
    echo "8) Logs"
    echo "9) Exit"
    echo ""

    read -p "Choose: " opt

    case $opt in
        1) create_server ;;
        2) list_servers ;;
        3) start_server ;;
        4) stop_server ;;
        5) restart_server ;;
        6) install_plugin ;;
        7) backup_server ;;
        8) view_logs ;;
        9) exit 0 ;;
        *) echo "Invalid"; sleep 1 ;;
    esac
done
