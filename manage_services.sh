#!/bin/bash
# Pi Monitoring System - Simple Service Manager
# Essential commands for managing all monitoring services

SERVICES=("pi-health-server" "pi-cry-detector" "pi-camera-server" "pi-camera1-stream" "pi-camera2-stream")
SERVICE_PORTS=("9000" "8888" "8889" "8080" "8081")
SERVICE_NAMES=("Health Server" "Cry Detector" "Camera API" "Camera 1 Stream" "Camera 2 Stream")

show_banner() {
    echo "🔧 Pi Monitoring System - Service Manager"
    echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="
}

# Check status of all services
check_status() {
    show_banner
    echo "📊 Service Status:"
    echo ""
    
    for i in "${!SERVICES[@]}"; do
        local service="${SERVICES[$i]}"
        local port="${SERVICE_PORTS[$i]}"
        local name="${SERVICE_NAMES[$i]}"
        
        # Check service status
        if systemctl is-active $service >/dev/null 2>&1; then
            service_status="✅ Running"
        else
            service_status="❌ Stopped"
        fi
        
        # Check port accessibility
        if curl -s --connect-timeout 2 http://localhost:$port >/dev/null 2>&1; then
            port_status="✅ Accessible"
        else
            port_status="❌ Not accessible"
        fi
        
        echo "$name:"
        echo "  Service: $service_status"
        echo "  Port $port: $port_status"
        echo ""
    done
    
    echo "🌐 Dashboard URLs:"
    echo "  Main Dashboard: http://192.168.8.137/index.html"
    echo "  Health API: http://192.168.8.137:9000/health"
    echo "  Cry Detection: http://192.168.8.137:8888/cry/status"
    echo "  Camera 1 Stream: http://192.168.8.137:8080/?action=stream"
    echo "  Camera 2 Stream: http://192.168.8.137:8081/?action=stream"
}

# Start all services
start_services() {
    show_banner
    echo "▶️ Starting all services..."
    echo ""
    
    for i in "${!SERVICES[@]}"; do
        local service="${SERVICES[$i]}"
        local name="${SERVICE_NAMES[$i]}"
        
        echo "🚀 Starting $name..."
        sudo systemctl start $service
        
        if systemctl is-active $service >/dev/null 2>&1; then
            echo "✅ $name started"
        else
            echo "❌ Failed to start $name"
        fi
    done
    
    echo ""
    echo "⏳ Waiting for services to initialize..."
    sleep 3
    check_status
}

# Stop all services
stop_services() {
    show_banner
    echo "⏹️ Stopping all services..."
    echo ""
    
    for i in "${!SERVICES[@]}"; do
        local service="${SERVICES[$i]}"
        local name="${SERVICE_NAMES[$i]}"
        
        echo "🛑 Stopping $name..."
        sudo systemctl stop $service
        
        if ! systemctl is-active $service >/dev/null 2>&1; then
            echo "✅ $name stopped"
        else
            echo "❌ Failed to stop $name"
        fi
    done
}

# Restart all services
restart_services() {
    show_banner
    echo "🔄 Restarting all services..."
    echo ""
    
    stop_services
    echo ""
    start_services
}

# Show service logs
show_logs() {
    local service=${1:-"pi-health-server"}
    
    if [[ ! " ${SERVICES[*]} " =~ " ${service} " ]]; then
        echo "❌ Invalid service name. Available services:"
        for s in "${SERVICES[@]}"; do
            echo "   - $s"
        done
        return 1
    fi
    
    show_banner
    echo "📋 Showing logs for $service (Press Ctrl+C to exit):"
    echo ""
    sudo journalctl -u $service -f
}

# Enable autostart
enable_autostart() {
    show_banner
    echo "⚙️ Enabling autostart for all services..."
    
    for service in "${SERVICES[@]}"; do
        sudo systemctl enable $service
        echo "✅ $service enabled for autostart"
    done
    
    echo ""
    echo "🎉 All services will start automatically on boot!"
}

# Disable autostart
disable_autostart() {
    show_banner
    echo "⚙️ Disabling autostart for all services..."
    
    for service in "${SERVICES[@]}"; do
        sudo systemctl disable $service
        echo "✅ $service autostart disabled"
    done
}

# Show help
show_help() {
    show_banner
    echo "Usage: $0 {command}"
    echo ""
    echo "Commands:"
    echo "  status             Show status of all services"
    echo "  start              Start all services"
    echo "  stop               Stop all services"
    echo "  restart            Restart all services"
    echo "  logs [service]     Show logs for specific service"
    echo "  enable             Enable autostart on boot"
    echo "  disable            Disable autostart on boot"
    echo "  help               Show this help"
    echo ""
    echo "Available services for logs:"
    for service in "${SERVICES[@]}"; do
        echo "  - $service"
    done
    echo ""
    echo "Examples:"
    echo "  $0 status                    # Check all services"
    echo "  $0 restart                   # Restart all services"
    echo "  $0 logs pi-health-server     # View health server logs"
    echo "  $0 logs pi-cry-detector      # View cry detector logs"
}

# Main script logic
case "$1" in
    status)
        check_status
        ;;
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    logs)
        show_logs "$2"
        ;;
    enable)
        enable_autostart
        ;;
    disable)
        disable_autostart
        ;;
    help|--help|-h|*)
        show_help
        ;;
esac
