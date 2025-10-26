#!/bin/bash
# Startup script to ensure all services start cleanly after Pi reboot

echo "🚀 Starting all incubator monitoring services..."

# Kill any stale processes
echo "🧹 Cleaning up stale processes..."
sudo pkill -9 -f nte_server.py 2>/dev/null
sudo pkill -9 -f cry_detector.py 2>/dev/null
sudo pkill -9 mjpg_streamer 2>/dev/null
sudo pkill -9 -f camera_server.py 2>/dev/null
sudo fuser -k 8080/tcp 8081/tcp 8886/tcp 8888/tcp 8889/tcp 2>/dev/null

sleep 3

# Start services in order
echo "📹 Starting camera server..."
sudo systemctl start camera-server
sleep 5

echo "🩺 Starting NTE server..."
sudo systemctl start nte-server
sleep 3

echo "👶 Starting cry detector..."
sudo systemctl start cry-detector
sleep 2

# Check status
echo ""
echo "✅ Service Status:"
echo "-------------------"
sudo systemctl is-active camera-server && echo "✓ Camera Server: Running" || echo "✗ Camera Server: Failed"
sudo systemctl is-active nte-server && echo "✓ NTE Server: Running" || echo "✗ NTE Server: Failed"
sudo systemctl is-active cry-detector && echo "✓ Cry Detector: Running" || echo "✗ Cry Detector: Failed"

echo ""
echo "🔌 Port Status:"
echo "-------------------"
netstat -tln | grep -E ':(8080|8081|8886|8888|8889)' || echo "No services listening"

echo ""
echo "✅ All services started!"
