#!/data/data/com.termux/files/usr/bin/bash

# Start CCminer in a screen session
screen -dmS CCminer bash -c 'cd ~/ccminer && ./ccminer -c config.json'

# Start monitoring
./monitor.sh

# Start job scheduler in a screen session
screen -dmS Scheduler ./schedule_job.sh
