# 🔬 Raspberry Pi Monitoring Dashboard

A simple, comprehensive monitoring system for Raspberry Pi with live camera streaming, baby cry detection, and system health monitoring.

![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen) ![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi-red)

## ✨ Features

- **📊 Real-time System Monitoring** - CPU, RAM, temperature monitoring
- **👶 Baby Cry Detection** - Audio analysis with real-time alerts
- **📹 Dual Camera Streaming** - Live monitoring with auto-start
- **🌐 Web Dashboard** - Complete control from any device
- **🔄 Auto-start Services** - Everything runs automatically on boot

## 🚀 Quick Setup

### Step 1: Copy Files to Pi

```bash
# Copy all files to your Pi
scp *.py *.sh *.html sahan@YOUR_PI_IP:~/
```

### Step 2: Run Setup

```bash
# SSH to your Pi
ssh sahan@YOUR_PI_IP

# Make setup script executable and run
chmod +x simple_setup.sh
sudo ./simple_setup.sh
```

### Step 3: Access Dashboard

Open your browser and go to:

```
http://YOUR_PI_IP/index.html
```

## 🎯 Service Management

### Essential Commands

```bash
# Check status of all services
./manage_services.sh status

# Start all services
./manage_services.sh start

# Stop all services
./manage_services.sh stop

# Restart all services
./manage_services.sh restart

# View service logs
./manage_services.sh logs pi-health-server
./manage_services.sh logs pi-cry-detector
./manage_services.sh logs pi-camera1-stream

# Enable/disable autostart
./manage_services.sh enable
./manage_services.sh disable
```

## 📋 Services Overview

| Service           | Port | Purpose                              |
| ----------------- | ---- | ------------------------------------ |
| **Health Server** | 9000 | System metrics (CPU, RAM, temp)      |
| **Cry Detector**  | 8888 | Audio monitoring & cry detection     |
| **Camera Server** | 8889 | Camera management API                |
| **Camera 1**      | 8080 | Live infant monitoring (/dev/video0) |
| **Camera 2**      | 8081 | LCD reader camera (/dev/video2)      |

## 🌐 Dashboard URLs

- **Main Dashboard**: `http://YOUR_PI_IP/index.html`
- **Health API**: `http://YOUR_PI_IP:9000/health`
- **Cry Detection**: `http://YOUR_PI_IP:8888/cry/status`
- **Camera 1 Stream**: `http://YOUR_PI_IP:8080/?action=stream`
- **Camera 2 Stream**: `http://YOUR_PI_IP:8081/?action=stream`

## 🔧 Troubleshooting

### Services Not Working?

```bash
# Check service status
./manage_services.sh status

# Restart all services
./manage_services.sh restart

# Check specific service logs
./manage_services.sh logs SERVICE_NAME
```

### Common Issues

#### Camera Not Working

```bash
# Check if camera devices exist
ls -la /dev/video*

# Restart camera services
sudo systemctl restart pi-camera1-stream pi-camera2-stream
```

#### Audio Detection Not Working

```bash
# Check audio devices
arecord -l

# Restart cry detection
sudo systemctl restart pi-cry-detector
```

#### Health Monitoring Not Working

```bash
# Check health server
sudo systemctl restart pi-health-server

# Test API manually
curl http://localhost:9000/health
```

## 📁 File Structure

### Essential Files

```
PI_webUI_for_monitoring/
├── index.html              # Main dashboard
├── simple_health_server.py # Health monitoring
├── cry_detector.py         # Cry detection
├── camera_server.py        # Camera management
├── simple_setup.sh         # One-time setup
├── manage_services.sh      # Service management
└── README.md              # This file
```

## 🎯 System Requirements

- **Raspberry Pi 3B+ or newer**
- **2x USB Cameras** for dual monitoring
- **USB Microphone** for cry detection
- **Raspberry Pi OS** (Bullseye or newer)

## 📝 Quick Reference

### After Pi Restart

All services start automatically. If needed:

```bash
./manage_services.sh status
```

### Daily Operations

```bash
# Check everything is working
./manage_services.sh status

# Restart if issues
./manage_services.sh restart
```

### Logs for Debugging

```bash
# Health monitoring logs
./manage_services.sh logs pi-health-server

# Cry detection logs
./manage_services.sh logs pi-cry-detector

# Camera logs
./manage_services.sh logs pi-camera1-stream
./manage_services.sh logs pi-camera2-stream
```

## 🎉 That's It!

Your Pi monitoring system is now complete and will work automatically. The dashboard provides real-time monitoring of your Pi's health, camera feeds, and audio detection - perfect for baby monitoring or general Pi surveillance.

**Everything starts automatically on boot - no manual intervention needed!** 🚀
