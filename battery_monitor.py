from flask import Flask, jsonify, request
import subprocess
import os
import requests
import json

app = Flask(__name__)

# Version number
VERSION = "1.0.9"

# Function to get battery status using Termux API
def get_battery_status():
    """Get battery status using Termux command"""
    try:
        output = subprocess.check_output(['termux-battery-status'], stderr=subprocess.DEVNULL)
        return json.loads(output.decode('utf-8'))
    except Exception as e:
        return {"error": str(e)}

# Function to check network connectivity
def get_network_status():
    """Check network connectivity"""
    try:
        output = subprocess.check_output(['ping', '-c', '1', '8.8.8.8'], stderr=subprocess.DEVNULL)
        return "Connected"
    except subprocess.CalledProcessError:
        return "Disconnected"

# Function to get CPU information from /proc/cpuinfo
def get_cpu_info():
    """Get CPU information from /proc/cpuinfo"""
    cpu_info = {}
    try:
        with open('/proc/cpuinfo', 'r') as f:
            for line in f:
                if line.strip():
                    if ":" in line:
                        key, value = line.split(":", 1)
                        cpu_info[key.strip()] = value.strip()
        return cpu_info
    except FileNotFoundError:
        return {"error": "Could not access /proc/cpuinfo"}

# Function to send data to a PHP script or endpoint
def send_data():
    """Send data to PHP script or echo if dry run"""
    url = "http://localhost:5000/api.php"  # Adjusted for local server
    hw_brand, hw_model, ip, summary_json, pool_json, battery, cpu_temp_json, cpu_count, rig_pw, cpu_info = get_system_data()

    data = {
        "hw_brand": hw_brand,
        "hw_model": hw_model,
        "ip": ip,
        "summary": summary_json,
        "pool": pool_json,
        "battery": battery,
        "cpu_temp": cpu_temp_json,
        "cpu_max": cpu_count,
        "cpu_info": cpu_info,
        "password": rig_pw,
        "monitor_version": VERSION,
        "scheduler_version": VERSION,
    }

    # Post data to the server
    try:
        response = requests.post(url, data=data)
        response_json = response.json()
        return response_json
    except Exception as e:
        return {"error": str(e)}

# Function to gather system data
def get_system_data():
    """Gather system data like hardware, IP, CPU info, etc."""
    hw_brand = "ANDROID"  # Hardcoded for demonstration, adjust as necessary
    hw_model = "Pixel"    # Hardcoded for demonstration, adjust as necessary
    ip = "192.168.1.68"   # Example IP, adjust dynamically or configure manually
    summary_json = {"summary": "Sample summary"}  # Example summary
    pool_json = {"pool": "Sample pool"}           # Example pool data
    battery = get_battery_status()
    cpu_temp_json = {"temp": "50"}                # Example CPU temp
    cpu_info = get_cpu_info()                     # Get CPU info from /proc/cpuinfo
    cpu_count = len([v for k, v in cpu_info.items() if k.startswith("processor")])  # Count CPU cores
    rig_pw = "your_password"                      # Placeholder password

    return hw_brand, hw_model, ip, summary_json, pool_json, battery, cpu_temp_json, cpu_count, rig_pw, cpu_info

# Endpoint to get system status (battery, network, CPU)
@app.route('/status', methods=['GET'])
def status():
    """Endpoint to get system status (battery, network, and CPU)"""
    battery_status = get_battery_status()
    network_status = get_network_status()
    cpu_info = get_cpu_info()

    return jsonify({
        'battery_status': battery_status,
        'network_status': network_status,
        'cpu_info': cpu_info
    })

# Endpoint to manually trigger data sending
@app.route('/send', methods=['POST'])
def send():
    """Endpoint to manually trigger data sending"""
    response = send_data()
    return jsonify(response)

if __name__ == '__main__':
    # Run Flask app on local network, accessible from other devices on the same network
    app.run(host='0.0.0.0', port=5000)
