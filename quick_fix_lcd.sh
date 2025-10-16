#!/bin/bash
# Quick Fix Script for LCD Reading Server
# This script deploys the fixed server and tests it
#
# Usage:
#   chmod +x quick_fix_lcd.sh
#   ./quick_fix_lcd.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}🔧 LCD Reading Server - Quick Fix${NC}"
echo -e "${BLUE}============================================${NC}"

# Configuration
PI_IP="100.99.151.101"
PI_USER="sahan"
MONITORING_DIR="/home/sahan/monitoring"
MODEL_DIR="$MONITORING_DIR/models"

echo ""
echo -e "${YELLOW}📋 This script will:${NC}"
echo "  1. Test SSH connection to Pi"
echo "  2. Identify correct camera device"
echo "  3. Transfer fixed LCD server"
echo "  4. Transfer ONNX model (if needed)"
echo "  5. Install dependencies"
echo "  6. Test camera capture"
echo "  7. Run server and test API"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Setup cancelled${NC}"
    exit 1
fi

# Step 1: Test SSH connection
echo ""
echo -e "${BLUE}Step 1: Testing SSH connection...${NC}"
if ssh -o ConnectTimeout=5 ${PI_USER}@${PI_IP} "echo 'SSH OK'" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ SSH connection successful${NC}"
else
    echo -e "${RED}❌ Cannot connect to Pi at ${PI_IP}${NC}"
    echo "   Please check:"
    echo "   - Pi is powered on"
    echo "   - Tailscale is running"
    echo "   - IP address is correct: ${PI_IP}"
    exit 1
fi

# Step 2: Identify camera devices
echo ""
echo -e "${BLUE}Step 2: Identifying camera devices...${NC}"
ssh ${PI_USER}@${PI_IP} << 'ENDSSH'
echo "📷 Available cameras:"
ls -la /dev/video* 2>/dev/null || echo "No cameras found"
echo ""
echo "📋 Camera details:"
for i in 0 1 2; do
    if [ -e "/dev/video$i" ]; then
        echo ""
        echo "Camera $i:"
        v4l2-ctl --device=/dev/video$i --info 2>/dev/null | grep -E "Card type|Driver name" || echo "  Info not available"
        
        # Test if camera can be opened
        python3 << EOF
import cv2
cap = cv2.VideoCapture($i)
if cap.isOpened():
    ret, frame = cap.read()
    if ret and frame is not None:
        print(f"  ✅ Can capture: {frame.shape[1]}x{frame.shape[0]}")
    else:
        print(f"  ⚠️  Opens but cannot read")
    cap.release()
else:
    print(f"  ❌ Cannot open")
EOF
    fi
done
ENDSSH

echo ""
echo -e "${YELLOW}Based on the output above:${NC}"
echo "1. USB 2.0 PC CAMERA should be video0 or video2 (NOT video1 - that's metadata)"
echo "2. Choose the camera that shows '✅ Can capture'"
echo ""
read -p "Which camera index for LCD display? (0, 1, or 2): " CAMERA_INDEX

if [[ ! $CAMERA_INDEX =~ ^[0-2]$ ]]; then
    echo -e "${RED}❌ Invalid camera index${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Using camera $CAMERA_INDEX${NC}"

# Step 3: Transfer fixed server
echo ""
echo -e "${BLUE}Step 3: Transferring fixed LCD server...${NC}"

# Update camera index in the fixed server
sed "s/LCD_CAMERA_INDEX = 0/LCD_CAMERA_INDEX = $CAMERA_INDEX/" lcd_reading_server_FIXED.py > /tmp/lcd_reading_server_temp.py

# Transfer to Pi
scp /tmp/lcd_reading_server_temp.py ${PI_USER}@${PI_IP}:${MONITORING_DIR}/lcd_reading_server.py
echo -e "${GREEN}✅ Server transferred${NC}"

# Clean up temp file
rm /tmp/lcd_reading_server_temp.py

# Step 4: Check/transfer ONNX model
echo ""
echo -e "${BLUE}Step 4: Checking ONNX model...${NC}"

MODEL_EXISTS=$(ssh ${PI_USER}@${PI_IP} "[ -f ${MODEL_DIR}/incubator_yolov8n.onnx ] && echo 'yes' || echo 'no'")

if [ "$MODEL_EXISTS" = "yes" ]; then
    echo -e "${GREEN}✅ ONNX model already on Pi${NC}"
else
    echo -e "${YELLOW}⚠️  ONNX model not found on Pi${NC}"
    
    if [ -f "lcd_ocr_readings/models/incubator_yolov8n.onnx" ]; then
        echo "📦 Transferring ONNX model..."
        ssh ${PI_USER}@${PI_IP} "mkdir -p ${MODEL_DIR}"
        scp lcd_ocr_readings/models/incubator_yolov8n.onnx ${PI_USER}@${PI_IP}:${MODEL_DIR}/
        echo -e "${GREEN}✅ ONNX model transferred${NC}"
    else
        echo -e "${RED}❌ ONNX model not found locally${NC}"
        echo "   Please run: python lcd_ocr_readings/convert_model_to_onnx.py"
        exit 1
    fi
fi

# Step 5: Install dependencies
echo ""
echo -e "${BLUE}Step 5: Installing dependencies...${NC}"
echo "   This may take 5-10 minutes..."

ssh ${PI_USER}@${PI_IP} << 'ENDSSH'
# Check if already installed
if python3 -c "import cv2, onnxruntime, easyocr" 2>/dev/null; then
    echo "✅ All packages already installed"
else
    echo "📦 Installing packages..."
    
    # Update pip
    pip3 install --upgrade pip --quiet
    
    # Install packages
    echo "  - Installing opencv-python-headless..."
    pip3 install opencv-python-headless --quiet
    
    echo "  - Installing onnxruntime..."
    pip3 install onnxruntime --quiet
    
    echo "  - Installing easyocr (this takes a while)..."
    pip3 install easyocr --quiet
    
    echo "✅ Packages installed"
fi

# Verify
python3 -c "import cv2; print('  ✅ OpenCV:', cv2.__version__)"
python3 -c "import onnxruntime; print('  ✅ ONNX Runtime:', onnxruntime.__version__)"
python3 -c "import easyocr; print('  ✅ EasyOCR: OK')"
ENDSSH

# Step 6: Test camera capture
echo ""
echo -e "${BLUE}Step 6: Testing camera capture...${NC}"

ssh ${PI_USER}@${PI_IP} << ENDSSH
cd ${MONITORING_DIR}
python3 << EOF
import cv2
import sys

print(f"Testing camera ${CAMERA_INDEX}...")
cap = cv2.VideoCapture(${CAMERA_INDEX})

if not cap.isOpened():
    print("❌ Cannot open camera ${CAMERA_INDEX}")
    sys.exit(1)

ret, frame = cap.read()
if not ret or frame is None:
    print("❌ Cannot read from camera ${CAMERA_INDEX}")
    cap.release()
    sys.exit(1)

print(f"✅ Camera ${CAMERA_INDEX} working!")
print(f"   Resolution: {frame.shape[1]}x{frame.shape[0]}")
print(f"   Channels: {frame.shape[2]}")

# Save test image
cv2.imwrite('${MONITORING_DIR}/test_camera.jpg', frame)
print(f"💾 Test image saved: ${MONITORING_DIR}/test_camera.jpg")

cap.release()
EOF
ENDSSH

# Step 7: Run server and test
echo ""
echo -e "${BLUE}Step 7: Running server and testing API...${NC}"
echo ""
echo -e "${YELLOW}Starting server in background...${NC}"

# Stop existing service if running
ssh ${PI_USER}@${PI_IP} "sudo systemctl stop lcd-reading.service 2>/dev/null || true"

# Start server in background
ssh ${PI_USER}@${PI_IP} "cd ${MONITORING_DIR} && nohup python3 lcd_reading_server.py > lcd_server.log 2>&1 &"

echo "⏳ Waiting 10 seconds for server to start..."
sleep 10

# Test API
echo ""
echo -e "${BLUE}Testing API endpoints...${NC}"

# Test root endpoint
echo ""
echo -e "${YELLOW}1. Testing API info endpoint...${NC}"
ssh ${PI_USER}@${PI_IP} "curl -s http://localhost:9001/ | head -20" || echo "❌ Failed"

# Test readings endpoint
echo ""
echo -e "${YELLOW}2. Testing readings endpoint...${NC}"
ssh ${PI_USER}@${PI_IP} "curl -s http://localhost:9001/readings | head -20" || echo "❌ Failed"

# Test capture endpoint
echo ""
echo -e "${YELLOW}3. Testing capture endpoint (this may take 5-10 seconds)...${NC}"
ssh ${PI_USER}@${PI_IP} "curl -s http://localhost:9001/capture | head -30" || echo "❌ Failed"

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Server Logs (last 30 lines):${NC}"
echo -e "${BLUE}============================================${NC}"
ssh ${PI_USER}@${PI_IP} "tail -30 ${MONITORING_DIR}/lcd_server.log"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Review the logs above for errors"
echo "2. If successful, enable service:"
echo "   ssh ${PI_USER}@${PI_IP}"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl restart lcd-reading.service"
echo "   sudo systemctl status lcd-reading.service"
echo ""
echo "3. Test from your PC:"
echo "   curl http://${PI_IP}:9001/readings"
echo ""
echo "4. Open dashboard:"
echo "   http://${PI_IP}/index.html"
echo ""
echo "5. Download test camera image:"
echo "   scp ${PI_USER}@${PI_IP}:${MONITORING_DIR}/test_camera.jpg ."
echo "   (Check if LCD display is visible)"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "- View live logs: ssh ${PI_USER}@${PI_IP} 'tail -f ${MONITORING_DIR}/lcd_server.log'"
echo "- View service logs: ssh ${PI_USER}@${PI_IP} 'sudo journalctl -u lcd-reading.service -f'"
echo "- Debug endpoint: curl http://${PI_IP}:9001/debug"
echo ""
echo -e "${GREEN}Done!${NC}"
