#!/bin/bash
# Simple Pi Monitoring System Setup
# One-time setup script for all monitoring services

echo "🚀 Pi Monitoring System - Simple Setup"
echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="

# Update system and install dependencies
echo "📦 Installing dependencies..."
sudo apt update
sudo apt install -y python3 python3-pip mjpg-streamer v4l-utils curl netstat-nat
sudo apt install -y python3-pyaudio portaudio19-dev

# Install Python packages
echo "🐍 Installing Python packages..."
pip3 install requests --break-system-packages
pip3 install pyaudio --break-system-packages 2>/dev/null || echo "PyAudio already installed"

# Add user to required groups
echo "👤 Setting up user permissions..."
sudo usermod -a -G audio,video sahan

# Create service files
echo "🔧 Creating service files..."

# Health Server Service
sudo tee /etc/systemd/system/pi-health-server.service > /dev/null <<EOF
[Unit]
Description=Pi Health Monitoring Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=sahan
ExecStart=/usr/bin/python3 /home/sahan/simple_health_server.py
Restart=always
RestartSec=10
WorkingDirectory=/home/sahan

[Install]
WantedBy=multi-user.target
EOF

# Cry Detector Service
sudo tee /etc/systemd/system/pi-cry-detector.service > /dev/null <<EOF
[Unit]
Description=Baby Cry Detection Service
After=network.target sound.target
Wants=network.target

[Service]
Type=simple
User=sahan
ExecStart=/usr/bin/python3 /home/sahan/cry_detector.py
Restart=always
RestartSec=10
WorkingDirectory=/home/sahan

[Install]
WantedBy=multi-user.target
EOF

# Camera Server Service
sudo tee /etc/systemd/system/pi-camera-server.service > /dev/null <<EOF
[Unit]
Description=Camera Streaming Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=sahan
ExecStart=/usr/bin/python3 /home/sahan/camera_server.py
Restart=always
RestartSec=10
WorkingDirectory=/home/sahan

[Install]
WantedBy=multi-user.target
EOF

# Find mjpg_streamer path
MJPG_STREAMER_PATH="/usr/local/bin/mjpg_streamer"
if [ ! -f "$MJPG_STREAMER_PATH" ]; then
    if [ -f "/usr/bin/mjpg_streamer" ]; then
        MJPG_STREAMER_PATH="/usr/bin/mjpg_streamer"
    elif command -v mjpg_streamer >/dev/null 2>&1; then
        MJPG_STREAMER_PATH=$(which mjpg_streamer)
    fi
fi

echo "📍 Using mjpg_streamer at: $MJPG_STREAMER_PATH"

# Camera 1 Stream Service (Infant - /dev/video0 -> Port 8080)
sudo tee /etc/systemd/system/pi-camera1-stream.service > /dev/null <<EOF
[Unit]
Description=Pi Camera 1 Live Stream (Infant)
After=network.target
Wants=network.target

[Service]
Type=simple
User=sahan
ExecStart=$MJPG_STREAMER_PATH -i "input_uvc.so -d /dev/video0 -r 640x480 -f 30" -o "output_http.so -p 8080 -w /usr/local/share/mjpg-streamer/www"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Camera 2 Stream Service (LCD Reader - /dev/video2 -> Port 8081)  
sudo tee /etc/systemd/system/pi-camera2-stream.service > /dev/null <<EOF
[Unit]
Description=Pi Camera 2 LCD Reader Stream
After=network.target
Wants=network.target

[Service]
Type=simple
User=sahan
ExecStart=$MJPG_STREAMER_PATH -i "input_uvc.so -d /dev/video2 -r 640x480 -f 30" -o "output_http.so -p 8081 -w /usr/local/share/mjpg-streamer/www"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable services
echo "🔄 Enabling services..."
sudo systemctl daemon-reload

# Enable all services for autostart
sudo systemctl enable pi-health-server pi-cry-detector pi-camera-server pi-camera1-stream pi-camera2-stream

# Start all services
echo "▶️ Starting all services..."
sudo systemctl start pi-health-server pi-cry-detector pi-camera-server pi-camera1-stream pi-camera2-stream

# Wait for services to start
echo "⏳ Waiting for services to initialize..."
sleep 5

# Check status
echo ""
echo "📊 Setup Complete! Checking service status..."
./manage_services.sh status

echo ""
echo "✅ Pi Monitoring System Setup Complete!"
echo ""
echo "🌐 Access your dashboard at: http://192.168.8.137/index.html"
echo ""
echo "🔧 Service Management:"
echo "  ./manage_services.sh status    # Check all services"
echo "  ./manage_services.sh restart   # Restart all services"
echo "  ./manage_services.sh stop      # Stop all services"
echo "  ./manage_services.sh start     # Start all services"
echo ""
echo "🎯 All services will start automatically on Pi boot!"
