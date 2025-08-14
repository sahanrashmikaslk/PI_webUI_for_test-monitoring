#!/bin/bash
# Pi Monitoring System - Installation Verification Script
# Checks if all services are properly installed and configured

echo "🔍 Pi Monitoring System - Installation Verification"
echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVICES=("pi-health-server" "pi-cry-detector" "pi-camera-server")
SCRIPTS=("simple_health_server.py" "cry_detector.py" "camera_server.py")
PORTS=("9000" "8888" "8889")

check_passed=0
check_failed=0

print_check() {
    local status=$1
    local message=$2
    
    if [ "$status" == "PASS" ]; then
        echo -e "${GREEN}✅ PASS${NC} - $message"
        ((check_passed++))
    elif [ "$status" == "FAIL" ]; then
        echo -e "${RED}❌ FAIL${NC} - $message"
        ((check_failed++))
    else
        echo -e "${YELLOW}⚠️  WARN${NC} - $message"
    fi
}

# Check if running as regular user (not root)
echo "📋 System Checks:"
if [ "$EUID" -eq 0 ]; then
    print_check "WARN" "Running as root - should run as regular user"
else
    print_check "PASS" "Running as regular user"
fi

# Check Python installation
if command -v python3 &> /dev/null; then
    python_version=$(python3 --version 2>&1)
    print_check "PASS" "Python3 installed: $python_version"
else
    print_check "FAIL" "Python3 not found"
fi

# Check required system packages
echo ""
echo "📦 Package Checks:"
packages=("curl" "netstat" "systemctl")
for pkg in "${packages[@]}"; do
    if command -v $pkg &> /dev/null; then
        print_check "PASS" "$pkg is installed"
    else
        print_check "FAIL" "$pkg is not installed"
    fi
done

# Check if mjpg-streamer is available
if command -v mjpg_streamer &> /dev/null; then
    print_check "PASS" "mjpg_streamer is installed"
else
    print_check "WARN" "mjpg_streamer not found - camera streaming may not work"
fi

# Check user groups
echo ""
echo "👤 User Group Checks:"
if groups | grep -q "audio"; then
    print_check "PASS" "User is in audio group"
else
    print_check "FAIL" "User not in audio group - cry detection may not work"
fi

if groups | grep -q "video"; then
    print_check "PASS" "User is in video group"
else
    print_check "FAIL" "User not in video group - camera access may not work"
fi

# Check Python scripts
echo ""
echo "🐍 Python Script Checks:"
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        print_check "PASS" "$script exists"
        
        # Basic syntax check
        if python3 -m py_compile "$script" 2>/dev/null; then
            print_check "PASS" "$script syntax is valid"
        else
            print_check "FAIL" "$script has syntax errors"
        fi
    else
        print_check "FAIL" "$script not found"
    fi
done

# Check systemd services
echo ""
echo "🔧 Service Configuration Checks:"
for service in "${SERVICES[@]}"; do
    service_file="/etc/systemd/system/${service}.service"
    
    if [ -f "$service_file" ]; then
        print_check "PASS" "$service.service file exists"
        
        # Check if service is recognized by systemd
        if systemctl list-unit-files | grep -q "$service"; then
            print_check "PASS" "$service recognized by systemd"
            
            # Check service status
            service_status=$(systemctl is-active $service 2>/dev/null)
            if [ "$service_status" == "active" ]; then
                print_check "PASS" "$service is running"
            else
                print_check "WARN" "$service is not running (status: $service_status)"
            fi
            
            # Check if enabled for autostart
            if systemctl is-enabled $service >/dev/null 2>&1; then
                print_check "PASS" "$service autostart enabled"
            else
                print_check "WARN" "$service autostart not enabled"
            fi
        else
            print_check "FAIL" "$service not recognized by systemd"
        fi
    else
        print_check "FAIL" "$service.service file not found"
    fi
done

# Check ports
echo ""
echo "🌐 Port Checks:"
for i in "${!PORTS[@]}"; do
    port="${PORTS[$i]}"
    service_name="${SERVICES[$i]}"
    
    if netstat -tln 2>/dev/null | grep -q ":$port "; then
        print_check "PASS" "Port $port is listening ($service_name)"
        
        # Test API response
        if curl -s --connect-timeout 2 http://localhost:$port >/dev/null 2>&1; then
            print_check "PASS" "Port $port API responding ($service_name)"
        else
            print_check "WARN" "Port $port not responding ($service_name)"
        fi
    else
        print_check "WARN" "Port $port not listening ($service_name)"
    fi
done

# Check camera devices
echo ""
echo "📷 Camera Device Checks:"
if ls /dev/video* &>/dev/null; then
    video_devices=$(ls /dev/video* 2>/dev/null | wc -l)
    print_check "PASS" "Found $video_devices video device(s)"
    
    for device in /dev/video*; do
        if [ -r "$device" ]; then
            print_check "PASS" "$device is readable"
        else
            print_check "WARN" "$device is not readable"
        fi
    done
else
    print_check "WARN" "No video devices found"
fi

# Check audio devices for cry detection
echo ""
echo "🔊 Audio Device Checks:"
if [ -d "/proc/asound" ]; then
    if ls /proc/asound/card* &>/dev/null; then
        audio_cards=$(ls /proc/asound/card* 2>/dev/null | wc -l)
        print_check "PASS" "Found $audio_cards audio card(s)"
    else
        print_check "WARN" "No audio cards found"
    fi
else
    print_check "WARN" "ALSA sound system not found"
fi

# Final summary
echo ""
echo "📊 Installation Summary:"
echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="
echo -e "${GREEN}✅ Passed Checks: $check_passed${NC}"
echo -e "${RED}❌ Failed Checks: $check_failed${NC}"
echo ""

if [ $check_failed -eq 0 ]; then
    echo -e "${GREEN}🎉 Installation verification completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Access your dashboard at: http://192.168.8.137/dashboard"
    echo "2. Use './service_manager.sh status' to check service status"
    echo "3. Use './service_manager.sh start' to start all services"
    echo "4. Use './service_manager.sh enable' to enable autostart"
else
    echo -e "${RED}⚠️  Installation has issues that need attention.${NC}"
    echo ""
    echo "Suggested fixes:"
    if [ $check_failed -gt 0 ]; then
        echo "1. Run './setup_autostart.sh' to fix service configuration"
        echo "2. Run './service_manager.sh install' to install dependencies"
        echo "3. Check individual service logs with './service_manager.sh logs [service]'"
    fi
fi

echo ""
echo "For help: './service_manager.sh help'"
