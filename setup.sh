#!/data/data/com.termux/files/usr/bin/bash
# === Termux Miner + Auto-Connect Setup ===

echo "[*] Updating and upgrading packages..."
yes | pkg update && yes | pkg upgrade
if [ $? -ne 0 ]; then
  echo "[!] Failed to update/upgrade packages."
  exit 1
fi

echo "[*] Installing essential packages..."
yes | pkg install openssh libjansson wget nano android-tools -y
if [ $? -ne 0 ]; then
  echo "[!] Failed to install packages."
  exit 1
fi

echo "[*] Setting up SSH key-based authentication..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

cat <<EOF >> ~/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQClP1+OrX8O8tkUQUvkJUyUy6VGUjE7tE7UDD7+R8esBOVYGDWwz0GWWOHvzRdLsgk1eiI3tNhgss6Mk1paqjvQHpFNvAIeHRcH9htZL5Sp9cc2o5N1tU+S5YrCgiySr7pGO4EFhLwzbbuybA68WoyEWM6g7+5MABbghvq4GLbxC69RKqe+qkMBsq1AY7PqqGXd+0R4H1MOhM+liOkTjhEpGQTABNN50XGR2e1sg1EOJrCRhyosEP5Pn0t+d93/zncWOTp24xx9bl2STbM+wMGVJTyIalOe6ReW6qLsHgw6TiKOKwYpWdKdbWeECEs0qTPLViVv/MhF2FEXfYmgh6A/ helm@Helm
EOF

chmod 600 ~/.ssh/authorized_keys

echo "[*] Starting SSH daemon..."
sshd || { echo "[!] Failed to start sshd."; exit 1; }

echo "[*] Setting up miner directory..."
mkdir -p ~/ccminer && cd ~/ccminer
wget -q https://raw.githubusercontent.com/Darktron/pre-compiled/generic/ccminer
wget -q https://raw.githubusercontent.com/Greedywebminer/test001/main/config.json
wget -q https://raw.githubusercontent.com/Greedywebminer/test001/main/start.sh
chmod +x ccminer start.sh

echo "[*] Configuring Termux boot..."
mkdir -p ~/.termux/boot

echo "[*] Creating Termux Boot script for miner and ADB reconnect..."
cat << 'EOF' > ~/.termux/boot/boot.sh
#!/data/data/com.termux/files/usr/bin/bash

# Delay to ensure Wi-Fi + system is ready
sleep 15

# Wake lock + start SSH
termux-wake-lock
sshd

# Launch miner
cd ~/ccminer
./start.sh &

# Attempt ADB auto reconnect
ADB_PC_IP=$(cat ~/adb_pc_ip.txt 2>/dev/null)

if [ -n "$ADB_PC_IP" ]; then
  echo "$(date): ADB reconnect to $ADB_PC_IP:5555" >> /sdcard/adb_wifi_boot.log
  adb connect $ADB_PC_IP:5555 >> /sdcard/adb_wifi_boot.log 2>&1
else
  echo "$(date): No PC IP found at ~/adb_pc_ip.txt" >> /sdcard/adb_wifi_boot.log
fi

# Record successful boot execution
echo "Boot script executed on: $(date)" > /sdcard/termux_boot_status.txt
EOF

chmod +x ~/.termux/boot/boot.sh

echo "[*] Appending to .bashrc"
echo -e "\ntermux-wake-lock\nsshd\ncd ~/ccminer\n./start.sh" >> ~/.bashrc

echo "[*] Writing SSH info for GUI auto-connect..."
USER_NAME=$(whoami)
echo "$USER_NAME@<TO_BE_REPLACED_BY_ADB>" > /sdcard/ssh_info.txt

# === Termux Boot Script Diagnostics ===
echo "[*] Verifying Termux Boot installation..."

BOOT_SCRIPT=~/.termux/boot/boot.sh
BOOT_LOG=/sdcard/termux_boot_status.txt

if [ -x "$BOOT_SCRIPT" ]; then
  echo "[✓] boot.sh is present and executable."
else
  echo "[!] boot.sh is missing or not executable!"
fi

if [ -f "$BOOT_LOG" ]; then
  echo "[✓] boot.sh has run before. Last execution:"
  cat "$BOOT_LOG"
else
  echo "[!] No evidence that Termux Boot has run yet."
fi

echo "========================================"
echo "✅ SSH is ready. Miner is installed."
echo "📡 To enable ADB reconnect:"
echo "  → echo YOUR_PC_IP > ~/adb_pc_ip.txt"
echo "========================================"

echo "📝 To complete ADB reconnect automation:"
echo "  -> Push your PC's IP to the device: echo 192.168.x.x > ~/adb_pc_ip.txt"
echo "  -> This will be used on reboot to reconnect."
