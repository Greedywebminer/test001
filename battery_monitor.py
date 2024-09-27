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

if __name__ == '__main__':
    app.run(host='192.168.1.68', port=5000)
