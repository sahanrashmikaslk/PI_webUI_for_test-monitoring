#!/bin/bash
# Pi Monitoring System - Service Manager
# Complete management script for all monitoring services including direct camera streams

SERVICES=("pi-health-server" "pi-cry-detector" "pi-camera-server" "pi-camera1-stream" "pi-camera2-stream")
SERVICE_PORTS=("9000" "8888" "8889" "8080"    echo "Commands:"
    echo "  start              Start all services"
    echo "  stop               Stop all services" 
    echo "  restart            Restart all services"
    echo "  restart-cameras    Restart only camera services"
    echo "  recover            Complete service recovery (recommended)"
    echo "  status             Show detailed status"
    echo "  cameras            Check camera streams only"
    echo "  enable             Enable autostart on boot"
    echo "  disable            Disable autostart on boot"
    echo "  logs [service]     Show logs for service"
    echo "  fix-permissions    Fix camera permissions"
    echo "  install            Install dependencies"
    echo "  help               Show this help"ERVICE_NAMES=("Health Server" "Cry Detector" "Camera API" "Camera 1 Stream" "Camera 2 Stream")

show_banner() {
    echo "🔧 Pi Monitoring System - Service Manager"
    echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="
}

check_service_detailed() {
    local service=$1
    local port=$2
    local name=$3
    
    # Check systemd service status
    local service_status=$(systemctl is-active $service 2>/dev/null)
    local service_enabled=$(systemctl is-enabled $service 2>/dev/null)
    
    # Check if port is listening
    local port_status=""
    if netstat -tln 2>/dev/null | grep -q ":$port "; then
        port_status="✅ Listening"
    else
        port_status="❌ Not listening"
    fi
    
    # Check API response (only for API services, not camera streams)
    local api_status=""
    if [[ "$service" == *"stream"* ]]; then
        # For camera streams, check if stream is accessible
        if curl -s --connect-timeout 2 http://localhost:$port >/dev/null 2>&1; then
            api_status="✅ Stream available"
        else
            api_status="❌ Stream not available"
        fi
    else
        # For API services, check API response
        if curl -s --connect-timeout 2 http://localhost:$port >/dev/null 2>&1; then
            api_status="✅ API responding"
        else
            api_status="❌ API not responding"
        fi
    fi
    
    echo "📊 $name ($service):"
    echo "   Service Status: $service_status"
    echo "   Auto-start: $service_enabled"
    echo "   Port $port: $port_status"
    echo "   Endpoint: $api_status"
    echo ""
}

start_services() {
    show_banner
    echo "▶️ Starting all Pi monitoring services..."
    echo ""
    
    for i in "${!SERVICES[@]}"; do
        local service="${SERVICES[$i]}"
        local name="${SERVICE_NAMES[$i]}"
        
        echo "🚀 Starting $name..."
        sudo systemctl start $service
        
        if systemctl is-active $service >/dev/null 2>&1; then
            echo "✅ $name started successfully"
        else
            echo "❌ Failed to start $name"
        fi
        echo ""
    done
    
    echo "⏳ Waiting for services to initialize..."
    sleep 3
    check_status
}

stop_services() {
    show_banner
    echo "⏹️ Stopping all Pi monitoring services..."
    echo ""
    
    for i in "${!SERVICES[@]}"; do
        local service="${SERVICES[$i]}"
        local name="${SERVICE_NAMES[$i]}"
        
        echo "🛑 Stopping $name..."
        sudo systemctl stop $service
        
        if ! systemctl is-active $service >/dev/null 2>&1; then
            echo "✅ $name stopped successfully"
        else
            echo "❌ Failed to stop $name"
        fi
        echo ""
    done
}

restart_services() {
    show_banner
    echo "🔄 Restarting all Pi monitoring services..."
    echo ""
    
    # Stop all services first
    for i in "${!SERVICES[@]}"; do
        local service="${SERVICES[$i]}"
        local name="${SERVICE_NAMES[$i]}"
        
        echo "⏹️ Stopping $name..."
        sudo systemctl stop $service
    done
    
    echo ""
    echo "⏳ Waiting for services to stop..."
    sleep 2
    
    # Start all services
    for i in "${!SERVICES[@]}"; do
        local service="${SERVICES[$i]}"
        local name="${SERVICE_NAMES[$i]}"
        
        echo "🚀 Starting $name..."
        sudo systemctl start $service
        
        if systemctl is-active $service >/dev/null 2>&1; then
            echo "✅ $name started successfully"
        else
            echo "❌ Failed to start $name"
        fi
        echo ""
    done
    
    echo "⏳ Waiting for services to initialize..."
    sleep 5
    check_status
}

recover_all_services() {
    show_banner
    echo "🛠️ Running complete service recovery..."
    echo ""
    
    if [ -f "./recover_all_services.sh" ]; then
        chmod +x ./recover_all_services.sh
        ./recover_all_services.sh
    else
        echo "❌ recover_all_services.sh not found"
        echo "   Please ensure all scripts are in the current directory"
        echo ""
        echo "🔄 Performing basic recovery instead..."
        
        # Basic recovery: reload systemd and restart all services
        sudo systemctl daemon-reload
        
        for i in "${!SERVICES[@]}"; do
            local service="${SERVICES[$i]}"
            local name="${SERVICE_NAMES[$i]}"
            
            echo "🔄 Recovering $name..."
            sudo systemctl enable $service
            sudo systemctl restart $service
            
            if systemctl is-active $service >/dev/null 2>&1; then
                echo "✅ $name recovered"
            else
                echo "❌ Failed to recover $name"
            fi
        done
        
        echo ""
        echo "⏳ Waiting for services to initialize..."
        sleep 5
        check_status
    fi
}

check_status() {
    show_banner
    echo "📊 Detailed Service Status:"
    echo ""
    
    for i in "${!SERVICES[@]}"; do
        check_service_detailed "${SERVICES[$i]}" "${SERVICE_PORTS[$i]}" "${SERVICE_NAMES[$i]}"
    done
    
    # Overall system check
    echo "🌐 Dashboard Access URLs:"
    echo "   Health API: http://192.168.8.137:9000/health"
    echo "   Cry Detection: http://192.168.8.137:8888/cry/status"
    echo "   Camera API: http://192.168.8.137:8889/camera/status"
    echo ""
    
    # Quick API test
    echo "🔍 Quick API Test:"
    for i in "${!SERVICE_PORTS[@]}"; do
        local port="${SERVICE_PORTS[$i]}"
        local name="${SERVICE_NAMES[$i]}"
        
        if curl -s --connect-timeout 2 http://localhost:$port >/dev/null 2>&1; then
            echo "   ✅ $name API (Port $port)"
        else
            echo "   ❌ $name API (Port $port)"
        fi
    done
    echo ""
}

enable_autostart() {
    show_banner
    echo "🔧 Enabling autostart for all services..."
    echo ""
    
    for i in "${!SERVICES[@]}"; do
        local service="${SERVICES[$i]}"
        local name="${SERVICE_NAMES[$i]}"
        
        echo "⚙️ Enabling autostart for $name..."
        sudo systemctl enable $service
        
        if systemctl is-enabled $service >/dev/null 2>&1; then
            echo "✅ $name autostart enabled"
        else
            echo "❌ Failed to enable autostart for $name"
        fi
        echo ""
    done
    
    echo "🎉 All services will now start automatically on boot!"
}

disable_autostart() {
    show_banner
    echo "🔧 Disabling autostart for all services..."
    echo ""
    
    for i in "${!SERVICES[@]}"; do
        local service="${SERVICES[$i]}"
        local name="${SERVICE_NAMES[$i]}"
        
        echo "⚙️ Disabling autostart for $name..."
        sudo systemctl disable $service
        
        if ! systemctl is-enabled $service >/dev/null 2>&1; then
            echo "✅ $name autostart disabled"
        else
            echo "❌ Failed to disable autostart for $name"
        fi
        echo ""
    done
}

show_logs() {
    local service=${1:-"pi-health-server"}
    
    if [[ ! " ${SERVICES[*]} " =~ " ${service} " ]]; then
        echo "❌ Invalid service name. Available services:"
        for s in "${SERVICES[@]}"; do
            echo "   - $s"
        done
        exit 1
    fi
    
    show_banner
    echo "📋 Showing logs for $service (Press Ctrl+C to exit):"
    echo ""
    sudo journalctl -u $service -f
}

install_dependencies() {
    show_banner
    echo "📦 Installing system dependencies..."
    
    sudo apt update
    sudo apt install -y python3 python3-pip mjpg-streamer v4l-utils netstat-nat curl
    
    echo "🐍 Installing Python packages..."
    pip3 install requests --break-system-packages
    
    echo "👤 Adding user to required groups..."
    sudo usermod -a -G audio,video $USER
    
    echo "✅ Dependencies installed!"
}

show_help() {
    show_banner
    echo "Usage: $0 {command} [options]"
    echo ""
    echo "Commands:"
    echo "  start              Start all services"
    echo "  stop               Stop all services" 
    echo "  restart            Restart all services"
    echo "  status             Show detailed status"
    echo "  enable             Enable autostart on boot"
    echo "  disable            Disable autostart on boot"
    echo "  logs [service]     Show logs for service"
    echo "  install            Install dependencies"
    echo "  help               Show this help"
    echo ""
    echo "Available services:"
    for i in "${!SERVICES[@]}"; do
        echo "  ${SERVICES[$i]} - ${SERVICE_NAMES[$i]} (Port ${SERVICE_PORTS[$i]})"
    done
    echo ""
    echo "Examples:"
    echo "  $0 status                    # Check all services"
    echo "  $0 restart                   # Restart all services"
    echo "  $0 logs pi-cry-detector      # View cry detector logs"
    echo "  $0 enable                    # Enable autostart"
}

# Main script logic
case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    recover)
        recover_all_services
        ;;
    status)
        check_status
        ;;
    enable)
        enable_autostart
        ;;
    disable)
        disable_autostart
        ;;
    logs)
        show_logs "$2"
        ;;
    install)
        install_dependencies
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
