#!/bin/bash
# Complete Service Recovery Script
# Fixes all Pi monitoring services (health, cry detection, cameras)

echo "🔧 Complete Pi Monitoring Service Recovery"
echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="

# Service definitions
ALL_SERVICES=("pi-health-server" "pi-cry-detector" "pi-camera-server" "pi-camera1-stream" "pi-camera2-stream")
SERVICE_PORTS=("9000" "8888" "8889" "8080" "8081")
SERVICE_NAMES=("Health Server" "Cry Detector" "Camera API" "Camera 1 Stream" "Camera 2 Stream")

# Function to check and restart a service
check_and_restart_service() {
    local service=$1
    local port=$2
    local name=$3
    
    echo "🔍 Checking $name..."
    
    # Check if service is active
    if systemctl is-active $service >/dev/null 2>&1; then
        echo "  ✅ Service is running"
        
        # Check if port is accessible
        if curl -s --connect-timeout 2 http://localhost:$port >/dev/null 2>&1; then
            echo "  ✅ Port $port is accessible"
            return 0
        else
            echo "  ⚠️ Service running but port $port not accessible - restarting..."
        fi
    else
        echo "  ❌ Service not running - starting..."
    fi
    
    # Restart the service
    sudo systemctl restart $service
    sleep 2
    
    # Check if restart was successful
    if systemctl is-active $service >/dev/null 2>&1; then
        echo "  ✅ $name restarted successfully"
        
        # Give it time to fully start
        sleep 3
        
        # Test port accessibility
        if curl -s --connect-timeout 3 http://localhost:$port >/dev/null 2>&1; then
            echo "  ✅ Port $port now accessible"
            return 0
        else
            echo "  ⚠️ Service started but port still not accessible"
            return 1
        fi
    else
        echo "  ❌ Failed to restart $name"
        return 1
    fi
}

# Function to check Python dependencies
check_python_dependencies() {
    echo "🐍 Checking Python dependencies..."
    
    # Check requests module (for health server)
    if python3 -c "import requests" 2>/dev/null; then
        echo "  ✅ requests module available"
    else
        echo "  ❌ requests module missing - installing..."
        pip3 install requests --break-system-packages
    fi
    
    # Check pyaudio module (for cry detection)
    if python3 -c "import pyaudio" 2>/dev/null; then
        echo "  ✅ pyaudio module available"
    else
        echo "  ⚠️ pyaudio module missing - cry detection may not work"
        echo "  📦 Installing pyaudio..."
        sudo apt install -y python3-pyaudio portaudio19-dev
        pip3 install pyaudio --break-system-packages
    fi
}

# Function to check system requirements
check_system_requirements() {
    echo "🔍 Checking system requirements..."
    
    # Check audio devices (for cry detection)
    if ls /proc/asound/card* >/dev/null 2>&1; then
        echo "  ✅ Audio devices available"
    else
        echo "  ⚠️ No audio devices found - cry detection may not work"
    fi
    
    # Check video devices (for cameras)
    if ls /dev/video* >/dev/null 2>&1; then
        echo "  ✅ Video devices available:"
        ls -la /dev/video* | while read line; do echo "    $line"; done
    else
        echo "  ⚠️ No video devices found - cameras may not work"
    fi
    
    # Check mjpg_streamer
    if command -v mjpg_streamer >/dev/null 2>&1; then
        echo "  ✅ mjpg_streamer available at: $(which mjpg_streamer)"
    else
        echo "  ❌ mjpg_streamer not found"
    fi
}

# Function to verify service files exist
check_service_files() {
    echo "📋 Checking service files..."
    
    for service in "${ALL_SERVICES[@]}"; do
        service_file="/etc/systemd/system/${service}.service"
        if [ -f "$service_file" ]; then
            echo "  ✅ $service.service exists"
        else
            echo "  ❌ $service.service missing"
            return 1
        fi
    done
    
    return 0
}

# Function to check Python script files
check_python_files() {
    echo "🐍 Checking Python script files..."
    
    local python_files=("simple_health_server.py" "cry_detector.py" "camera_server.py")
    
    for file in "${python_files[@]}"; do
        if [ -f "/home/sahan/$file" ]; then
            echo "  ✅ $file exists"
            
            # Basic syntax check
            if python3 -m py_compile "/home/sahan/$file" 2>/dev/null; then
                echo "  ✅ $file syntax is valid"
            else
                echo "  ❌ $file has syntax errors"
                return 1
            fi
        else
            echo "  ❌ $file missing"
            return 1
        fi
    done
    
    return 0
}

# Main recovery process
echo "🚀 Starting complete service recovery..."
echo ""

# Step 1: Check system requirements
check_system_requirements
echo ""

# Step 2: Check Python dependencies
check_python_dependencies
echo ""

# Step 3: Check service files
if ! check_service_files; then
    echo "❌ Service files missing - please run setup_autostart.sh first"
    exit 1
fi
echo ""

# Step 4: Check Python files
if ! check_python_files; then
    echo "❌ Python files missing - please copy all Python scripts to /home/sahan/"
    exit 1
fi
echo ""

# Step 5: Reload systemd (in case of any changes)
echo "🔄 Reloading systemd..."
sudo systemctl daemon-reload
echo ""

# Step 6: Enable all services
echo "⚙️ Ensuring all services are enabled for autostart..."
for service in "${ALL_SERVICES[@]}"; do
    sudo systemctl enable $service
    echo "  ✅ $service enabled"
done
echo ""

# Step 7: Check and restart each service
echo "🔧 Checking and restarting services as needed..."
failed_services=()

for i in "${!ALL_SERVICES[@]}"; do
    service="${ALL_SERVICES[$i]}"
    port="${SERVICE_PORTS[$i]}"
    name="${SERVICE_NAMES[$i]}"
    
    if ! check_and_restart_service "$service" "$port" "$name"; then
        failed_services+=("$service")
    fi
    echo ""
done

# Step 8: Final status check
echo "📊 Final Service Status Report:"
echo ""

all_working=true
for i in "${!ALL_SERVICES[@]}"; do
    service="${ALL_SERVICES[$i]}"
    port="${SERVICE_PORTS[$i]}"
    name="${SERVICE_NAMES[$i]}"
    
    # Check service status
    if systemctl is-active $service >/dev/null 2>&1; then
        service_status="✅ Running"
    else
        service_status="❌ Stopped"
        all_working=false
    fi
    
    # Check port accessibility
    if curl -s --connect-timeout 2 http://localhost:$port >/dev/null 2>&1; then
        port_status="✅ Accessible"
    else
        port_status="❌ Not accessible"
        all_working=false
    fi
    
    echo "$name ($service):"
    echo "  Service: $service_status"
    echo "  Port $port: $port_status"
    echo ""
done

# Step 9: Show URLs for testing
echo "🌐 Service URLs for testing:"
echo "  Health API: http://192.168.8.137:9000/health"
echo "  Cry Detection: http://192.168.8.137:8888/cry/status"
echo "  Camera API: http://192.168.8.137:8889/camera/status"
echo "  Camera 1 Stream: http://192.168.8.137:8080/?action=stream"
echo "  Camera 2 Stream: http://192.168.8.137:8081/?action=stream"
echo ""

# Step 10: Summary and recommendations
if [ "$all_working" = true ]; then
    echo "🎉 All services are working properly!"
    echo "✅ Your Pi monitoring dashboard should be fully functional"
else
    echo "⚠️ Some services have issues:"
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        echo "Failed services:"
        for failed in "${failed_services[@]}"; do
            echo "  - $failed"
        done
        echo ""
        echo "🔧 Troubleshooting steps:"
        echo "1. Check service logs:"
        for failed in "${failed_services[@]}"; do
            echo "   sudo journalctl -u $failed -n 20"
        done
        echo ""
        echo "2. Check if required files exist:"
        echo "   ls -la /home/sahan/*.py"
        echo ""
        echo "3. Check Python dependencies:"
        echo "   python3 -c 'import requests, pyaudio'"
        echo ""
        echo "4. Manually test services:"
        echo "   python3 /home/sahan/simple_health_server.py"
        echo "   python3 /home/sahan/cry_detector.py"
    fi
fi

echo ""
echo "📋 For ongoing monitoring, use:"
echo "  ./service_manager.sh status    # Check all services"
echo "  ./service_manager.sh restart   # Restart all services"
echo "  ./service_manager.sh logs [service]   # View service logs"

echo ""
echo "✅ Complete service recovery finished!"
