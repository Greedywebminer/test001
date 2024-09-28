from flask import Flask, jsonify
import os
import subprocess

app = Flask(__name__)

def get_battery_status():
    # Get battery status using Termux command
    try:
        output = subprocess.check_output(['termux-battery-status'], stderr=subprocess.DEVNULL)
        return output.decode('utf-8')
    except Exception as e:
        return str(e)

def get_network_status():
    # Check network connectivity
    try:
        output = subprocess.check_output(['ping', '-c', '1', '8.8.8.8'], stderr=subprocess.DEVNULL)
        return "Connected"
    except subprocess.CalledProcessError:
        return "Disconnected"

@app.route('/status', methods=['GET'])
def status():
    battery_status = get_battery_status()
    network_status = get_network_status()

    return jsonify({
        'battery_status': battery_status,
        'network_status': network_status
    })

#!/bin/bash

# Version number
VERSION="1.0.9"

# Function to send data to PHP script or echo if dryrun
send_data() {
  local url="http://localhost:5000/api.php"  # Updated for local server
  local data="hw_brand=$hw_brand&hw_model=$hw_model&ip=$ip&summary=$summary_json&pool=$pool_json&battery=$battery&cpu_temp=$cpu_temp_json&cpu_max=$cpu_count&password=$rig_pw&monitor_version=$VERSION&scheduler_version=$scheduler_version"

  if [ -n "$miner_id" ]; then
    data+="&miner_id=$miner_id"
  fi

  if [ "$dryrun" == true ]; then
    echo "curl -s -X POST -d \"$data\" \"$url\""
  else
    response=$(curl -s -X POST -d "$data" "$url")
    echo "Response from server: $response"
  fi

  # Extracting miner_id from the response
  miner_id=$(echo "$response" | jq -r '.miner_id')

  # Check if miner_id is valid and update rig.conf
  if [[ "$miner_id" =~ ^[0-9]+$ ]]; then
    update_rig_conf "$miner_id"
  else
    echo "Invalid miner_id received: $miner_id"
  fi
}

# Function to update rig.conf with miner_id and ssl_supported
update_rig_conf() {
  local miner_id=$1
  local rig_conf_path=~/rig.conf

  if [ -f "$rig_conf_path" ]; then
    if grep -q "miner_id=" "$rig_conf_path"; then
      sed -i "s/miner_id=.*/miner_id=$(printf '%q' "$miner_id")/" "$rig_conf_path"
    else
      echo "miner_id=$miner_id" >> "$rig_conf_path"
    fi

    if grep -q "ssl_supported=" "$rig_conf_path"; then
      sed -i "s/ssl_supported=.*/ssl_supported=$(printf '%q' "$ssl_supported")/" "$rig_conf_path"
    else
      echo "ssl_supported=$ssl_supported" >> "$rig_conf_path"
    fi
  else
    echo "rig.conf file not found. Creating a new one."
    echo "miner_id=$miner_id" > "$rig_conf_path"
    echo "ssl_supported=$ssl_supported" >> "$rig_conf_path"
  fi
}

# Determine SSL support and update rig.conf only if not already set
ssl_supported="false"
if [ -f ~/rig.conf ]; then
  ssl_supported=$(grep -E "^ssl_supported=" ~/rig.conf | cut -d '=' -f 2)
fi

if [ -z "$ssl_supported" ]; then
  if check_ssl_support; then
    ssl_supported="true"
  else
    ssl_supported="false"
  fi
  # Update rig.conf with the SSL support status
  update_rig_conf "$miner_id"
fi

# Get the number of CPUs
cpu_count=$(lscpu | grep -E '^CPU\(s\):' | awk '{print $2}')

# Check if connectivity to Internet is given
x=$(ping -c1 google.com 2>&1 | grep unknown)
if [ ! "$x" = "" ]; then
  # For Android if connection is down try to restart Wifi network
  if su -c true 2>/dev/null; then
    echo "Connection to Internet broken. Restarting Network!"
    su -c input keyevent 26
    su -c svc wifi disable
    su -c svc wifi enable
    sleep 10
  fi
fi

# Parse arguments
dryrun=false
if [ "$1" == "--dryrun" ]; then
  dryrun=true
fi

# Check if ~/rig.conf exists and rig_pw is set
if [ -f ~/rig.conf ]; then
  rig_pw=$(grep -E "^rig_pw=" ~/rig.conf | cut -d '=' -f 2)
  if [ -z "$rig_pw" ]; then
    echo "rig_pw not set in ~/rig.conf. Exiting."
    exit 1
  fi
  miner_id=$(grep -E "^miner_id=" ~/rig.conf | cut -d '=' -f 2)
else
  echo "~/rig.conf file not found. Exiting."
  exit 1
fi

# Check hardware brand and format to uppercase
if [ -f /sys/firmware/devicetree/base/model ]; then
  hw_brand=$(cat /sys/firmware/devicetree/base/model | awk '{print $1}' | tr '[:lower:]' '[:upper:]')
elif [ -n "$(uname -o | grep Android)" ]; then
  hw_brand=$(getprop ro.product.brand | tr '[:lower:]' '[:upper:]')
elif [ "$(uname -s)" == "Linux" ]; then
  hw_brand=$(lsb_release -a 2>/dev/null | grep "Description:" | cut -d ':' -f 2- | sed 's/^[ \t]*//;s/[ \t]*$//')
else
  hw_brand=$(uname -o | tr '[:lower:]' '[:upper:]')
fi

# Check hardware model and format to uppercase
if [ -f /sys/firmware/devicetree/base/model ]; then
  hw_model=$(cat /sys/firmware/devicetree/base/model | awk '{print $2 $3}')
elif [ -n "$(uname -o | grep Android)" ]; then
  hw_model=$(getprop ro.product.model)
else
  hw_model=$(uname -m)
fi
hw_model=$(echo "$hw_model" | tr '[:lower:]' '[:upper:]')

# Get local IP address (prefer ethernet over wlan, IPv4 only)
if [ -n "$(uname -o | grep Android)" ]; then
  ip=$(termux-wifi-connectioninfo | grep -oP '(?<="ip": ")[^"]*')
  if [ -z "$ip" ]; then
    ip=$(ifconfig 2> /dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '[0-9.]*' | grep -v 127.0.0.1)
    if [ -z "$ip" ]; then
      if su -c true 2>/dev/null; then
        ip=$(su -c ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1)
      fi
    fi
  fi
else
  ip=$(ip -4 -o addr show | awk '$2 !~ /lo|docker/ {print $4}' | cut -d "/" -f 1 | head -n 1)
fi

# Check if ccminer is running, exit if not
if ! screen -list | grep -q "\.CCminer"; then
  echo "ccminer not running. Exiting."
  exit 1
fi

# Get summary output of ccminer API socket (default port)
summary_raw=$(echo 'summary' | nc 127.0.0.1 4068 | tr -d '\0')
summary_raw=${summary_raw%|}  # Remove trailing '|'
summary_json=$(echo "$summary_raw" | jq -R 'split(";") | map(split("=")) | map({(.[0]): .[1]}) | add')

# Get pool output of ccminer API socket (default port)
pool_raw=$(echo 'pool' | nc 127.0.0.1 4068 | tr -d '\0')
pool_raw=${pool_raw%|}  # Remove trailing '|'
pool_json=$(echo "$pool_raw" | jq -R 'split(";") | map(split("=")) | map({(.[0]): .[1]}) | add')

# Check battery status if OS is Termux
if [ "$(uname -o)" == "Android" ]; then
  battery=$(timeout 2s termux-battery-status | jq -c '.')
  if [ -z "$battery" ]; then
    battery="{}"
  fi
else
  battery="{}"
fi

# Check CPU temperature if available
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
  cpu_temp=$(cat /sys/class/thermal/thermal_zone0/temp)
  cpu_temp_json="{\"temp\": $(echo "scale=2; $cpu_temp/1000" | bc)}"
else
  cpu_temp_json="{}"
fi

# Call send_data function to execute the POST request
send_data

if __name__ == '__main__':
    app.run(host='192.168.1.68', port=5000)
