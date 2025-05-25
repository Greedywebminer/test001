#!/data/data/com.termux/files/usr/bin/bash
CONFIG="$HOME/ccminer/config.json"
BIN="$HOME/ccminer/ccminer"
LOG="/sdcard/miner.log"

[ ! -f "$CONFIG" ] && echo "[✗] config.json not found at $CONFIG" >> "$LOG" && exit 1
[ ! -x "$BIN" ] && echo "[✗] ccminer binary not executable at $BIN" >> "$LOG" && exit 1

"$BIN" -c "$CONFIG" >> "$LOG" 2>&1
