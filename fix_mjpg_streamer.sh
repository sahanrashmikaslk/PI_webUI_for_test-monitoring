#!/bin/bash
# Fix mjpg_streamer installation and camera services
# This script resolves the "No such file or directory" error

echo "🔧 Fixing mjpg_streamer installation and camera services"
echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="

# Function to install mjpg_streamer properly
install_mjpg_streamer() {
    echo "📦 Installing mjpg_streamer..."
    
    # Update package list
    sudo apt update
    
    # Install dependencies
    sudo apt install -y cmake libjpeg8-dev gcc g++ make
    
    # Try package installation first
    if sudo apt install -y mjpg-streamer; then
        echo "✅ mjpg_streamer installed via package manager"
        return 0
    fi
    
    # If package fails, compile from source
    echo "📥 Package installation failed, compiling from source..."
    
    cd /tmp
    
    # Clone mjpg-streamer repository
    if [ ! -d "mjpg-streamer" ]; then
        git clone https://github.com/jacksonliam/mjpg-streamer.git
    fi
    
    cd mjpg-streamer/mjpg-streamer-experimental
    
    # Build
    make CMAKE_BUILD_TYPE=Release
    
    # Install
    sudo make install
    
    # Create symlink if needed
    if [ ! -f "/usr/local/bin/mjpg_streamer" ] && [ -f "./mjpg_streamer" ]; then
        sudo cp mjpg_streamer /usr/local/bin/
        sudo chmod +x /usr/local/bin/mjpg_streamer
    fi
    
    cd ~
    echo "✅ mjpg_streamer compiled and installed"
}

# Check if mjpg_streamer exists
echo "🔍 Checking mjpg_streamer installation..."

MJPG_STREAMER_PATH=""

# Check common locations
if [ -f "/usr/local/bin/mjpg_streamer" ]; then
    MJPG_STREAMER_PATH="/usr/local/bin/mjpg_streamer"
    echo "✅ Found mjpg_streamer at: $MJPG_STREAMER_PATH"
elif [ -f "/usr/bin/mjpg_streamer" ]; then
    MJPG_STREAMER_PATH="/usr/bin/mjpg_streamer"
    echo "✅ Found mjpg_streamer at: $MJPG_STREAMER_PATH"
elif command -v mjpg_streamer >/dev/null 2>&1; then
    MJPG_STREAMER_PATH=$(which mjpg_streamer)
    echo "✅ Found mjpg_streamer at: $MJPG_STREAMER_PATH"
else
    echo "❌ mjpg_streamer not found - installing..."
    install_mjpg_streamer
    
    # Check again after installation
    if command -v mjpg_streamer >/dev/null 2>&1; then
        MJPG_STREAMER_PATH=$(which mjpg_streamer)
        echo "✅ mjpg_streamer now available at: $MJPG_STREAMER_PATH"
    else
        echo "❌ Failed to install mjpg_streamer"
        exit 1
    fi
fi

# Test mjpg_streamer
echo "🧪 Testing mjpg_streamer..."
if $MJPG_STREAMER_PATH --help >/dev/null 2>&1; then
    echo "✅ mjpg_streamer is working"
else
    echo "❌ mjpg_streamer test failed"
fi

# Check camera devices
echo "📷 Checking camera devices..."
if [ -e "/dev/video0" ]; then
    echo "✅ /dev/video0 exists (Camera 1)"
else
    echo "❌ /dev/video0 not found (Camera 1)"
fi

if [ -e "/dev/video2" ]; then
    echo "✅ /dev/video2 exists (Camera 2)"
else
    echo "❌ /dev/video2 not found (Camera 2)"
fi

# Update systemd services with correct path
echo "🔧 Updating systemd services with correct path..."

# Camera 1 service
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

# Camera 2 service
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

echo "✅ Services updated with correct mjpg_streamer path"

# Fix permissions
echo "🔒 Fixing permissions..."
sudo usermod -a -G video,audio sahan

# Set up udev rules
sudo tee /etc/udev/rules.d/99-camera.rules > /dev/null <<EOF
SUBSYSTEM=="video4linux", GROUP="video", MODE="0664"
KERNEL=="video[0-9]*", GROUP="video", MODE="0664"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

echo "✅ Permissions fixed"

# Reload systemd
echo "🔄 Reloading systemd..."
sudo systemctl daemon-reload

# Enable services
echo "⚙️ Enabling camera services..."
sudo systemctl enable pi-camera1-stream
sudo systemctl enable pi-camera2-stream

# Stop any existing services
echo "⏹️ Stopping existing camera services..."
sudo systemctl stop pi-camera1-stream 2>/dev/null
sudo systemctl stop pi-camera2-stream 2>/dev/null

# Start services
echo "▶️ Starting camera services..."
sudo systemctl start pi-camera1-stream
sudo systemctl start pi-camera2-stream

# Wait and check status
sleep 3

echo ""
echo "📊 Camera Service Status:"
echo "Camera 1 (video0:8080):"
systemctl status pi-camera1-stream --no-pager -l

echo ""
echo "Camera 2 (video2:8081):"
systemctl status pi-camera2-stream --no-pager -l

echo ""
echo "🌐 Testing camera streams..."

# Test Camera 1
if curl -s --connect-timeout 3 http://localhost:8080 >/dev/null 2>&1; then
    echo "✅ Camera 1 stream accessible at http://localhost:8080"
else
    echo "❌ Camera 1 stream not accessible"
fi

# Test Camera 2
if curl -s --connect-timeout 3 http://localhost:8081 >/dev/null 2>&1; then
    echo "✅ Camera 2 stream accessible at http://localhost:8081"
else
    echo "❌ Camera 2 stream not accessible"
fi

echo ""
echo "🎯 Camera URLs:"
echo "  Camera 1: http://192.168.8.137:8080/?action=stream"
echo "  Camera 2: http://192.168.8.137:8081/?action=stream"
echo ""
echo "🔧 If cameras still don't work, check:"
echo "  sudo journalctl -u pi-camera1-stream -f"
echo "  sudo journalctl -u pi-camera2-stream -f"
echo ""
echo "✅ mjpg_streamer fix completed!"
