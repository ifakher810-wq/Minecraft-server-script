#!/bin/bash

while true; do
    echo "----------------------------------------"
    echo "       VPS MANAGER - BY NICEGAMER         "
    echo "----------------------------------------"
    echo "1) Create-VPS"
    echo "2) Exit"
    echo "3) Stop-VPS"
    echo "4) Start-VPS"
    echo "----------------------------------------"
    read -p "Select an option [1-4]: " choice

    case $choice in
        1)
            read -p "Enter container name: " vps_name
            read -p "Enter CPU cores (e.g., 1): " cpu_limit
            read -p "Enter RAM (e.g., 512MB or 1GB): " ram_limit
            read -p "Enter Disk size (e.g., 5GB): " disk_size

            echo "[*] Creating VPS..."
            lxc launch ubuntu:22.04 "$vps_name"
            
            echo "[*] Applying hardware limits..."
            lxc config set "$vps_name" limits.cpu "$cpu_limit"
            lxc config set "$vps_name" limits.memory "$ram_limit"
            lxc config device override "$vps_name" root size="$disk_size"

            echo "[*] Updating and upgrading the VPS..."
            lxc exec "$vps_name" -- apt update && lxc exec "$vps_name" -- apt upgrade -y
            
            echo "SUCCESS: VPS '$vps_name' is ready with $cpu_limit CPU, $ram_limit RAM, and $disk_size disk."
            ;;
        2)
            echo "Exiting..."
            exit 0
            ;;
        3)
            read -p "Enter container name to stop: " vps_name
            lxc stop "$vps_name"
            echo "VPS '$vps_name' stopped."
            ;;
        4)
            read -p "Enter container name to start: " vps_name
            lxc start "$vps_name"
            echo "VPS '$vps_name' started."
            ;;
        *)
            echo "Invalid option, please try again."
            ;;
    esac
done
