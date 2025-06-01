#!/bin/bash

# EC2 UserData Optimized CPU Control Setup Script with Speed Guard
# Enhanced error handling, logging, and security features
# Designed specifically for EC2 instance initialization

# Configuration
LOG_FILE="/var/log/cpu-control-setup.log"
APP_DIR="/home/ec2-user"
APP_FILE="$APP_DIR/cpu_control_app.py"
SERVICE_NAME="cpu-control"
MAX_CPU_CORES=$(nproc)

# Create log file with proper permissions
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handler with userdata-friendly behavior
error_exit() {
    log "ERROR: $1"
    # Don't exit immediately in userdata - log and continue where possible
    log "Continuing with setup despite error..."
}

# Userdata runs as root by default, so we'll handle permissions properly
log "Starting EC2 UserData execution for CPU Control application..."
log "Running as user: $(whoami)"

log "Starting CPU Control application setup..."

# Wait for system to be ready (important for userdata)
log "Waiting for system initialization..."
sleep 30

# Update system packages with retry logic
log "Updating system packages..."
for i in {1..3}; do
    if yum update -y; then
        log "System packages updated successfully"
        break
    else
        log "Package update attempt $i failed, retrying..."
        sleep 10
    fi
done

# Install required packages with retry logic
log "Installing Python3, pip, and dependencies..."
for i in {1..3}; do
    if yum install -y python3 python3-pip htop wget curl; then
        log "Basic packages installed successfully"
        break
    else
        log "Package installation attempt $i failed, retrying..."
        sleep 10
    fi
done

# Install EPEL repository
log "Installing EPEL repository..."
yum install -y epel-release || log "EPEL installation failed, continuing..."

# Install stress testing tools
log "Installing stress testing tools..."
yum install -y stress stress-ng || log "Stress tools installation failed, will use basic stress only"

# Install Python packages with pip upgrade
log "Upgrading pip and installing Python packages..."
python3 -m pip install --upgrade pip
pip3 install flask psutil Flask-Cors gunicorn || error_exit "Failed to install Python packages"

# Create application directory and ensure proper ownership
mkdir -p "$APP_DIR"
chown -R ec2-user:ec2-user "$APP_DIR"

# Create optimized Flask application
log "Creating Flask application..."
cat << 'EOF' > "$APP_FILE"
#!/usr/bin/env python3
"""
Optimized CPU Control Application with Speed Guard
Enhanced monitoring, safety features, and performance optimizations
"""

from flask import Flask, render_template_string, jsonify, request
from flask_cors import CORS
import psutil
import subprocess
import threading
import time
import json
import os
import signal
import logging
from datetime import datetime, timedelta

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/cpu-control-app.log'),
        logging.StreamHandler()
    ]
)

app = Flask(__name__)
CORS(app)

# Global variables and configuration
stress_processes = []
monitoring_active = True
cpu_history = []
MAX_HISTORY = 100
SAFETY_THRESHOLD = 95  # CPU percentage threshold for safety
MAX_STRESS_DURATION = 300  # Maximum stress duration in seconds (5 minutes)
SPEED_GUARD_ACTIVE = True

class SpeedGuard:
    def __init__(self):
        self.active = True
        self.cpu_threshold = 90
        self.memory_threshold = 85
        self.temp_threshold = 80  # Temperature threshold in Celsius
        self.monitoring_thread = None
        self.alerts = []
        
    def start_monitoring(self):
        """Start the speed guard monitoring thread"""
        if not self.monitoring_thread or not self.monitoring_thread.is_alive():
            self.monitoring_thread = threading.Thread(target=self._monitor_system, daemon=True)
            self.monitoring_thread.start()
            logging.info("Speed Guard monitoring started")
    
    def _monitor_system(self):
        """Continuous system monitoring with safety checks"""
        while self.active:
            try:
                # CPU monitoring
                cpu_percent = psutil.cpu_percent(interval=1)
                memory_percent = psutil.virtual_memory().percent
                
                # Temperature monitoring (if available)
                temp = self._get_cpu_temperature()
                
                # Check thresholds and take action
                if cpu_percent > self.cpu_threshold:
                    self._handle_high_cpu(cpu_percent)
                
                if memory_percent > self.memory_threshold:
                    self._handle_high_memory(memory_percent)
                
                if temp and temp > self.temp_threshold:
                    self._handle_high_temperature(temp)
                
                # Store metrics for history
                cpu_history.append({
                    'timestamp': datetime.now().isoformat(),
                    'cpu': round(cpu_percent, 2),
                    'memory': round(memory_percent, 2),
                    'temperature': temp
                })
                
                # Keep history size manageable
                if len(cpu_history) > MAX_HISTORY:
                    cpu_history.pop(0)
                    
            except Exception as e:
                logging.error(f"Speed Guard monitoring error: {e}")
            
            time.sleep(2)
    
    def _get_cpu_temperature(self):
        """Get CPU temperature if sensors are available"""
        try:
            if hasattr(psutil, "sensors_temperatures"):
                temps = psutil.sensors_temperatures()
                if temps:
                    # Try to get CPU temperature from common sensor names
                    for name, entries in temps.items():
                        if 'cpu' in name.lower() or 'core' in name.lower():
                            return entries[0].current if entries else None
        except:
            pass
        return None
    
    def _handle_high_cpu(self, cpu_percent):
        """Handle high CPU usage scenarios"""
        alert = f"HIGH CPU ALERT: {cpu_percent}% usage detected"
        logging.warning(alert)
        self.alerts.append({
            'timestamp': datetime.now().isoformat(),
            'type': 'CPU',
            'message': alert,
            'value': cpu_percent
        })
        
        # Auto-throttle if CPU is critically high
        if cpu_percent > SAFETY_THRESHOLD:
            self._emergency_throttle()
    
    def _handle_high_memory(self, memory_percent):
        """Handle high memory usage"""
        alert = f"HIGH MEMORY ALERT: {memory_percent}% usage detected"
        logging.warning(alert)
        self.alerts.append({
            'timestamp': datetime.now().isoformat(),
            'type': 'MEMORY',
            'message': alert,
            'value': memory_percent
        })
    
    def _handle_high_temperature(self, temp):
        """Handle high temperature"""
        alert = f"HIGH TEMPERATURE ALERT: {temp}°C detected"
        logging.warning(alert)
        self.alerts.append({
            'timestamp': datetime.now().isoformat(),
            'type': 'TEMPERATURE',
            'message': alert,
            'value': temp
        })
        
        # Emergency shutdown if temperature is critical
        if temp > 90:
            self._emergency_throttle()
    
    def _emergency_throttle(self):
        """Emergency system throttling"""
        logging.critical("EMERGENCY THROTTLE ACTIVATED")
        cancel_all_load()
        self.alerts.append({
            'timestamp': datetime.now().isoformat(),
            'type': 'EMERGENCY',
            'message': 'Emergency throttle activated - all stress processes terminated',
            'value': None
        })

# Initialize Speed Guard
speed_guard = SpeedGuard()

def cleanup_processes():
    """Clean up all stress processes"""
    global stress_processes
    for process in stress_processes[:]:
        try:
            if process.poll() is None:  # Process is still running
                process.terminate()
                process.wait(timeout=5)
        except:
            try:
                process.kill()
            except:
                pass
        finally:
            stress_processes.remove(process)
    
    # Additional cleanup using pkill
    try:
        subprocess.run(['pkill', '-f', 'stress'], check=False, timeout=10)
    except:
        pass

def cancel_all_load():
    """Cancel all CPU load processes"""
    cleanup_processes()
    logging.info("All stress processes terminated")

# Signal handlers for graceful shutdown
def signal_handler(signum, frame):
    logging.info(f"Received signal {signum}, shutting down gracefully...")
    global monitoring_active
    monitoring_active = False
    speed_guard.active = False
    cancel_all_load()
    exit(0)

signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

@app.route('/')
def index():
    """Main dashboard page"""
    hostname = subprocess.check_output(['hostname']).decode('utf-8').strip()
    cpu_count = psutil.cpu_count()
    return render_template_string(HTML_TEMPLATE, 
                                hostname=hostname, 
                                cpu_count=cpu_count,
                                speed_guard_active=speed_guard.active)

@app.route('/api/system_info')
def system_info():
    """Get comprehensive system information"""
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        load_avg = os.getloadavg()
        
        return jsonify({
            'cpu_percent': round(cpu_percent, 2),
            'cpu_count': psutil.cpu_count(),
            'memory_percent': round(memory.percent, 2),
            'memory_used_gb': round(memory.used / (1024**3), 2),
            'memory_total_gb': round(memory.total / (1024**3), 2),
            'disk_percent': round((disk.used / disk.total) * 100, 2),
            'load_avg': [round(x, 2) for x in load_avg],
            'active_stress_processes': len(stress_processes),
            'speed_guard_active': speed_guard.active,
            'uptime': time.time() - psutil.boot_time()
        })
    except Exception as e:
        logging.error(f"Error getting system info: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/cpu_history')
def get_cpu_history():
    """Get CPU usage history for graphing"""
    return jsonify(cpu_history[-50:])  # Return last 50 data points

@app.route('/api/alerts')
def get_alerts():
    """Get recent alerts from Speed Guard"""
    # Return only recent alerts (last 24 hours)
    recent_alerts = []
    cutoff_time = datetime.now() - timedelta(hours=24)
    
    for alert in speed_guard.alerts:
        alert_time = datetime.fromisoformat(alert['timestamp'])
        if alert_time > cutoff_time:
            recent_alerts.append(alert)
    
    return jsonify(recent_alerts[-20:])  # Return last 20 alerts

@app.route('/api/increase_load')
def increase_load():
    """Increase CPU load with safety checks"""
    try:
        # Safety check before starting load
        current_cpu = psutil.cpu_percent(interval=1)
        if current_cpu > SAFETY_THRESHOLD:
            return jsonify({
                'status': 'error',
                'message': f'CPU usage too high ({current_cpu}%) - load increase blocked by Speed Guard'
            }), 400
        
        # Limit number of concurrent stress processes
        if len(stress_processes) >= psutil.cpu_count():
            return jsonify({
                'status': 'error',
                'message': 'Maximum stress processes already running'
            }), 400
        
        # Start stress process with timeout
        process = subprocess.Popen([
            'stress-ng', 
            '--cpu', '1', 
            '--timeout', f'{MAX_STRESS_DURATION}s',
            '--quiet'
        ])
        stress_processes.append(process)
        
        logging.info(f"Started stress process PID: {process.pid}")
        
        return jsonify({
            'status': 'success', 
            'message': f'CPU load increased (Process: {process.pid})',
            'active_processes': len(stress_processes)
        })
        
    except Exception as e:
        logging.error(f"Error increasing load: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/cancel_load')
def cancel_load():
    """Cancel CPU load processes"""
    try:
        initial_count = len(stress_processes)
        cancel_all_load()
        return jsonify({
            'status': 'success',
            'message': f'Cancelled {initial_count} stress processes'
        })
    except Exception as e:
        logging.error(f"Error cancelling load: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/speed_guard/toggle')
def toggle_speed_guard():
    """Toggle Speed Guard on/off"""
    speed_guard.active = not speed_guard.active
    if speed_guard.active:
        speed_guard.start_monitoring()
        message = "Speed Guard activated"
    else:
        message = "Speed Guard deactivated"
    
    logging.info(message)
    return jsonify({'status': 'success', 'message': message, 'active': speed_guard.active})

# HTML Template
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CloudFolks HUB - Advanced CPU Control</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            text-align: center;
            color: white;
            margin-bottom: 30px;
        }
        
        .branding {
            font-size: 2.5em;
            font-weight: bold;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .card {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            padding: 20px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
        }
        
        .speed-guard {
            border-left: 5px solid #ff6b6b;
        }
        
        .speed-guard.active {
            border-left-color: #51cf66;
        }
        
        .meter {
            height: 25px;
            background: #e9ecef;
            border-radius: 15px;
            overflow: hidden;
            margin: 15px 0;
            position: relative;
        }
        
        .meter-fill {
            height: 100%;
            border-radius: 15px;
            transition: all 0.3s ease;
            background: linear-gradient(90deg, #51cf66, #69db7c);
        }
        
        .meter-fill.high { background: linear-gradient(90deg, #ff8787, #ff6b6b); }
        .meter-fill.critical { background: linear-gradient(90deg, #ff4757, #ff3838); }
        
        .controls {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
            justify-content: center;
            margin: 20px 0;
        }
        
        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.3s ease;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .btn-primary { background: #4dabf7; color: white; }
        .btn-danger { background: #ff6b6b; color: white; }
        .btn-warning { background: #ffd43b; color: #333; }
        
        .btn:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0,0,0,0.2); }
        
        .alerts {
            max-height: 200px;
            overflow-y: auto;
            background: #f8f9fa;
            border-radius: 8px;
            padding: 10px;
        }
        
        .alert {
            padding: 8px 12px;
            margin: 5px 0;
            border-radius: 5px;
            font-size: 0.9em;
        }
        
        .alert-cpu { background: #fff3cd; border-left: 4px solid #ffc107; }
        .alert-memory { background: #d1ecf1; border-left: 4px solid #17a2b8; }
        .alert-temperature { background: #f8d7da; border-left: 4px solid #dc3545; }
        .alert-emergency { background: #d4edda; border-left: 4px solid #28a745; }
        
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        
        .status-active { background: #51cf66; }
        .status-inactive { background: #ff6b6b; }
        
        @media (max-width: 768px) {
            .dashboard { grid-template-columns: 1fr; }
            .controls { flex-direction: column; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 class="branding">CloudFolks HUB</h1>
            <p>Advanced CPU Control & Monitoring System</p>
            <p>Host: {{ hostname }} | CPU Cores: {{ cpu_count }}</p>
        </div>
        
        <div class="dashboard">
            <div class="card">
                <h3>System Metrics</h3>
                <div>
                    <label>CPU Usage:</label>
                    <div class="meter">
                        <div id="cpu-meter" class="meter-fill" style="width: 0%;"></div>
                    </div>
                    <span id="cpu-text">0%</span>
                </div>
                
                <div>
                    <label>Memory Usage:</label>
                    <div class="meter">
                        <div id="memory-meter" class="meter-fill" style="width: 0%;"></div>
                    </div>
                    <span id="memory-text">0%</span>
                </div>
                
                <div>
                    <label>Active Stress Processes:</label>
                    <span id="process-count">0</span>
                </div>
            </div>
            
            <div class="card speed-guard" id="speed-guard-card">
                <h3>
                    <span class="status-indicator" id="guard-indicator"></span>
                    Speed Guard System
                </h3>
                <p id="guard-status">Monitoring system performance...</p>
                <div class="controls">
                    <button class="btn btn-warning" onclick="toggleSpeedGuard()">
                        Toggle Guard
                    </button>
                </div>
                
                <h4>Recent Alerts:</h4>
                <div id="alerts" class="alerts">
                    <p>No alerts</p>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h3>Load Control</h3>
            <div class="controls">
                <button class="btn btn-primary" onclick="increaseLoad()">
                    Increase CPU Load
                </button>
                <button class="btn btn-danger" onclick="cancelLoad()">
                    Cancel All Load
                </button>
            </div>
        </div>
    </div>
    
    <script>
        let systemData = {};
        
        function updateSystemInfo() {
            fetch('/api/system_info')
                .then(response => response.json())
                .then(data => {
                    systemData = data;
                    updateUI();
                })
                .catch(error => console.error('Error:', error));
        }
        
        function updateUI() {
            // Update CPU meter
            const cpuMeter = document.getElementById('cpu-meter');
            const cpuText = document.getElementById('cpu-text');
            const cpu = systemData.cpu_percent || 0;
            
            cpuMeter.style.width = cpu + '%';
            cpuText.textContent = cpu + '%';
            
            // Color coding for CPU
            cpuMeter.className = 'meter-fill';
            if (cpu > 80) cpuMeter.classList.add('critical');
            else if (cpu > 60) cpuMeter.classList.add('high');
            
            // Update Memory meter
            const memoryMeter = document.getElementById('memory-meter');
            const memoryText = document.getElementById('memory-text');
            const memory = systemData.memory_percent || 0;
            
            memoryMeter.style.width = memory + '%';
            memoryText.textContent = memory + '%';
            
            // Update process count
            document.getElementById('process-count').textContent = 
                systemData.active_stress_processes || 0;
            
            // Update Speed Guard status
            const guardCard = document.getElementById('speed-guard-card');
            const guardIndicator = document.getElementById('guard-indicator');
            const guardStatus = document.getElementById('guard-status');
            
            if (systemData.speed_guard_active) {
                guardCard.classList.add('active');
                guardIndicator.className = 'status-indicator status-active';
                guardStatus.textContent = 'Speed Guard is actively monitoring';
            } else {
                guardCard.classList.remove('active');
                guardIndicator.className = 'status-indicator status-inactive';
                guardStatus.textContent = 'Speed Guard is disabled';
            }
        }
        
        function updateAlerts() {
            fetch('/api/alerts')
                .then(response => response.json())
                .then(alerts => {
                    const alertsContainer = document.getElementById('alerts');
                    if (alerts.length === 0) {
                        alertsContainer.innerHTML = '<p>No recent alerts</p>';
                        return;
                    }
                    
                    alertsContainer.innerHTML = alerts.slice(-5).reverse().map(alert => 
                        `<div class="alert alert-${alert.type.toLowerCase()}">
                            <strong>${alert.type}:</strong> ${alert.message}
                            <br><small>${new Date(alert.timestamp).toLocaleString()}</small>
                        </div>`
                    ).join('');
                })
                .catch(error => console.error('Error fetching alerts:', error));
        }
        
        function increaseLoad() {
            fetch('/api/increase_load')
                .then(response => response.json())
                .then(data => {
                    if (data.status === 'success') {
                        showNotification(data.message, 'success');
                    } else {
                        showNotification(data.message, 'error');
                    }
                })
                .catch(error => {
                    showNotification('Error increasing load', 'error');
                    console.error('Error:', error);
                });
        }
        
        function cancelLoad() {
            fetch('/api/cancel_load')
                .then(response => response.json())
                .then(data => {
                    showNotification(data.message, 'success');
                })
                .catch(error => {
                    showNotification('Error cancelling load', 'error');
                    console.error('Error:', error);
                });
        }
        
        function toggleSpeedGuard() {
            fetch('/api/speed_guard/toggle')
                .then(response => response.json())
                .then(data => {
                    showNotification(data.message, 'success');
                })
                .catch(error => {
                    showNotification('Error toggling Speed Guard', 'error');
                    console.error('Error:', error);
                });
        }
        
        function showNotification(message, type) {
            // Simple notification system
            const notification = document.createElement('div');
            notification.textContent = message;
            notification.style.cssText = `
                position: fixed; top: 20px; right: 20px; z-index: 1000;
                padding: 15px 20px; border-radius: 5px; color: white;
                background: ${type === 'success' ? '#51cf66' : '#ff6b6b'};
                box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            `;
            document.body.appendChild(notification);
            
            setTimeout(() => {
                notification.remove();
            }, 3000);
        }
        
        // Initialize and set up intervals
        updateSystemInfo();
        updateAlerts();
        
        setInterval(updateSystemInfo, 2000);
        setInterval(updateAlerts, 5000);
    </script>
</body>
</html>
"""

if __name__ == "__main__":
    try:
        # Start Speed Guard monitoring
        speed_guard.start_monitoring()
        
        # Start Flask application
        logging.info("Starting CPU Control application...")
        app.run(host='0.0.0.0', port=8080, debug=False, threaded=True)
    except Exception as e:
        logging.error(f"Failed to start application: {e}")
        cancel_all_load()
        raise
EOF

# Set correct permissions
chown ec2-user:ec2-user "$APP_FILE"
chmod +x "$APP_FILE"

# Create systemd service for auto-start and management
log "Creating systemd service..."
tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << EOF
[Unit]
Description=CPU Control Application with Speed Guard
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_FILE
Restart=always
RestartSec=10
Environment=PYTHONUNBUFFERED=1

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=$APP_DIR /var/log

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable $SERVICE_NAME

# Create log rotation configuration
tee /etc/logrotate.d/$SERVICE_NAME > /dev/null << EOF
/var/log/cpu-control-*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 ec2-user ec2-user
}
EOF

# Set up firewall rules (if firewalld is active)
if sudo systemctl is-active --quiet firewalld; then
    log "Configuring firewall..."
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
fi

# Start the service
log "Starting CPU Control service..."
sudo systemctl start $SERVICE_NAME

# Display status
log "Service status:"
sudo systemctl status $SERVICE_NAME --no-pager

# Display access information
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")

log "Setup completed successfully!"
echo ""
echo "=============================================="
echo "CPU Control Application Setup Complete!"
echo "=============================================="
echo ""
echo "Service Status: $(sudo systemctl is-active $SERVICE_NAME)"
echo "Access URL: http://$INSTANCE_IP:8080"
echo "Service Management:"
echo "  Start:   sudo systemctl start $SERVICE_NAME"
echo "  Stop:    sudo systemctl stop $SERVICE_NAME"
echo "  Restart: sudo systemctl restart $SERVICE_NAME"
echo "  Status:  sudo systemctl status $SERVICE_NAME"
echo ""
echo "Logs:"
echo "  Application: /var/log/cpu-control-app.log"
echo "  Setup: /var/log/cpu-control-setup.log"
echo "  Service: sudo journalctl -u $SERVICE_NAME"
echo ""
echo "Features:"
echo "  ✓ Advanced Speed Guard system"
echo "  ✓ Real-time monitoring & alerts"
echo "  ✓ Emergency throttling"
echo "  ✓ System service integration"
echo "  ✓ Enhanced security settings"
echo "  ✓ Automatic log rotation"
echo "=============================================="