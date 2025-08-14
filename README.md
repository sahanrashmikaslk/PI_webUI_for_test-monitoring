#  Raspberry Pi Monitoring Test Dashboard

A comprehensive real-time monitoring system for Raspberry Pi with live camera streaming, baby cry detection, system health monitoring, and SSH terminal access.

![Dashboard Preview](https://img.shields.io/badge/Status-Production%20Ready-brightgreen) ![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi-red) ![License](https://img.shields.io/badge/License-MIT-blue)

##  Table of Contents

- [Features](#-features)
- [System Requirements](#-system-requirements)
- [Quick Setup](#-quick-setup)
- [Architecture](#-architecture)
- [Services Overview](#-services-overview)
- [Dashboard Features](#-dashboard-features)
- [API Documentation](#-api-documentation)
- [Service Management](#-service-management)
- [Troubleshooting](#-troubleshooting)
- [File Structure](#-file-structure)
- [Configuration](#-configuration)
- [Contributing](#-contributing)

## Features

### Core Functionality

- **Real-time System Monitoring** - CPU, RAM, temperature, and power status
- **Dual Camera Streaming** - Live infant monitoring and LCD reading
- **Baby Cry Detection** - Real-time audio analysis with frequency detection
- **SSH Terminal Access** - Web-based terminal for remote Pi management
- **Automatic Service Management** - All services start on Pi boot
- **Responsive Web Interface** - Works on desktop, tablet, and mobile

### Technical Features

- **Auto-start Configuration** - Complete systemd service setup
- **Persistent Monitoring** - Services restart automatically on failure
- **CORS-enabled APIs** - Cross-origin resource sharing for web access
- **Real-time Updates** - Live data refresh without page reload
- **Error Handling** - Graceful degradation when services are unavailable
- **Configurable IP** - Easy Pi IP address configuration from dashboard

## System Requirements

### Hardware

- **Raspberry Pi** (3B+ or newer recommended)
- **2x USB Cameras** (for dual monitoring)
- **USB Microphone** (for cry detection)
- **MicroSD Card** (16GB+ recommended)
- **Network Connection** (WiFi or Ethernet)

### Software Dependencies

- **Raspberry Pi OS** (Bullseye or newer)
- **Python 3.7+**
- **mjpg-streamer** (for camera streaming)
- **ttyd** (for SSH terminal)
- **ALSA/PulseAudio** (for audio processing)

## Quick Setup

### Step 1: Clone Repository

```bash
git clone https://github.com/sahanrashmikaslk/PI_webUI_for_monitoring.git
cd PI_webUI_for_monitoring
```

### Step 2: Transfer Files to Pi

```bash
# From your computer, transfer all files to Pi
scp *.py *.sh *.html sahan@YOUR_PI_IP:~/
```

### Step 3: Run Auto-Setup on Pi

```bash
# SSH to your Pi
ssh sahan@YOUR_PI_IP

# Make scripts executable
chmod +x *.sh

# Run the complete setup
sudo ./setup_autostart.sh
```

### Step 4: Verify Installation

```bash
# Check all services
./service_manager.sh status

# Test camera streams
./service_manager.sh cameras
```

### Step 5: Access Dashboard

Open your web browser and navigate to:

```
http://YOUR_PI_IP/dashboard
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Web Dashboard (index.html)               │
├─────────────────────────────────────────────────────────────┤
│  Health Monitor  │  Camera Streams  │  Cry Detection        │
│  SSH Terminal    │  Audio Monitor   │  System Controls      │
└─────────────────────────────────────────────────────────────┘
                                │
                        ┌───────┴───────┐
                        │   HTTP APIs   │
                        └───────┬───────┘
         ┌──────────────────────┼──────────────────────┐
         │                      │                      │
┌────────▼────────┐   ┌─────────▼─────────┐   ┌───────▼───────┐
│  Health Server  │   │  Cry Detector     │   │ Camera Server │
│  Port: 9000     │   │  Port: 8888       │   │ Port: 8889    │
│                 │   │                   │   │               │
│ • CPU Usage     │   │ • Audio Level     │   │ • mjpg-stream │
│ • RAM Usage     │   │ • Cry Detection   │   │ • Camera Mgmt │
│ • Temperature   │   │ • Real-time Mon   │   │ • Auto-start  │
│ • System Info   │   │ • PyAudio         │   │ • Device Ctrl │
└─────────────────┘   └───────────────────┘   └───────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
            ┌───────▼───────┐       ┌───────▼───────┐
            │ Camera 1      │       │ Camera 2      │
            │ Port: 8080    │       │ Port: 8081    │
            │ /dev/video0   │       │ /dev/video2   │
            │ (Infant)      │       │ (LCD Reader)  │
            └───────────────┘       └───────────────┘
```

## 🔧 Services Overview

| Service             | Port | Purpose                              | Auto-start |
| ------------------- | ---- | ------------------------------------ | ---------- |
| **Health Server**   | 9000 | System metrics API                   | ✅         |
| **Cry Detector**    | 8888 | Audio monitoring & cry detection     | ✅         |
| **Camera Server**   | 8889 | Camera management API                | ✅         |
| **Camera 1 Stream** | 8080 | Live infant monitoring (/dev/video0) | ✅         |
| **Camera 2 Stream** | 8081 | LCD reader camera (/dev/video2)      | ✅         |
| **SSH Terminal**    | 7681 | Web-based terminal access            | Manual     |

## Dashboard Features

### System Health Panel

- **Real-time Metrics**: CPU usage, RAM consumption, temperature
- **Visual Progress Bars**: Color-coded status indicators
- **Configurable Polling**: Adjustable refresh intervals (1-60 seconds)
- **Auto-start**: Begins monitoring automatically on page load
- **Persistent**: Continues monitoring across page refreshes

### Camera Streaming

- **Dual Camera Support**: Simultaneous streaming from two cameras
- **Full Resolution Display**: No cropping or fitting - shows complete image
- **Individual Controls**: Start/stop cameras independently
- **Auto-start**: Cameras begin streaming on Pi boot
- **Device Detection**: Automatic camera device discovery
- **Port Configuration**: Customizable streaming ports

### Baby Cry Detection

- **Real-time Audio Analysis**: Continuous audio level monitoring
- **Frequency-based Detection**: Advanced cry pattern recognition
- **Visual Feedback**: Live audio level display with progress bar
- **Service Control**: Start/stop detection service remotely
- **Alert System**: Visual alerts when crying is detected

### SSH Terminal

- **Web-based Access**: No need for separate SSH client
- **Full Terminal**: Complete bash shell with all commands
- **Persistent Session**: Maintains session across browser refreshes
- **Setup Instructions**: Built-in setup guide for ttyd installation

### Connection Management

- **Pi IP Configuration**: Change Pi IP address from dashboard
- **Connection Status**: Real-time connection indicator
- **Auto-detection**: Automatic service discovery
- **Error Handling**: Graceful degradation when services unavailable

## 📡 API Documentation

### Health API (Port 9000)

```bash
# Get system health metrics
GET http://PI_IP:9000/health

# Response
{
  "cpu": 25.4,
  "ram": 67.8,
  "temp": 45.2,
  "power": "OK",
  "uptime": "2 days, 14:30:22"
}
```

### Cry Detection API (Port 8888)

```bash
# Get cry detection status
GET http://PI_IP:8888/cry/status

# Response
{
  "cry_detected": false,
  "audio_level": 0.25,
  "timestamp": 1692057600
}

# Start/stop detection service
GET http://PI_IP:8888/cry/start
GET http://PI_IP:8888/cry/stop
```

### Camera API (Port 8889)

```bash
# Get camera status
GET http://PI_IP:8889/camera/status

# Start all cameras
GET http://PI_IP:8889/camera/start

# Start specific camera
GET http://PI_IP:8889/camera/start?id=camera1

# Stop cameras
GET http://PI_IP:8889/camera/stop
GET http://PI_IP:8889/camera/stop?id=camera2
```

### Camera Streams

```bash
# Camera 1 (Infant monitoring)
http://PI_IP:8080/?action=stream

# Camera 2 (LCD reader)
http://PI_IP:8081/?action=stream
```

## 🛠️ Service Management

### Using the Service Manager

```bash
# Check status of all services
./service_manager.sh status

# Start all services
./service_manager.sh start

# Stop all services
./service_manager.sh stop

# Restart all services
./service_manager.sh restart

# Restart only camera services
./service_manager.sh restart-cameras

# Check only camera streams
./service_manager.sh cameras

# View service logs
./service_manager.sh logs pi-health-server
./service_manager.sh logs pi-cry-detector
./service_manager.sh logs pi-camera1-stream

# Enable/disable autostart
./service_manager.sh enable
./service_manager.sh disable

# Fix camera permissions
./service_manager.sh fix-permissions

# Install dependencies
./service_manager.sh install
```

### Manual Service Control

```bash
# Individual service control
sudo systemctl start pi-health-server
sudo systemctl stop pi-cry-detector
sudo systemctl restart pi-camera1-stream

# Check service status
systemctl status pi-camera2-stream

# View logs
sudo journalctl -u pi-health-server -f
```

## Troubleshooting

### Common Issues

#### 1. Camera Not Working

```bash
# Check if devices exist
ls -la /dev/video*

# Fix permissions
./service_manager.sh fix-permissions

# Check camera service logs
./service_manager.sh logs pi-camera1-stream

# Test camera manually
mjpg_streamer -i "input_uvc.so -d /dev/video0" -o "output_http.so -p 8080"
```

#### 2. mjpg_streamer Not Found

```bash
# Run the fix script
sudo ./fix_mjpg_streamer.sh

# Or install manually
sudo apt update
sudo apt install mjpg-streamer
```

#### 3. Cry Detection Not Working

```bash
# Check audio devices
arecord -l

# Test microphone
arecord -f cd -t wav -d 5 test.wav

# Check service logs
./service_manager.sh logs pi-cry-detector

# Install audio dependencies
sudo apt install python3-pyaudio portaudio19-dev
```

#### 4. Services Not Starting on Boot

```bash
# Re-enable services
./service_manager.sh enable

# Check service files
sudo systemctl list-unit-files | grep pi-

# Reload systemd
sudo systemctl daemon-reload
```

#### 5. Dashboard Not Accessible

```bash
# Check Pi IP address
hostname -I

# Test network connectivity
ping PI_IP

# Verify web server (if using one)
python3 -m http.server 80
```

### Log Locations

```bash
# Service logs
sudo journalctl -u pi-health-server
sudo journalctl -u pi-cry-detector
sudo journalctl -u pi-camera1-stream

# System logs
sudo journalctl -f

# Service status
systemctl status pi-*
```

## File Structure

```
PI_webUI_for_monitoring/
├── index.html                 # Main dashboard interface
├── simple_health_server.py    # System health monitoring API
├── cry_detector.py           # Baby cry detection service
├── camera_server.py          # Camera management API
├── setup_autostart.sh        # Complete autostart setup script
├── service_manager.sh        # Service management utility
├── fix_mjpg_streamer.sh      # mjpg_streamer installation fix
├── verify_installation.sh    # Installation verification script
└── README.md                 # This file
```

### Generated Files (on Pi)

```
/etc/systemd/system/
├── pi-health-server.service
├── pi-cry-detector.service
├── pi-camera-server.service
├── pi-camera1-stream.service
└── pi-camera2-stream.service

/etc/udev/rules.d/
└── 99-camera.rules

/home/sahan/
├── check_services.py
└── manage_services.sh
```

## Configuration

### Default Settings

```bash
# Network Configuration
PI_IP="192.168.8.137"          # Default Pi IP address
HEALTH_PORT=9000                # Health monitoring API
CRY_PORT=8888                   # Cry detection API
CAMERA_API_PORT=8889            # Camera management API
CAMERA1_PORT=8080               # Camera 1 stream
CAMERA2_PORT=8081               # Camera 2 stream
TERMINAL_PORT=7681              # SSH terminal

# Camera Configuration
CAMERA1_DEVICE="/dev/video0"    # Infant monitoring camera
CAMERA2_DEVICE="/dev/video2"    # LCD reader camera
RESOLUTION="640x480"            # Stream resolution
FPS=30                          # Frames per second

# Monitoring Configuration
HEALTH_POLL_INTERVAL=5          # Health check interval (seconds)
CRY_CHECK_INTERVAL=1            # Cry detection interval (seconds)
AUDIO_LEVEL_INTERVAL=0.5        # Audio level update interval (seconds)
```

### Customization

1. **Change Pi IP**: Use the dashboard interface or edit `index.html`
2. **Modify Ports**: Edit service files in `/etc/systemd/system/`
3. **Camera Settings**: Update `camera_server.py` configuration
4. **Polling Intervals**: Adjust JavaScript variables in `index.html`

## Prerequisites Installation

### On Raspberry Pi OS:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Python dependencies
sudo apt install python3 python3-pip -y

# Install system packages
sudo apt install mjpg-streamer v4l-utils ttyd curl netstat-nat -y

# Install audio packages (for cry detection)
sudo apt install portaudio19-dev python3-pyaudio -y

# Install Python packages
pip3 install requests pyaudio numpy --break-system-packages
```

## Security Considerations

- **Network Access**: Dashboard accessible on local network only
- **Authentication**: No built-in authentication (use network security)
- **Permissions**: Services run as regular user, not root
- **Firewall**: Consider limiting port access with iptables
- **SSH Keys**: Use SSH keys instead of passwords for better security

## Use Cases

- **Baby Monitoring**: Real-time infant surveillance with cry detection
- **System Administration**: Remote Pi monitoring and maintenance
- **Educational Projects**: Learning IoT, web development, and system integration
- **Home Automation**: Integration with larger smart home systems
- **Development Platform**: Base for expanding monitoring capabilities

## Future Enhancements

- [ ] User authentication and access control
- [ ] Database logging for historical data
- [ ] Mobile app integration
- [ ] Push notifications for alerts
- [ ] Multi-Pi support in single dashboard
- [ ] Advanced cry detection with machine learning
- [ ] Cloud storage integration for recordings
- [ ] Custom alert thresholds and notifications

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **mjpg-streamer** - For excellent camera streaming capabilities
- **ttyd** - For web-based terminal access
- **Raspberry Pi Foundation** - For the amazing hardware platform
- **Python Community** - For the robust libraries and tools

## Support

If you encounter any issues or have questions:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review service logs using the service manager
3. Open an issue on GitHub with detailed information
4. Include system information and error logs

---

_This dashboard provides a complete monitoring solution for Raspberry Pi projects with real-time capabilities and automatic service management._
