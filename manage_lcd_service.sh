#!/bin/bash
#
# Manage LCD Reading Service
# Quick commands to control the LCD reading server
#
# Usage:
#   ./manage_lcd_service.sh [start|stop|restart|status|logs|enable|disable]
#

SERVICE_NAME="lcd-reading.service"

case "$1" in
    start)
        echo "🚀 Starting LCD reading service..."
        sudo systemctl start $SERVICE_NAME
        sleep 1
        sudo systemctl status $SERVICE_NAME --no-pager -l | head -n 15
        ;;
    
    stop)
        echo "⏹️  Stopping LCD reading service..."
        sudo systemctl stop $SERVICE_NAME
        echo "✅ Service stopped"
        ;;
    
    restart)
        echo "🔄 Restarting LCD reading service..."
        sudo systemctl restart $SERVICE_NAME
        sleep 1
        sudo systemctl status $SERVICE_NAME --no-pager -l | head -n 15
        ;;
    
    status)
        echo "📊 LCD reading service status:"
        sudo systemctl status $SERVICE_NAME --no-pager -l
        ;;
    
    logs)
        echo "📋 LCD reading service logs (Ctrl+C to exit):"
        sudo journalctl -u $SERVICE_NAME -f
        ;;
    
    enable)
        echo "✅ Enabling LCD reading service (auto-start on boot)..."
        sudo systemctl enable $SERVICE_NAME
        echo "✅ Service enabled"
        ;;
    
    disable)
        echo "❌ Disabling LCD reading service (no auto-start)..."
        sudo systemctl disable $SERVICE_NAME
        echo "✅ Service disabled"
        ;;
    
    test)
        echo "🧪 Testing LCD reading API..."
        echo ""
        echo "📍 Local endpoint:"
        curl -s http://localhost:9001/readings | python3 -m json.tool
        echo ""
        echo "📍 External endpoint:"
        LOCAL_IP=$(hostname -I | awk '{print $1}')
        echo "   http://${LOCAL_IP}:9001/readings"
        ;;
    
    *)
        echo "🏥 LCD Reading Service Manager"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start    - Start the service"
        echo "  stop     - Stop the service"
        echo "  restart  - Restart the service"
        echo "  status   - Show service status"
        echo "  logs     - Show live logs (Ctrl+C to exit)"
        echo "  enable   - Enable auto-start on boot"
        echo "  disable  - Disable auto-start on boot"
        echo "  test     - Test the API endpoint"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 logs"
        echo "  $0 test"
        ;;
esac
