#!/bin/bash

echo "Installing Minecraft VPS Panel..."

sudo apt update -y
sudo apt install git curl wget openjdk-17-jre -y

git clone https://github.com/YOUR-USERNAME/minecraft-vps-panel.git

cd minecraft-vps-panel
chmod +x panel.sh

echo "Setup Complete ✔"
echo "Run: ./panel.sh"
