#!/bin/bash
# Cry Detection Setup Script for Raspberry Pi
# This script installs dependencies and sets up the cry detection system

echo "🍼 Setting up Cry Detection System on Raspberry Pi"
echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="

# Update system
echo "📦 Updating system packages..."
sudo apt update

# Install audio dependencies
echo "🎤 Installing audio dependencies..."
sudo apt install -y python3-pyaudio python3-numpy python3-scipy portaudio19-dev

# Install additional Python packages (with fallback options)
echo "🐍 Installing Python packages..."

# Try system packages first
sudo apt install -y python3-librosa python3-soundfile

# If system packages aren't available, use pip with break-system-packages
if ! python3 -c "import librosa" 2>/dev/null; then
    echo "📝 System packages not available, using pip..."
    pip3 install librosa soundfile --break-system-packages
fi

# Test audio setup
echo "🔧 Testing audio setup..."
python3 -c "
import pyaudio
import numpy as np
print('✅ PyAudio working')
print('✅ NumPy working')

# List audio devices
p = pyaudio.PyAudio()
print(f'🎤 Found {p.get_device_count()} audio devices:')
for i in range(p.get_device_count()):
    info = p.get_device_info_by_index(i)
    if info['maxInputChannels'] > 0:
        print(f'  📍 Device {i}: {info[\"name\"]} (Input: {info[\"maxInputChannels\"]} channels)')
p.terminate()
"

# Create systemd service for cry detection
echo "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/cry-detector.service > /dev/null <<EOF
[Unit]
Description=Baby Cry Detection Service
After=network.target sound.target

[Service]
Type=simple
User=pi
Group=audio
WorkingDirectory=/home/pi
ExecStart=/usr/bin/python3 /home/pi/cry_detector.py
Restart=always
RestartSec=10
Environment=PULSE_RUNTIME_PATH=/run/user/1000/pulse

[Install]
WantedBy=multi-user.target
EOF

# Add pi user to audio group
echo "👤 Adding pi user to audio group..."
sudo usermod -a -G audio sahan

echo ""
echo "✅ Cry Detection Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Copy cry_detector.py to your Pi: scp cry_detector.py pi@your-pi-ip:/home/pi/"
echo "2. Run manually: python3 cry_detector.py"
echo "3. Or enable service: sudo systemctl enable cry-detector && sudo systemctl start cry-detector"
echo ""
echo "🌐 API will be available at: http://your-pi-ip:8888"
echo "📊 Status endpoint: http://your-pi-ip:8888/cry/status"
echo ""
echo "🎤 Make sure you have a microphone connected to your Pi!"
echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="
