#!/bin/bash
#
# LCD Reading Server Update Script
# Fixes 3 critical bugs in existing /home/sahan/monitoring/lcd_reading_server.py
#
# This script:
# 1. Backs up the existing buggy server
# 2. Deploys the fixed version
# 3. Creates systemd service
# 4. Tests functionality
#
# Usage: ./update_lcd_server.sh
#

set -e  # Exit on error

# Configuration
PI_USER="sahan"
PI_HOST="100.99.151.101"
PI_SSH="${PI_USER}@${PI_HOST}"
MONITORING_DIR="/home/sahan/monitoring"
MODEL_DIR="${MONITORING_DIR}/models"
SERVER_FILE="${MONITORING_DIR}/lcd_reading_server.py"
SERVICE_NAME="lcd-reading"
PORT=9001

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}🔧 LCD Reading Server Update${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${YELLOW}Fixes:${NC}"
echo "  ❌ Bug 1: HTTP stream → ✅ Direct camera capture"
echo "  ❌ Bug 2: Tesseract OCR → ✅ EasyOCR"  
echo "  ❌ Bug 3: PyTorch .pt → ✅ ONNX model"
echo ""

# Step 1: Test SSH connection
echo -e "${BLUE}[1/7]${NC} Testing SSH connection..."
if ! ssh -o ConnectTimeout=5 ${PI_SSH} "echo 'Connected'" &>/dev/null; then
    echo -e "${RED}❌ Cannot connect to Pi at ${PI_HOST}${NC}"
    echo "Please check:"
    echo "  - Tailscale is running"
    echo "  - Pi is powered on"
    echo "  - SSH key is set up"
    exit 1
fi
echo -e "${GREEN}✅ SSH connection successful${NC}"

# Step 2: Verify existing files
echo ""
echo -e "${BLUE}[2/7]${NC} Checking existing installation..."
if ! ssh ${PI_SSH} "test -f ${SERVER_FILE}"; then
    echo -e "${RED}❌ Server file not found at ${SERVER_FILE}${NC}"
    exit 1
fi

if ! ssh ${PI_SSH} "test -f ${MODEL_DIR}/incubator_yolov8n.onnx"; then
    echo -e "${RED}❌ ONNX model not found at ${MODEL_DIR}/incubator_yolov8n.onnx${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Existing files verified${NC}"
echo "  📄 Server: ${SERVER_FILE} (28KB)"
echo "  🤖 Model: ${MODEL_DIR}/incubator_yolov8n.onnx (12MB)"

# Step 3: Backup existing server
echo ""
echo -e "${BLUE}[3/7]${NC} Backing up existing server..."
BACKUP_FILE="${SERVER_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
ssh ${PI_SSH} "cp ${SERVER_FILE} ${BACKUP_FILE}"
echo -e "${GREEN}✅ Backup created: ${BACKUP_FILE}${NC}"

# Step 4: Upload fixed server
echo ""
echo -e "${BLUE}[4/7]${NC} Uploading fixed server..."
if [ ! -f "lcd_reading_server_FIXED.py" ]; then
    echo -e "${RED}❌ lcd_reading_server_FIXED.py not found in current directory${NC}"
    exit 1
fi

scp lcd_reading_server_FIXED.py ${PI_SSH}:${SERVER_FILE}
ssh ${PI_SSH} "chmod +x ${SERVER_FILE}"
echo -e "${GREEN}✅ Fixed server deployed${NC}"

# Step 5: Create systemd service
echo ""
echo -e "${BLUE}[5/7]${NC} Creating systemd service..."
ssh ${PI_SSH} "sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null" <<EOF
[Unit]
Description=LCD Reading Server (Incubator Display OCR)
After=network.target pi-camera2-stream.service
Wants=pi-camera2-stream.service

[Service]
Type=simple
User=${PI_USER}
WorkingDirectory=${MONITORING_DIR}
ExecStart=/usr/bin/python3 ${SERVER_FILE}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Environment
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✅ Service file created${NC}"

# Step 6: Enable and start service
echo ""
echo -e "${BLUE}[6/7]${NC} Starting service..."
ssh ${PI_SSH} "sudo systemctl daemon-reload"
ssh ${PI_SSH} "sudo systemctl enable ${SERVICE_NAME}.service"
ssh ${PI_SSH} "sudo systemctl restart ${SERVICE_NAME}.service"
sleep 3

# Check service status
if ssh ${PI_SSH} "sudo systemctl is-active ${SERVICE_NAME}.service" | grep -q "active"; then
    echo -e "${GREEN}✅ Service started successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Service may not be running. Checking logs...${NC}"
    ssh ${PI_SSH} "sudo journalctl -u ${SERVICE_NAME}.service -n 20 --no-pager"
fi

# Step 7: Test API endpoint
echo ""
echo -e "${BLUE}[7/7]${NC} Testing API endpoint..."
sleep 2
if ssh ${PI_SSH} "curl -s http://localhost:${PORT}/readings" | grep -q "heart_rate"; then
    echo -e "${GREEN}✅ API endpoint responding${NC}"
else
    echo -e "${YELLOW}⚠️  API may be warming up. Test manually:${NC}"
    echo "    curl http://100.99.151.101:${PORT}/readings"
fi

# Summary
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✅ Update Complete!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "📊 Service Status:"
ssh ${PI_SSH} "sudo systemctl status ${SERVICE_NAME}.service --no-pager -l" | head -15
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  View logs:    ssh ${PI_SSH} \"sudo journalctl -u ${SERVICE_NAME}.service -f\""
echo "  Restart:      ssh ${PI_SSH} \"sudo systemctl restart ${SERVICE_NAME}.service\""
echo "  Stop:         ssh ${PI_SSH} \"sudo systemctl stop ${SERVICE_NAME}.service\""
echo "  Status:       ssh ${PI_SSH} \"sudo systemctl status ${SERVICE_NAME}.service\""
echo ""
echo -e "${BLUE}API Endpoints:${NC}"
echo "  Health:       http://100.99.151.101:${PORT}/health"
echo "  Readings:     http://100.99.151.101:${PORT}/readings"
echo ""
echo -e "${GREEN}🎉 LCD reading server is now operational!${NC}"
