#!/data/data/com.termux/files/usr/bin/bash
cd ~/ccminer
nohup ./ccminer -c config.json >> miner.log 2>&1 &

