#!/bin/bash
#
# Setup script for LCD Reading Server on Raspberry Pi
# This script installs dependencies and configures the service
#
# Usage:
#   chmod +x setup_lcd_reading.sh
#   ./setup_lcd_reading.sh
#

set -e  # Exit on error

echo "============================================"
echo "🏥 LCD Reading Server Setup"
echo "============================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MONITORING_DIR="/home/sahan/monitoring"
MODEL_DIR="$MONITORING_DIR/models"
SERVICE_FILE="/etc/systemd/system/lcd-reading.service"

echo ""
echo "📋 This script will:"
echo "  1. Create monitoring directories"
echo "  2. Install Python dependencies"
echo "  3. Configure systemd service"
echo "  4. Test camera access"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Setup cancelled"
    exit 1
fi

# Step 1: Create directories
echo ""
echo "📁 Creating directories..."
mkdir -p "$MONITORING_DIR"
mkdir -p "$MODEL_DIR"
echo "✅ Directories created"

# Step 2: Check if files are transferred
echo ""
echo "📦 Checking for required files..."

if [ ! -f "$MONITORING_DIR/lcd_reading_server.py" ]; then
    echo -e "${RED}❌ Error: lcd_reading_server.py not found${NC}"
    echo "   Please transfer the file first:"
    echo "   scp lcd_reading_server.py sahan@192.168.8.137:/home/sahan/monitoring/"
    exit 1
fi
echo "✅ lcd_reading_server.py found"

if [ ! -f "$MODEL_DIR/incubator_yolov8n.onnx" ]; then
    echo -e "${YELLOW}⚠️  Warning: incubator_yolov8n.onnx not found${NC}"
    echo "   Please transfer the ONNX model:"
    echo "   scp lcd_ocr_readings/models/incubator_yolov8n.onnx sahan@192.168.8.137:/home/sahan/monitoring/models/"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ ONNX model found"
fi

# Step 3: Install system dependencies
echo ""
echo "📦 Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y python3-pip libgl1-mesa-glx libglib2.0-0
echo "✅ System dependencies installed"

# Step 4: Install Python packages
echo ""
echo "🐍 Installing Python packages..."
echo "   This may take 5-10 minutes..."

pip3 install --upgrade pip > /dev/null 2>&1

# Install packages one by one for better error handling
echo "   - Installing numpy..."
pip3 install numpy --no-warn-script-location

echo "   - Installing opencv-python-headless..."
pip3 install opencv-python-headless --no-warn-script-location

echo "   - Installing onnxruntime..."
pip3 install onnxruntime --no-warn-script-location

echo "   - Installing easyocr (this may take a while)..."
pip3 install easyocr --no-warn-script-location

echo "✅ Python packages installed"

# Step 5: Test installations
echo ""
echo "🧪 Testing installations..."

python3 -c "import cv2; print('  ✅ OpenCV:', cv2.__version__)" || {
    echo -e "${RED}  ❌ OpenCV import failed${NC}"
    exit 1
}

python3 -c "import numpy; print('  ✅ NumPy:', numpy.__version__)" || {
    echo -e "${RED}  ❌ NumPy import failed${NC}"
    exit 1
}

python3 -c "import onnxruntime as ort; print('  ✅ ONNX Runtime:', ort.__version__)" || {
    echo -e "${RED}  ❌ ONNX Runtime import failed${NC}"
    exit 1
}

python3 -c "import easyocr; print('  ✅ EasyOCR: OK')" || {
    echo -e "${RED}  ❌ EasyOCR import failed${NC}"
    exit 1
}

echo "✅ All packages working"

# Step 6: Test camera
echo ""
echo "📷 Testing camera access..."
python3 -c "
import cv2
import sys

# Test cameras 0, 1, 2
for i in range(3):
    cap = cv2.VideoCapture(i)
    if cap.isOpened():
        ret, frame = cap.read()
        if ret:
            print(f'  ✅ Camera {i} working (resolution: {frame.shape[1]}x{frame.shape[0]})')
        else:
            print(f'  ⚠️  Camera {i} opened but can\\'t read frame')
        cap.release()
    else:
        print(f'  ℹ️  Camera {i} not available')
" || {
    echo -e "${RED}  ❌ Camera test failed${NC}"
    exit 1
}

# Step 7: Create systemd service
echo ""
echo "⚙️  Creating systemd service..."

sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=LCD Reading Server
After=network.target

[Service]
Type=simple
User=sahan
WorkingDirectory=$MONITORING_DIR
ExecStart=/usr/bin/python3 $MONITORING_DIR/lcd_reading_server.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Service file created"

# Step 8: Enable and start service
echo ""
echo "🚀 Configuring service..."

sudo systemctl daemon-reload
sudo systemctl enable lcd-reading.service
echo "✅ Service enabled (will start on boot)"

# Ask if user wants to start now
echo ""
read -p "Start the service now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo systemctl start lcd-reading.service
    sleep 2
    
    # Check status
    if sudo systemctl is-active --quiet lcd-reading.service; then
        echo -e "${GREEN}✅ Service started successfully${NC}"
        echo ""
        echo "📊 Service information:"
        sudo systemctl status lcd-reading.service --no-pager -l | head -n 10
    else
        echo -e "${RED}❌ Service failed to start${NC}"
        echo "Check logs with: sudo journalctl -u lcd-reading.service -n 50"
        exit 1
    fi
fi

# Step 9: Final instructions
echo ""
echo "============================================"
echo "✅ Setup Complete!"
echo "============================================"
echo ""
echo "🎯 Next steps:"
echo ""
echo "1. Test the API:"
echo "   curl http://localhost:9001/readings"
echo ""
echo "2. View logs:"
echo "   sudo journalctl -u lcd-reading.service -f"
echo ""
echo "3. Service commands:"
echo "   sudo systemctl start lcd-reading.service"
echo "   sudo systemctl stop lcd-reading.service"
echo "   sudo systemctl restart lcd-reading.service"
echo "   sudo systemctl status lcd-reading.service"
echo ""
echo "4. Access from external:"
echo "   http://$(hostname -I | awk '{print $1}'):9001/readings"
echo ""
echo "5. Update dashboard:"
echo "   Add the LCD section to index.html"
echo "   See: dashboard_lcd_section.html"
echo ""
echo "============================================"
