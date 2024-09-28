#!/bin/bash

SERVER_URL="http://192.168.1.34:5000/data"
PHONE_ID=$(termux-telephony-deviceinfo | jq -r '.device_id')

while true; do
    # Get battery status
    battery=$(termux-battery-status)
    # Get Wi-Fi status
    wifi=$(termux-wifi-connectioninfo)

    # Send data to server
    curl -X POST -d "phone_id=$PHONE_ID&battery=$battery&wifi=$wifi" $SERVER_URL

    # Wait 5 minutes before sending again
    sleep 300
done
