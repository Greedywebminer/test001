#!/data/data/com.termux/files/usr/bin/bash

config_file="$HOME/ccminer/config.json"
tmp_config="$HOME/ccminer/config_new.json"
pool_status_file="/sdcard/pool_status.txt"
log_file="/sdcard/pool_debug.log"
restart_required=false

# 🔧 Read pool name from pushed file or fallback
POOL_NAME=$(cat /sdcard/pool_name.txt 2>/dev/null)
[ -z "$POOL_NAME" ] && POOL_NAME="NA-LUCKPOOL"

# Get device alias for worker ID
DEV_IP=$(ip a | grep wlan0 | grep inet | awk '{print $2}' | cut -d/ -f1 | tail -n1)
WALLET="RQaWTAGYudd2sPnXy9vqVj8qd7VXLRP5ep"
ALIAS="miner-$(echo $DEV_IP | cut -d. -f3)-$(echo $DEV_IP | cut -d. -f4)"
USER_ID="${WALLET}.${ALIAS}"

# Desired config (static or pulled from server/API in future)
fetched_config=$(cat <<EOF
{
  "pools": [
    {
      "name": "USW-VIPOR",
      "url": "stratum+tcp://usw.vipor.net:5040",
      "timeout": 180,
      "disabled": 0
    },
    {
      "name": "NA-LUCKPOOL",
      "url": "stratum+tcp://na.luckpool.net:3960",
      "timeout": 180,
      "disabled": 1
    },
    {
      "name": "AIH-LOW",
      "url": "stratum+tcp://verus.aninterestinghole.xyz:9998",
      "timeout": 180,
      "disabled": 1
    },
    {
      "name": "WW-ZERGPOOL",
      "url": "stratum+tcp://verushash.mine.zergpool.com:3300",
      "timeout": 180,
      "disabled": 1
    }
  ],
  "user": "$USER_ID",
  "pass": "",
  "algo": "verus",
  "threads": 8,
  "cpu-priority": 1,
  "cpu-affinity": -1,
  "retry-pause": 5,
  "api-allow": "192.168.0.0/16",
  "api-bind": "0.0.0.0:4068"
}
EOF
)

# Write fetched config to tmp
echo "$fetched_config" | jq -S . > "$tmp_config"

# Compare with existing config
if [ -f "$config_file" ]; then
  current=$(jq -S . "$config_file")
  new=$(jq -S . "$tmp_config")

  if [ "$current" != "$new" ]; then
    mv "$tmp_config" "$config_file"
    restart_required=true
    echo "$(date) [✓] Config updated" >> "$log_file"
  else
    rm "$tmp_config"
    echo "$(date) [=] No config changes" >> "$log_file"
  fi
else
  mv "$tmp_config" "$config_file"
  restart_required=true
  echo "$(date) [+] Config initialized" >> "$log_file"
fi

# Restart miner if needed
if [ "$restart_required" = true ]; then
  echo "$(date) [⛏] Restarting ccminer..." >> "$log_file"
  pkill -f ccminer
  cd ~/ccminer
  ./ccminer -c config.json >> "$log_file" 2>&1 &
  sleep 2
  current_pool=$(jq -r '.pools[] | select(.disabled==0) | .name' "$config_file")
  echo "Pool: $current_pool" > "$pool_status_file"
  echo "$(date) [→] Active pool: $current_pool" >> "$log_file"
fi
