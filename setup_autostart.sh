#!/bin/bash
# Autostart Setup Script for Pi Monitoring System
# This script sets up all services to start automatically on boot
# Includes direct camera streaming for specified devices

echo "🚀 Setting up Pi Monitoring System Autostart"
echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="

# Function to create systemd service
create_service() {
    local service_name=$1
    local description=$2
    local exec_start=$3
    local working_dir=$4
    local user=$5
    local additional_groups=$6

    echo "🔧 Creating $service_name service..."
    
    # Determine group settings
    local group_setting="audio"
    if [ ! -z "$additional_groups" ]; then
        group_setting="$additional_groups"
    fi
    
    sudo tee /etc/systemd/system/$service_name.service > /dev/null <<EOF
[Unit]
Description=$description
After=network.target sound.target
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=$user
Group=$group_setting
SupplementaryGroups=audio,video
WorkingDirectory=$working_dir
ExecStart=$exec_start
Restart=always
RestartSec=10
Environment=HOME=$working_dir
Environment=PULSE_RUNTIME_PATH=/run/user/1000/pulse

[Install]
WantedBy=multi-user.target
EOF

    # Enable the service
    sudo systemctl enable $service_name
    echo "✅ $service_name service created and enabled"
}

# Update system
echo "📦 Updating system packages..."
sudo apt update

# Install required packages
echo "📋 Installing system dependencies..."
sudo apt install -y python3 python3-pip mjpg-streamer v4l-utils

# Add user to required groups
echo "👤 Adding user to required groups..."
sudo usermod -a -G audio,video sahan

# Create health server service
create_service "pi-health-server" \
    "Pi Health Monitoring Server" \
    "/usr/bin/python3 /home/sahan/simple_health_server.py" \
    "/home/sahan" \
    "sahan"

# Create cry detection service  
create_service "pi-cry-detector" \
    "Baby Cry Detection Service" \
    "/usr/bin/python3 /home/sahan/cry_detector.py" \
    "/home/sahan" \
    "sahan"

# Create camera server service
create_service "pi-camera-server" \
    "Camera Streaming Server with Auto-start" \
    "/usr/bin/python3 /home/sahan/camera_server.py" \
    "/home/sahan" \
    "sahan" \
    "video"

# Create direct camera streaming services for guaranteed startup
echo "📹 Creating direct camera streaming services..."

# First, find the correct mjpg_streamer path
MJPG_STREAMER_PATH="/usr/local/bin/mjpg_streamer"
if [ ! -f "$MJPG_STREAMER_PATH" ]; then
    # Try alternative paths
    if [ -f "/usr/bin/mjpg_streamer" ]; then
        MJPG_STREAMER_PATH="/usr/bin/mjpg_streamer"
    elif command -v mjpg_streamer >/dev/null 2>&1; then
        MJPG_STREAMER_PATH=$(which mjpg_streamer)
    else
        echo "⚠️ mjpg_streamer not found - installing..."
        sudo apt update
        sudo apt install -y mjpg-streamer
        # Check again after installation
        if command -v mjpg_streamer >/dev/null 2>&1; then
            MJPG_STREAMER_PATH=$(which mjpg_streamer)
        else
            MJPG_STREAMER_PATH="/usr/local/bin/mjpg_streamer"
        fi
    fi
fi

echo "📍 Using mjpg_streamer at: $MJPG_STREAMER_PATH"

# Camera 1 - Live Stream (Infant) on port 8080
sudo tee /etc/systemd/system/pi-camera1-stream.service > /dev/null <<EOF
[Unit]
Description=Pi Camera 1 Live Stream (Infant)
After=network.target
Wants=network.target

[Service]
Type=simple
User=sahan
Group=video
SupplementaryGroups=audio
ExecStart=$MJPG_STREAMER_PATH -i "input_uvc.so -d /dev/video0 -r 640x480 -f 30" -o "output_http.so -p 8080 -w /usr/local/share/mjpg-streamer/www"
Restart=always
RestartSec=5
Environment=LD_LIBRARY_PATH=/usr/local/lib

[Install]
WantedBy=multi-user.target
EOF

# Camera 2 - LCD Reader on port 8081
sudo tee /etc/systemd/system/pi-camera2-stream.service > /dev/null <<EOF
[Unit]
Description=Pi Camera 2 LCD Reader Stream
After=network.target
Wants=network.target

[Service]
Type=simple
User=sahan
Group=video
SupplementaryGroups=audio
ExecStart=$MJPG_STREAMER_PATH -i "input_uvc.so -d /dev/video2 -r 640x480 -f 30" -o "output_http.so -p 8081 -w /usr/local/share/mjpg-streamer/www"
Restart=always
RestartSec=5
Environment=LD_LIBRARY_PATH=/usr/local/lib

[Install]
WantedBy=multi-user.target
EOF

# Enable camera streaming services
sudo systemctl enable pi-camera1-stream
sudo systemctl enable pi-camera2-stream
echo "✅ Direct camera streaming services created and enabled"

# Set up camera permissions
echo "🔒 Setting up camera permissions..."
sudo tee /etc/udev/rules.d/99-camera.rules > /dev/null <<EOF
SUBSYSTEM=="video4linux", GROUP="video", MODE="0664"
KERNEL=="video[0-9]*", GROUP="video", MODE="0664"
EOF

# Reload systemd and udev
echo "🔄 Reloading system services..."
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo udevadm trigger

# Create startup verification script
echo "📝 Creating startup verification script..."
tee /home/sahan/check_services.py > /dev/null <<'EOF'
#!/usr/bin/env python3
"""
Service Status Checker for Pi Monitoring System
Checks if all required services are running and provides status
"""

import subprocess
import requests
import time
import json

def check_service_status(service_name):
    """Check if a systemd service is running"""
    try:
        result = subprocess.run(['systemctl', 'is-active', service_name], 
                              capture_output=True, text=True)
        return result.stdout.strip() == 'active'
    except:
        return False

def check_api_endpoint(url, timeout=5):
    """Check if an API endpoint is responding"""
    try:
        response = requests.get(url, timeout=timeout)
        return response.status_code == 200
    except:
        return False

def main():
    print("🔍 Pi Monitoring System Status Check")
    print("=" * 50)
    
    services = {
        'pi-health-server': 'http://localhost:9000/health',
        'pi-cry-detector': 'http://localhost:8888/cry/status', 
        'pi-camera-server': 'http://localhost:8889/camera/status'
    }
    
    all_good = True
    
    for service, api_url in services.items():
        # Check service status
        service_running = check_service_status(service)
        
        # Check API endpoint
        api_responding = False
        if service_running:
            time.sleep(1)  # Give service a moment
            api_responding = check_api_endpoint(api_url)
        
        # Display status
        service_status = "✅ Running" if service_running else "❌ Stopped"
        api_status = "✅ Responding" if api_responding else "❌ Not responding"
        
        print(f"{service}:")
        print(f"  Service: {service_status}")
        print(f"  API: {api_status}")
        print()
        
        if not (service_running and api_responding):
            all_good = False
    
    if all_good:
        print("🎉 All services are running and responding!")
        print("🌐 Your Pi Monitoring Dashboard should work perfectly!")
    else:
        print("⚠️  Some services have issues. Check the logs:")
        print("   sudo journalctl -u pi-health-server -f")
        print("   sudo journalctl -u pi-cry-detector -f") 
        print("   sudo journalctl -u pi-camera-server -f")
    
    print("=" * 50)

if __name__ == "__main__":
    main()
EOF

chmod +x /home/sahan/check_services.py

# Create service management script
echo "🛠️ Creating service management script..."
tee /home/sahan/manage_services.sh > /dev/null <<'EOF'
#!/bin/bash
# Service Management Script for Pi Monitoring System

SERVICES=("pi-health-server" "pi-cry-detector" "pi-camera-server")

case "$1" in
    start)
        echo "▶️ Starting all Pi monitoring services..."
        for service in "${SERVICES[@]}"; do
            sudo systemctl start $service
            echo "Started $service"
        done
        ;;
    stop)
        echo "⏹️ Stopping all Pi monitoring services..."
        for service in "${SERVICES[@]}"; do
            sudo systemctl stop $service
            echo "Stopped $service"
        done
        ;;
    restart)
        echo "🔄 Restarting all Pi monitoring services..."
        for service in "${SERVICES[@]}"; do
            sudo systemctl restart $service
            echo "Restarted $service"
        done
        ;;
    status)
        echo "📊 Service status:"
        for service in "${SERVICES[@]}"; do
            status=$(systemctl is-active $service)
            echo "$service: $status"
        done
        echo ""
        echo "🔍 Detailed status check:"
        python3 /home/sahan/check_services.py
        ;;
    logs)
        service=${2:-"pi-health-server"}
        echo "📋 Showing logs for $service (Ctrl+C to exit):"
        sudo journalctl -u $service -f
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs [service-name]}"
        echo ""
        echo "Services: ${SERVICES[*]}"
        echo ""
        echo "Examples:"
        echo "  $0 status              # Check all services"
        echo "  $0 restart             # Restart all services"
        echo "  $0 logs pi-cry-detector # View cry detector logs"
        exit 1
        ;;
esac
EOF

chmod +x /home/sahan/manage_services.sh

# Start all services
echo "🚀 Starting all services..."
sudo systemctl start pi-health-server
sudo systemctl start pi-cry-detector  
sudo systemctl start pi-camera-server
sudo systemctl start pi-camera1-stream
sudo systemctl start pi-camera2-stream

# Wait a moment for services to start
echo "⏳ Waiting for services to start..."
sleep 5

# Check service status
echo "📊 Checking service status..."
./manage_services.sh status

echo ""
echo "✅ Pi Monitoring System Autostart Setup Complete!"
echo ""
echo "🎯 What's been set up:"
echo "  📊 Health Server (Port 9000) - System metrics"
echo "  👶 Cry Detector (Port 8888) - Audio monitoring" 
echo "  📹 Camera Server (Port 8889) - Camera management API"
echo "  📷 Camera 1 Stream (Port 8080) - Live infant camera (/dev/video0)"
echo "  📷 Camera 2 Stream (Port 8081) - LCD reader camera (/dev/video2)"
echo ""
echo "🔧 Service Management:"
echo "  ./manage_services.sh status    # Check all services"
echo "  ./manage_services.sh restart   # Restart all services"
echo "  ./manage_services.sh logs      # View service logs"
echo ""
echo "🔍 Check Status:"
echo "  python3 check_services.py      # Detailed status check"
echo ""
echo "🌐 Your Dashboard URLs:"
echo "  Health: http://192.168.8.137:9000/health"
echo "  Cry Detection: http://192.168.8.137:8888/cry/status"
echo "  Camera API: http://192.168.8.137:8889/camera/status"
echo "  Camera 1 Stream: http://192.168.8.137:8080/?action=stream"
echo "  Camera 2 Stream: http://192.168.8.137:8081/?action=stream"
echo ""
echo "🔄 All services will now start automatically on Pi boot!"
echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="
