#!/data/data/com.termux/files/usr/bin/bash

LOG_FILE="/sdcard/adb_wifi_boot.log"
BOOT_STATUS="/sdcard/termux_boot_status.txt"

# ✅ Load PC user and IP (with fallback)
ADB_PC_USER=$(cat ~/adb_pc_user.txt 2>/dev/null)
ADB_PC_IP=$(cat ~/adb_pc_ip.txt 2>/dev/null)
[ -z "$ADB_PC_IP" ] && ADB_PC_IP="192.168.202.1"

echo "$(date): Boot script started" >> "$LOG_FILE"

# Wait for wlan0 to get IP
for i in {1..15}; do
  if ip a | grep -q 'wlan0.*inet '; then
    echo "$(date): Wi-Fi is up." >> "$LOG_FILE"
    break
  fi
  sleep 1
done

# Start wake lock + SSH
termux-wake-lock
sshd
echo "$(date): SSH started." >> "$LOG_FILE"

# Launch miner
cd ~/ccminer
./start.sh &
echo "$(date): Miner launched." >> "$LOG_FILE"

# ADB reconnect via SSH to PC
if [ -n "$ADB_PC_USER" ]; then
  echo "$(date): Trying SSH to $ADB_PC_USER@$ADB_PC_IP to run 'adb tcpip 5555'" >> "$LOG_FILE"

  success=false
  for i in 1 2 3; do
    if ping -c 1 "$ADB_PC_IP" > /dev/null 2>&1; then
      ssh -o ConnectTimeout=5 "$ADB_PC_USER@$ADB_PC_IP" 'adb tcpip 5555' >> "$LOG_FILE" 2>&1
      if [ $? -eq 0 ]; then
        sleep 3
        adb connect "$ADB_PC_IP:5555" >> "$LOG_FILE" 2>&1
        if adb devices | grep -q "$ADB_PC_IP"; then
          echo "$(date): ✅ ADB reconnect succeeded." >> "$LOG_FILE"
          success=true
          break
        fi
      fi
    else
      echo "$(date): Ping failed to $ADB_PC_IP (attempt #$i)" >> "$LOG_FILE"
    fi
    sleep 5
  done

  if [ "$success" != true ]; then
    echo "$(date): ❗ All ADB reconnect attempts failed." >> "$LOG_FILE"
  fi
else
  echo "$(date): ⚠️ Missing ~/adb_pc_user.txt. Skipping SSH reconnect." >> "$LOG_FILE"
fi

# ✅ Write actual SSH info for dashboard (fixed)
SSH_USER=$(whoami)
WIFI_IP=$(ip route get 1 | awk '{print $7; exit}')
if [ -n "$WIFI_IP" ]; then
  echo "$SSH_USER@$WIFI_IP" > /sdcard/ssh_info.txt
  echo "$WIFI_IP" > /sdcard/ip.txt
  echo "$(date): 🧾 Wrote SSH info: $SSH_USER@$WIFI_IP and IP to /sdcard/ip.txt" >> "$LOG_FILE"
else
  echo "$(date): ❌ Failed to detect IP. SSH info not written." >> "$LOG_FILE"
fi

# Mark boot completed
echo "Boot script executed on: $(date)" > "$BOOT_STATUS"
echo "$(date): ✅ Boot script finished" >> "$LOG_FILE"
