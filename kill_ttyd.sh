#!/bin/bash
"""
Kill ttyd processes and restart clean
Fixes port binding issues with ttyd.
"""

echo "🔧 Fixing ttyd port binding issue..."
echo "=" * 50

# Check what's using port 7681
echo "🔍 Checking what's using port 7681..."
sudo netstat -tulpn | grep :7681 || echo "No process found on port 7681"
sudo ss -tulpn | grep :7681 || echo "No process found on port 7681 (ss)"

# Kill any existing ttyd processes
echo "🔪 Killing existing ttyd processes..."
sudo pkill -f ttyd || echo "No ttyd processes found"

# Stop the service
echo "⏹️ Stopping ttyd service..."
sudo systemctl stop ttyd.service

# Wait a moment
echo "⏳ Waiting for cleanup..."
sleep 3

# Check if port is free now
echo "🔍 Checking port 7681 again..."
if sudo netstat -tulpn | grep :7681; then
    echo "❌ Port still in use. Finding and killing process..."
    PORT_PID=$(sudo netstat -tulpn | grep :7681 | awk '{print $7}' | cut -d'/' -f1)
    if [ ! -z "$PORT_PID" ]; then
        echo "🔪 Killing process $PORT_PID"
        sudo kill -9 $PORT_PID
        sleep 2
    fi
else
    echo "✅ Port 7681 is now free"
fi

# Get current username
CURRENT_USER=$(whoami)
echo "👤 Current user: $CURRENT_USER"

# Try manual start first
echo "🚀 Starting ttyd manually..."
echo "📍 Command: ttyd -p 7681 -i 0.0.0.0 --writable bash"
echo "🌐 URL: http://$(hostname -I | awk '{print $1}'):7681"
echo ""
echo "⚠️ If this works, press Ctrl+C to stop it, then run the service"
echo "📱 Test in your dashboard while this is running!"
echo ""
echo "Starting in 3 seconds..."
sleep 3

# Start ttyd manually
ttyd -p 7681 -i 0.0.0.0 --writable bash
