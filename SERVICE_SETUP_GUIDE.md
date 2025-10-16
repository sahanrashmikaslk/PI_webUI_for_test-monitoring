# 🚀 LCD Reading Service - Auto-Start Setup Guide

This guide shows you how to set up the LCD reading server to run automatically as a systemd service on your Raspberry Pi, just like your camera and other services.

## 📋 What You'll Get

After setup, the LCD reading service will:

- ✅ **Auto-start** when Raspberry Pi boots up
- ✅ **Auto-restart** if it crashes
- ✅ Run in the **background** (no need to keep terminal open)
- ✅ **Log all activity** for troubleshooting
- ✅ Start **after network** is ready

## 🎯 Quick Setup (3 Steps)

### **Step 1: Transfer Files to Pi**

From your Windows PC (PowerShell):

```powershell
# Navigate to project directory
cd C:\Users\sahan\Desktop\MYProjects\PI_webUI_for_monitoring

# Transfer ONNX model
scp lcd_ocr_readings\models\incubator_yolov8n.onnx sahan@192.168.8.137:/home/sahan/monitoring/models/

# Transfer server script
scp lcd_reading_server.py sahan@192.168.8.137:/home/sahan/monitoring/

# Transfer setup script
scp setup_lcd_reading.sh sahan@192.168.8.137:/home/sahan/monitoring/

# Transfer management script (optional)
scp manage_lcd_service.sh sahan@192.168.8.137:/home/sahan/monitoring/
```

### **Step 2: Run Setup on Pi**

SSH into your Pi:

```bash
ssh sahan@192.168.8.137
cd /home/sahan/monitoring

# Make scripts executable
chmod +x setup_lcd_reading.sh
chmod +x manage_lcd_service.sh

# Run setup (will install dependencies and create service)
./setup_lcd_reading.sh
```

**The setup will:**

1. Install Python packages (numpy, opencv, onnxruntime, easyocr)
2. Test camera access
3. Create systemd service file
4. Enable auto-start on boot
5. Optionally start the service now

**Expected output:**

```
============================================
✅ Setup Complete!
============================================
```

### **Step 3: Verify Service is Running**

```bash
# Check service status
sudo systemctl status lcd-reading.service

# Test the API
curl http://localhost:9001/readings

# View live logs
sudo journalctl -u lcd-reading.service -f
```

---

## 🔧 Service Management

### Using the Management Script (Easiest)

```bash
cd /home/sahan/monitoring

# Start service
./manage_lcd_service.sh start

# Stop service
./manage_lcd_service.sh stop

# Restart service
./manage_lcd_service.sh restart

# Check status
./manage_lcd_service.sh status

# View logs
./manage_lcd_service.sh logs

# Test API
./manage_lcd_service.sh test

# Enable auto-start
./manage_lcd_service.sh enable

# Disable auto-start
./manage_lcd_service.sh disable
```

### Using systemctl Commands Directly

```bash
# Start the service
sudo systemctl start lcd-reading.service

# Stop the service
sudo systemctl stop lcd-reading.service

# Restart the service
sudo systemctl restart lcd-reading.service

# Check status
sudo systemctl status lcd-reading.service

# Enable auto-start on boot
sudo systemctl enable lcd-reading.service

# Disable auto-start on boot
sudo systemctl disable lcd-reading.service

# View logs
sudo journalctl -u lcd-reading.service -f

# View last 100 log lines
sudo journalctl -u lcd-reading.service -n 100
```

---

## 📊 Service File Location

The service is configured in: `/etc/systemd/system/lcd-reading.service`

**Service Configuration:**

```ini
[Unit]
Description=LCD Reading Server
After=network.target

[Service]
Type=simple
User=sahan
WorkingDirectory=/home/sahan/monitoring
ExecStart=/usr/bin/python3 /home/sahan/monitoring/lcd_reading_server.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**What this means:**

- Starts after network is ready
- Runs as user `sahan`
- Automatically restarts if crashes (waits 10 seconds)
- Logs to systemd journal
- Starts on boot (when enabled)

---

## 🧪 Testing

### Test 1: Check if Service is Running

```bash
sudo systemctl is-active lcd-reading.service
```

**Expected output:** `active`

### Test 2: Test API Endpoint

```bash
curl http://localhost:9001/readings
```

**Expected output:**

```json
{
  "status": "success",
  "readings": {
    "heart_rate_value": {
      "value": 145,
      "unit": "bpm",
      ...
    },
    ...
  }
}
```

### Test 3: Check Logs

```bash
sudo journalctl -u lcd-reading.service -n 50
```

**Look for:**

```
✅ Server ready!
📊 Readings endpoint: http://localhost:9001/readings
```

### Test 4: Test from Dashboard

Open your dashboard in browser and check if LCD readings section shows data.

---

## 🔄 Update/Modify the Service

If you make changes to `lcd_reading_server.py`:

```bash
# Method 1: Using management script
./manage_lcd_service.sh restart

# Method 2: Using systemctl
sudo systemctl restart lcd-reading.service
```

If you modify the service file itself:

```bash
# Reload systemd configuration
sudo systemctl daemon-reload

# Restart the service
sudo systemctl restart lcd-reading.service
```

---

## 🐛 Troubleshooting

### Service won't start

**Check logs:**

```bash
sudo journalctl -u lcd-reading.service -n 100 --no-pager
```

**Common issues:**

1. **Model not found**

   ```
   ❌ Model not found: /home/sahan/monitoring/models/incubator_yolov8n.onnx
   ```

   **Fix:** Transfer the ONNX model file

2. **Camera not available**

   ```
   ❌ Cannot open camera 1
   ```

   **Fix:** Check camera index in `lcd_reading_server.py` (line 50)

3. **Python packages missing**

   ```
   ModuleNotFoundError: No module named 'onnxruntime'
   ```

   **Fix:** Run setup script again or install manually:

   ```bash
   pip3 install onnxruntime opencv-python-headless easyocr
   ```

4. **Permission denied**
   ```
   Permission denied: '/dev/video1'
   ```
   **Fix:** Add user to video group:
   ```bash
   sudo usermod -a -G video sahan
   # Then reboot
   sudo reboot
   ```

### Service keeps restarting

**Check logs to see why:**

```bash
sudo journalctl -u lcd-reading.service -f
```

**Common causes:**

- Model file missing
- Camera disconnected
- Port 9001 already in use

### Slow performance

**Check CPU usage:**

```bash
htop
```

**Solutions:**

1. Increase capture interval in `lcd_reading_server.py`:

   ```python
   CAPTURE_INTERVAL = 10  # Change from 5 to 10 seconds
   ```

2. Use lower camera resolution

3. Consider using NCNN model instead of ONNX

---

## 📁 File Locations

| File              | Location                                               |
| ----------------- | ------------------------------------------------------ |
| Server Script     | `/home/sahan/monitoring/lcd_reading_server.py`         |
| ONNX Model        | `/home/sahan/monitoring/models/incubator_yolov8n.onnx` |
| Service File      | `/etc/systemd/system/lcd-reading.service`              |
| Setup Script      | `/home/sahan/monitoring/setup_lcd_reading.sh`          |
| Management Script | `/home/sahan/monitoring/manage_lcd_service.sh`         |
| Logs              | `sudo journalctl -u lcd-reading.service`               |

---

## 🎯 Complete Service Lifecycle

```bash
# 1. First time setup
./setup_lcd_reading.sh

# 2. Service is now running and will auto-start on boot

# 3. To stop temporarily
sudo systemctl stop lcd-reading.service

# 4. To start again
sudo systemctl start lcd-reading.service

# 5. To restart (after code changes)
sudo systemctl restart lcd-reading.service

# 6. To disable auto-start
sudo systemctl disable lcd-reading.service

# 7. To re-enable auto-start
sudo systemctl enable lcd-reading.service

# 8. To remove service completely
sudo systemctl stop lcd-reading.service
sudo systemctl disable lcd-reading.service
sudo rm /etc/systemd/system/lcd-reading.service
sudo systemctl daemon-reload
```

---

## ✅ Verification Checklist

After setup, verify everything is working:

- [ ] Service is active: `sudo systemctl is-active lcd-reading.service`
- [ ] Service is enabled: `sudo systemctl is-enabled lcd-reading.service`
- [ ] API responds: `curl http://localhost:9001/readings`
- [ ] No errors in logs: `sudo journalctl -u lcd-reading.service -n 50`
- [ ] Dashboard shows LCD readings
- [ ] Service survives reboot: `sudo reboot` then check status

---

## 🔗 Related Services

Your complete monitoring system services:

| Service         | Port     | Purpose                     |
| --------------- | -------- | --------------------------- |
| Camera 1        | 8080     | Infant camera stream        |
| Camera 2        | 8081     | LCD camera stream           |
| Cry Detection   | 8888     | Audio analysis              |
| Health Monitor  | 9000     | System health metrics       |
| **LCD Reading** | **9001** | **Incubator parameters** ⭐ |
| SSH Terminal    | 7681     | Web terminal (ttyd)         |

**View all services:**

```bash
sudo systemctl list-units --type=service | grep -E "camera|cry|health|lcd"
```

---

## 🎉 You're Done!

Your LCD reading service is now set up to run automatically! It will:

- Start when Pi boots
- Restart if it crashes
- Run in background
- Log all activity

Your dashboard at `http://192.168.8.137/index.html` will now show live incubator parameters! 🚀
