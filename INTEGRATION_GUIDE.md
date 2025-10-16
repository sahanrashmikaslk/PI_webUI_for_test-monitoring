# 🏥 LCD OCR Reading Integration Guide

## Overview

This guide explains how to integrate the incubator LCD display reading system into your Raspberry Pi monitoring dashboard. The system uses YOLO object detection + OCR to extract vital signs from the incubator display and serves them via HTTP API.

## 📊 What Gets Monitored

The system detects and reads 4 parameters from the incubator display:

| Parameter            | Range     | Unit | Type              |
| -------------------- | --------- | ---- | ----------------- |
| **Heart Rate**       | 60-220    | bpm  | Integer           |
| **SpO2**             | 70-100    | %    | Integer           |
| **Skin Temperature** | 32.0-39.0 | °C   | Decimal (1 place) |
| **Humidity**         | 30-95     | %    | Integer           |

## 🎯 Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Dashboard (Web Browser)                │
│  ┌────────────┐  ┌────────────┐  ┌─────────────────────┐ │
│  │  Cameras   │  │   Health   │  │  LCD Readings (NEW) │ │
│  │  Port 8080 │  │  Port 9000 │  │     Port 9001       │ │
│  └────────────┘  └────────────┘  └─────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│            Raspberry Pi (192.168.8.137)                   │
│  ┌────────────────────────────────────────────────────┐  │
│  │         camera_server.py (Port 8080-8081)          │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │        simple_health_server.py (Port 9000)         │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │    lcd_reading_server.py (Port 9001) ← NEW         │  │
│  │    ├─ Camera 1 (LCD display camera)                │  │
│  │    ├─ YOLO Detection (incubator_yolov8n.onnx)      │  │
│  │    ├─ EasyOCR (text extraction)                    │  │
│  │    └─ Validation & Correction                      │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

## 📋 Step-by-Step Setup

### **Step 1: Convert Model to ONNX (on Windows PC)**

The `.pt` PyTorch model needs to be converted to ONNX format for better performance on Raspberry Pi.

```powershell
# Navigate to lcd_ocr_readings directory
cd c:\Users\sahan\Desktop\MYProjects\PI_webUI_for_monitoring\lcd_ocr_readings

# Run the conversion script
python convert_model_to_onnx.py
```

This will create `incubator_yolov8n.onnx` in the `models/` directory.

**Expected Output:**

```
🔄 Converting incubator_yolov8n.pt to ONNX format...
✅ Model successfully converted!
📦 ONNX model saved to: models/incubator_yolov8n.onnx
```

### **Step 2: Transfer Files to Raspberry Pi**

Transfer the following files to your Pi:

```powershell
# From Windows PowerShell

# 1. Transfer the ONNX model
scp lcd_ocr_readings/models/incubator_yolov8n.onnx sahan@192.168.8.137:/home/sahan/monitoring/models/

# 2. Transfer the LCD reading server
scp lcd_reading_server.py sahan@192.168.8.137:/home/sahan/monitoring/

# 3. Transfer the simple health server (if not already there)
scp simple_health_server.py sahan@192.168.8.137:/home/sahan/monitoring/
```

### **Step 3: Install Dependencies on Raspberry Pi**

SSH into your Pi and install the required packages:

```bash
ssh sahan@192.168.8.137

# Update system
sudo apt-get update

# Install Python dependencies
pip3 install opencv-python-headless numpy onnxruntime easyocr

# For PyTorch model (if not using ONNX):
# pip3 install ultralytics torch torchvision

# Verify installations
python3 -c "import cv2; print('OpenCV:', cv2.__version__)"
python3 -c "import onnxruntime; print('ONNX Runtime:', onnxruntime.__version__)"
python3 -c "import easyocr; print('EasyOCR OK')"
```

**Note:** EasyOCR first-time initialization downloads language models (~100MB), which may take a few minutes.

### **Step 4: Configure Camera Index**

Determine which camera is connected to the LCD display:

```bash
# List available cameras
v4l2-ctl --list-devices

# Test camera
python3 -c "import cv2; cap = cv2.VideoCapture(1); print('Camera 1:', cap.isOpened()); cap.release()"
```

Edit `lcd_reading_server.py` if needed:

```python
LCD_CAMERA_INDEX = 1  # Change to 0, 1, or 2 based on your setup
```

### **Step 5: Test the LCD Reading Server**

Run the server manually to verify it works:

```bash
cd /home/sahan/monitoring

# Run the server
python3 lcd_reading_server.py
```

**Expected Output:**

```
============================================================
🚀 LCD Reading Server for Raspberry Pi
============================================================

📷 Initializing LCD reader...
   Camera: 1
   Model: /home/sahan/monitoring/models/incubator_yolov8n.onnx

🔧 Loading ONNX model: /home/sahan/monitoring/models/incubator_yolov8n.onnx
✅ ONNX model loaded successfully
🔧 Initializing EasyOCR...
✅ EasyOCR initialized successfully

🔄 Starting continuous reading (interval: 5s)
✅ Continuous reading started

✅ Server ready!
📊 Readings endpoint: http://localhost:9001/readings
📸 Capture endpoint: http://localhost:9001/capture
ℹ️  API info: http://localhost:9001/
🌐 External access: http://<your-pi-ip>:9001/readings
⏹️  Press Ctrl+C to stop
============================================================
```

### **Step 6: Test API Endpoints**

Open another SSH session or use curl to test:

```bash
# Get latest readings (cached)
curl http://localhost:9001/readings

# Capture new reading immediately
curl http://localhost:9001/capture

# Get API info
curl http://localhost:9001/
```

**Example Response:**

```json
{
  "status": "success",
  "readings": {
    "heart_rate_value": {
      "value": 145,
      "unit": "bpm",
      "name": "Heart Rate",
      "detection_confidence": 0.95,
      "ocr_confidence": 0.89,
      "raw_text": "145"
    },
    "spo2_value": {
      "value": 98,
      "unit": "%",
      "name": "SpO2",
      "detection_confidence": 0.92,
      "ocr_confidence": 0.91,
      "raw_text": "98"
    },
    "skin_temp_value": {
      "value": 36.5,
      "unit": "°C",
      "name": "Skin Temperature",
      "detection_confidence": 0.94,
      "ocr_confidence": 0.87,
      "raw_text": "36.5"
    },
    "humidity_value": {
      "value": 65,
      "unit": "%",
      "name": "Humidity",
      "detection_confidence": 0.93,
      "ocr_confidence": 0.88,
      "raw_text": "65"
    }
  },
  "timestamp": 1728663420.5,
  "detections_count": 4
}
```

### **Step 7: Create Systemd Service (Auto-start on boot)**

Create a service file to run the LCD reading server automatically:

```bash
# Create service file
sudo nano /etc/systemd/system/lcd-reading.service
```

**Service file content:**

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

[Install]
WantedBy=multi-user.target
```

**Enable and start the service:**

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service (start on boot)
sudo systemctl enable lcd-reading.service

# Start service now
sudo systemctl start lcd-reading.service

# Check status
sudo systemctl status lcd-reading.service

# View logs
sudo journalctl -u lcd-reading.service -f
```

### **Step 8: Update the Dashboard (index.html)**

Now we need to add the LCD readings section to the dashboard. The integration will be added in the next file.

## 🔧 Configuration Options

### LCD Reading Server (`lcd_reading_server.py`)

```python
# Camera settings
LCD_CAMERA_INDEX = 1  # Camera connected to LCD display (0, 1, or 2)

# Server settings
LCD_PORT = 9001  # HTTP server port

# Model settings
MODEL_PATH = "/home/sahan/monitoring/models/incubator_yolov8n.onnx"
CONFIDENCE_THRESHOLD = 0.25  # Detection confidence (0.1-0.9)

# Reading interval
CAPTURE_INTERVAL = 5  # Capture every N seconds
```

### Performance Tuning

**For Raspberry Pi 3/4:**

- Use ONNX model (faster than PyTorch)
- Set `CAPTURE_INTERVAL = 5` (good balance)
- Use `CONFIDENCE_THRESHOLD = 0.25` (default)

**For Raspberry Pi Zero/2:**

- Use ONNX model (required)
- Set `CAPTURE_INTERVAL = 10` (reduce load)
- Consider reducing camera resolution

## 🔍 Troubleshooting

### Issue: Model not loading

**Error:** `❌ Model not found`

**Solution:**

```bash
# Check if model exists
ls -lh /home/sahan/monitoring/models/incubator_yolov8n.onnx

# If missing, transfer from Windows
scp lcd_ocr_readings/models/incubator_yolov8n.onnx sahan@192.168.8.137:/home/sahan/monitoring/models/
```

### Issue: Camera not opening

**Error:** `❌ Cannot open camera 1`

**Solution:**

```bash
# List cameras
v4l2-ctl --list-devices

# Try different camera index (0, 1, or 2)
# Edit lcd_reading_server.py and change LCD_CAMERA_INDEX
```

### Issue: Low detection accuracy

**Solution:**

1. **Improve lighting** - Add LED light near LCD display
2. **Position camera** - Mount camera perpendicular to display
3. **Clean display** - Remove reflections and dust
4. **Adjust confidence** - Lower `CONFIDENCE_THRESHOLD` to 0.2

### Issue: Slow inference

**Solution:**

1. **Use ONNX model** (not PyTorch .pt)
2. **Increase interval** - Set `CAPTURE_INTERVAL = 10`
3. **Reduce resolution** - Modify camera capture size
4. **Disable EasyOCR GPU** - Already disabled by default

### Issue: Wrong readings

**Solution:**

1. **Check parameter ranges** in `PARAMETER_RANGES`
2. **View raw OCR text** in API response
3. **Adjust OCR settings** - Change EasyOCR parameters
4. **Retrain model** if consistently wrong

## 📊 API Reference

### GET /readings

Get the latest cached readings (fast, no camera capture).

**Response:**

```json
{
  "status": "success|no_detection|error|no_data",
  "readings": {
    "heart_rate_value": {...},
    "spo2_value": {...},
    "skin_temp_value": {...},
    "humidity_value": {...}
  },
  "timestamp": 1728663420.5,
  "detections_count": 4
}
```

### GET /capture

Capture a new reading immediately (slower, triggers camera capture).

### GET /

Get API information.

## 🚀 Next Steps

1. ✅ **Convert model to ONNX** (Step 1)
2. ✅ **Transfer files to Pi** (Step 2)
3. ✅ **Install dependencies** (Step 3)
4. ✅ **Test server manually** (Step 5-6)
5. ⏭️ **Update dashboard HTML** (see `DASHBOARD_INTEGRATION.md`)
6. ⏭️ **Create systemd service** (Step 7)
7. ⏭️ **Monitor and fine-tune** (Step 9)

## 📝 Files Created

1. **`convert_model_to_onnx.py`** - Model conversion script (run on Windows)
2. **`lcd_reading_server.py`** - LCD reading HTTP server (run on Pi)
3. **`INTEGRATION_GUIDE.md`** - This file
4. **`DASHBOARD_INTEGRATION.md`** - Dashboard HTML updates (next file)

## 💡 Tips

- **Camera positioning is crucial** - Mount camera stable and perpendicular to LCD
- **Good lighting helps** - Add LED strip or desk lamp
- **Monitor logs regularly** - `sudo journalctl -u lcd-reading.service -f`
- **Start with longer intervals** - Use 10s while testing, reduce to 5s when stable
- **Check confidence scores** - Low scores (<0.5) indicate poor detection/OCR

---

**Need Help?** Check the logs and API responses for detailed error messages.
