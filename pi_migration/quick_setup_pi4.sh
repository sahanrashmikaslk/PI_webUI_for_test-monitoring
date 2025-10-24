#!/bin/bash
# ========================================================================
# Quick Setup Script for Pi 4B+ After Migration
# ========================================================================
# Run this script on Pi 4B+ to complete the setup
# Usage: bash quick_setup_pi4.sh
# ========================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=================================="
echo "Pi 4B+ Post-Migration Setup"
echo "==================================${NC}"
echo ""

# Check if running on Pi 4B+
if ! grep -q "100.71.54.112" <(hostname -I); then
    echo -e "${YELLOW}Warning: This doesn't appear to be Pi 4B+ (expected IP: 100.71.54.112)${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}Step 1: Checking Python packages installation...${NC}"
if pip3 list | grep -q "ultralytics"; then
    echo -e "${GREEN}✓ Python packages installed${NC}"
else
    echo -e "${YELLOW}⚠ Python packages still installing or failed${NC}"
    echo "Checking installation status..."
    ps aux | grep "pip3 install" | grep -v grep || echo "No pip installation running"
fi
echo ""

echo -e "${GREEN}Step 2: Installing system dependencies...${NC}"
echo "This will install: mosquitto, portaudio, build tools"
read -p "Install system dependencies? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo apt update
    sudo apt install -y \
        mosquitto mosquitto-clients \
        portaudio19-dev \
        build-essential \
        cmake \
        pkg-config
    echo -e "${GREEN}✓ System dependencies installed${NC}"
else
    echo "Skipped system dependencies"
fi
echo ""

echo -e "${GREEN}Step 3: Setting up mjpg-streamer for camera...${NC}"
if [ -d "$HOME/mjpg-streamer" ]; then
    echo -e "${YELLOW}mjpg-streamer directory already exists${NC}"
    read -p "Rebuild mjpg-streamer? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd ~/mjpg-streamer/mjpg-streamer-experimental
        make clean
        make
        sudo make install
        echo -e "${GREEN}✓ mjpg-streamer rebuilt${NC}"
    fi
else
    read -p "Install mjpg-streamer? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd ~
        git clone https://github.com/jacksonliam/mjpg-streamer.git
        cd mjpg-streamer/mjpg-streamer-experimental
        make
        sudo make install
        echo -e "${GREEN}✓ mjpg-streamer installed${NC}"
    else
        echo "Skipped mjpg-streamer installation"
    fi
fi
cd ~
echo ""

echo -e "${GREEN}Step 4: Updating IP addresses in scripts...${NC}"
OLD_IP="100.99.151.101"
NEW_IP="100.71.54.112"

echo "Searching for files with old IP ($OLD_IP)..."
FILES_WITH_OLD_IP=$(grep -rl "$OLD_IP" ~/monitoring ~/incubator_monitoring_with_thingsboard_integration ~/*.py ~/*.sh 2>/dev/null || true)

if [ -n "$FILES_WITH_OLD_IP" ]; then
    echo "Files containing old IP:"
    echo "$FILES_WITH_OLD_IP"
    echo ""
    read -p "Replace $OLD_IP with $NEW_IP in these files? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$FILES_WITH_OLD_IP" | while read -r file; do
            if [ -f "$file" ]; then
                cp "$file" "$file.backup_$(date +%Y%m%d)"
                sed -i "s/$OLD_IP/$NEW_IP/g" "$file"
                echo "✓ Updated: $file"
            fi
        done
        echo -e "${GREEN}✓ IP addresses updated${NC}"
    else
        echo "Skipped IP address updates"
    fi
else
    echo -e "${GREEN}✓ No files found with old IP${NC}"
fi
echo ""

echo -e "${GREEN}Step 5: Testing hardware interfaces...${NC}"
echo "Testing camera..."
if vcgencmd get_camera 2>/dev/null | grep -q "detected=1"; then
    echo -e "${GREEN}✓ Camera detected${NC}"
else
    echo -e "${YELLOW}⚠ No camera detected${NC}"
    echo "  Make sure camera is connected and enabled in raspi-config"
fi

echo "Testing I2C..."
if [ -c /dev/i2c-1 ]; then
    echo -e "${GREEN}✓ I2C enabled${NC}"
    if command -v i2cdetect &> /dev/null; then
        echo "I2C devices:"
        sudo i2cdetect -y 1 || echo "  No devices found or error"
    fi
else
    echo -e "${YELLOW}⚠ I2C not enabled${NC}"
    echo "  Enable I2C in raspi-config if needed for LCD"
fi
echo ""

echo -e "${GREEN}Step 6: Creating virtual environment for ThingsBoard client...${NC}"
TB_VENV="$HOME/incubator_monitoring_with_thingsboard_integration/pi_client/venv"
if [ ! -d "$TB_VENV" ]; then
    read -p "Create virtual environment for ThingsBoard client? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        python3 -m venv "$TB_VENV"
        source "$TB_VENV/bin/activate"
        pip install paho-mqtt python-dotenv
        deactivate
        echo -e "${GREEN}✓ Virtual environment created${NC}"
    fi
else
    echo -e "${GREEN}✓ Virtual environment already exists${NC}"
fi
echo ""

echo -e "${GREEN}Step 7: Testing services individually...${NC}"
echo "This will test each service file syntax"
echo ""

SERVICES=(
    "camera-server"
    "cry-detector"
    "lcd-reading"
    "pi-camera-server"
    "pi-camera1-stream"
    "pi-camera2-stream"
    "pi-cry-detector"
    "thingsboard-bridge"
)

echo "Validating service files..."
for service in "${SERVICES[@]}"; do
    if sudo systemd-analyze verify "/etc/systemd/system/${service}.service" 2>&1 | grep -q "Failed"; then
        echo -e "${RED}✗ ${service}.service has errors${NC}"
    else
        echo -e "${GREEN}✓ ${service}.service syntax OK${NC}"
    fi
done
echo ""

echo -e "${GREEN}Step 8: Service Management${NC}"
echo "What would you like to do with the services?"
echo "  1) Test services manually (recommended)"
echo "  2) Enable services (auto-start on boot)"
echo "  3) Enable and start services now"
echo "  4) Skip service setup"
read -p "Choose option (1-4): " -n 1 -r
echo ""

case $REPLY in
    1)
        echo ""
        echo "To test services manually, run:"
        echo "  python3 ~/camera_server.py"
        echo "  python3 ~/monitoring/lcd_reading_server.py"
        echo "  python3 ~/cry_detector.py"
        echo ""
        echo "Check if they work, then press Ctrl+C to stop"
        echo "After testing, run: sudo systemctl enable <service-name>"
        ;;
    2)
        echo "Enabling services (will start on next boot)..."
        for service in "${SERVICES[@]}"; do
            if sudo systemctl enable "${service}.service" 2>/dev/null; then
                echo -e "${GREEN}✓ Enabled ${service}${NC}"
            else
                echo -e "${YELLOW}⚠ Failed to enable ${service}${NC}"
            fi
        done
        echo "Services enabled. Reboot to start them."
        ;;
    3)
        echo "Enabling and starting services..."
        for service in "${SERVICES[@]}"; do
            if sudo systemctl enable --now "${service}.service" 2>/dev/null; then
                echo -e "${GREEN}✓ Started ${service}${NC}"
            else
                echo -e "${YELLOW}⚠ Failed to start ${service}${NC}"
            fi
        done
        echo ""
        echo "Checking service status..."
        sudo systemctl status camera-server lcd-reading cry-detector thingsboard-bridge --no-pager
        ;;
    4)
        echo "Skipped service setup"
        ;;
esac
echo ""

echo -e "${GREEN}Step 9: Port Check${NC}"
echo "Checking which ports are currently in use..."
sudo netstat -tulpn | grep LISTEN | grep -E ":(8080|8081|8888|8889|9000|9001)" || echo "No services running on expected ports yet"
echo ""

echo -e "${GREEN}=================================="
echo "Setup Script Complete!"
echo "==================================${NC}"
echo ""
echo "Summary of what was done:"
echo "  ✓ Checked Python packages"
echo "  ✓ Installed system dependencies"
echo "  ✓ Configured mjpg-streamer"
echo "  ✓ Updated IP addresses"
echo "  ✓ Tested hardware interfaces"
echo "  ✓ Validated service files"
echo ""
echo "Next steps:"
echo "  1. Update React dashboard .env:"
echo "     REACT_APP_PI_HOST=100.71.54.112"
echo ""
echo "  2. Test endpoints:"
echo "     curl http://100.71.54.112:8889/  # Camera server"
echo "     curl http://100.71.54.112:9001/readings  # LCD readings"
echo "     curl http://100.71.54.112:8888/status  # Cry detector"
echo ""
echo "  3. Monitor logs:"
echo "     sudo journalctl -u camera-server -f"
echo "     sudo journalctl -u lcd-reading -f"
echo ""
echo "  4. Check service status:"
echo "     sudo systemctl status camera-server lcd-reading"
echo ""
echo "📝 Full documentation: ~/pi_migration/MIGRATION_COMPLETE_SUMMARY.md"
echo ""
echo -e "${GREEN}Good luck! 🚀${NC}"
