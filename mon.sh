#!/data/data/com.termux/files/usr/bin/bash

while true; do
  # Get battery status
  battery=$(termux-battery-status | jq '.')

  # Get Wi-Fi status
  wifi=$(termux-wifi-info 2>&1)
  if [ $? -ne 0 ]; then
    wifi="{\"error\": \"Failed to retrieve Wi-Fi info: $wifi\"}"
  else
    wifi=$(echo "$wifi" | jq '.')
  fi

  # Save JSON data to a file
  echo "{\"battery\": $battery, \"wifi\": $wifi}" > /data/data/com.termux/files/home/status.json

  sleep 60  # Wait for 1 minute
done
