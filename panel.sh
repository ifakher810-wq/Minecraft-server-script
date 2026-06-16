#!/bin/bash

while true; do
clear

echo "========================"
echo " MINECRAFT VPS PANEL"
echo "========================"

echo "1) Create Server"
echo "2) Server List"
echo "3) Start Server"
echo "4) Stop Server"
echo "5) Restart Server"
echo "6) Install Plugin"
echo "7) Backup Server"
echo "8) Logs"
echo "9) Exit"

read -p "Choose: " opt

case $opt in
1) echo "Create Server logic here";;
2) ls mc-servers ;;
3) echo "Start server logic";;
4) pkill -f server.jar ;;
5) pkill -f server.jar && echo "Restarting...";;
6) echo "Plugin install logic";;
7) tar -czf backup.tar.gz mc-servers ;;
8) tail -f mc-servers/server1/logs/server.log ;;
9) exit ;;
esac

done
