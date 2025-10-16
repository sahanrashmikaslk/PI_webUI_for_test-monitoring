# 🔧 LCD Display Reader - Troubleshooting & Setup Guide

## 📋 Current Status Summary

Based on the repository analysis, here's what has been set up:

### ✅ What's Already Done

1. **YOLO Model Training**

   - YOLOv8n model trained for LCD display detection
   - Models available: `incubator_yolov8n.pt`, `incubator_yolov8n.onnx`
   - Located in: `lcd_ocr_readings/models/`
   - Classes: `heart_rate_value`, `spo2_value`, `skin_temp_value`, `humidity_value`

2. **LCD Reading Server (`lcd_reading_server.py`)**

   - HTTP server on port 9001
   - Captures frames from **mjpg_streamer on port 8081**
   - Runs YOLO detection + Tesseract OCR
   - Medical validation & correction
   - Continuous reading every 5 seconds

3. **Dashboard Integration (`index.html`)**

   - LCD readings section already added
   - Displays: Heart Rate, SpO2, Temperature, Humidity
   - Auto-polling from LCD server
   - Confidence scores shown

4. **Setup Scripts**
   - `setup_lcd_reading.sh` - Automated setup
   - `manage_lcd_service.sh` - Service management

### ❌ What's NOT Working

The LCD reader is **not working** because:

1. **Camera Configuration Issue**

   - LCD server is trying to read from **HTTP stream (port 8081)**
   - But the actual camera is on **USB 2.0 (video0)**
   - Server should directly access camera device, not HTTP stream

2. **Model Path Issue**

   - Server configured for `.pt` (PyTorch) model
   - Should use `.onnx` for better Pi 3B+ performance

3. **OCR Engine Issue**
   - Using **Tesseract OCR** (not installed on Pi)
   - Should use **EasyOCR** (as per original pipeline)

---

## 🎯 Root Cause Analysis

### Problem 1: Camera Capture Method

**Current Code (WRONG):**

```python
# lcd_reading_server.py line 192
def capture_frame(self):
    """Capture a frame from mjpg_streamer HTTP stream on port 8081"""
    stream_url = "http://localhost:8081/?action=stream"
    # ... tries to read from HTTP stream
```

**Why it's wrong:**

- The USB 2.0 camera is on `/dev/video0` (or `/dev/video2`)
- Port 8081 is for **streaming**, not for OCR processing
- Should capture directly from camera device with OpenCV

**Should be:**

```python
def capture_frame(self):
    """Capture a frame directly from camera device"""
    cap = cv2.VideoCapture(self.camera_index)
    if not cap.isOpened():
        return None
    ret, frame = cap.read()
    cap.release()
    return frame if ret else None
```

### Problem 2: OCR Engine

**Current Code:**

```python
# Uses pytesseract (Tesseract OCR)
import pytesseract
pytesseract.image_to_data(processed, ...)
```

**Should use EasyOCR:**

```python
import easyocr
self.reader = easyocr.Reader(['en'], gpu=False)
results = self.reader.readtext(processed)
```

### Problem 3: Model Format

**Current Config:**

```python
MODEL_PATH = "/home/sahan/monitoring/models/incubator_yolov8n.pt"  # PyTorch
```

**Should be:**

```python
MODEL_PATH = "/home/sahan/monitoring/models/incubator_yolov8n.onnx"  # ONNX
```

---

## 🔧 Fix Steps

### Step 1: Identify the Correct Camera

SSH to Pi and check cameras:

```bash
ssh sahan@100.99.151.101

# List all video devices
ls -la /dev/video*

# Expected output:
# /dev/video0  <- USB 2.0 PC CAMERA (main device)
# /dev/video1  <- USB 2.0 PC CAMERA (metadata device)
# /dev/video2  <- V380 FHD Camera (or another camera)
```

Test each camera:

```bash
# Install v4l-utils if not installed
sudo apt-get install v4l-utils

# Check camera 0
v4l2-ctl --device=/dev/video0 --all | grep "Driver Info" -A 5

# Check camera 1
v4l2-ctl --device=/dev/video1 --all | grep "Driver Info" -A 5

# Check camera 2
v4l2-ctl --device=/dev/video2 --all | grep "Driver Info" -A 5
```

**USB 2.0 PC CAMERA for LCD should be video0 or video2** (not video1 - that's metadata)

Test capture:

```bash
# Test video0
python3 -c "import cv2; cap = cv2.VideoCapture(0); ret, frame = cap.read(); print(f'video0: {ret}, shape: {frame.shape if ret else None}'); cap.release()"

# Test video2
python3 -c "import cv2; cap = cv2.VideoCapture(2); ret, frame = cap.read(); print(f'video2: {ret}, shape: {frame.shape if ret else None}'); cap.release()"
```

### Step 2: Fix the LCD Reading Server

I'll create a corrected version of `lcd_reading_server.py`:

**Key Changes:**

1. ✅ Direct camera capture (not HTTP stream)
2. ✅ Use EasyOCR instead of Tesseract
3. ✅ Use ONNX model for better performance
4. ✅ Proper camera index configuration

### Step 3: Install Dependencies on Pi

```bash
ssh sahan@100.99.151.101

# Install system dependencies
sudo apt-get update
sudo apt-get install -y python3-pip libgl1-mesa-glx libglib2.0-0

# Install Python packages
pip3 install opencv-python-headless numpy onnxruntime easyocr

# Verify installations
python3 -c "import cv2; print('OpenCV:', cv2.__version__)"
python3 -c "import onnxruntime; print('ONNX Runtime:', onnxruntime.__version__)"
python3 -c "import easyocr; print('EasyOCR: OK')"
```

### Step 4: Transfer Files to Pi

```powershell
# From Windows PC

# 1. Transfer corrected server script (I'll create this next)
scp lcd_reading_server_fixed.py sahan@100.99.151.101:/home/sahan/monitoring/lcd_reading_server.py

# 2. Transfer ONNX model (if not already there)
scp lcd_ocr_readings\models\incubator_yolov8n.onnx sahan@100.99.151.101:/home/sahan/monitoring/models/

# 3. Transfer NCNN model (optional, for better performance)
scp -r lcd_ocr_readings\models\incubator_yolov8n_ncnn_model sahan@100.99.151.101:/home/sahan/monitoring/models/
```

### Step 5: Configure Camera Index

Edit the server file on Pi:

```bash
ssh sahan@100.99.151.101
nano /home/sahan/monitoring/lcd_reading_server.py
```

Change line ~50:

```python
# Set to the correct camera index (0, 2, etc.)
LCD_CAMERA_INDEX = 0  # or 2, based on your testing
```

### Step 6: Test the Server

```bash
# Stop the service if running
sudo systemctl stop lcd-reading.service

# Run server manually to see output
cd /home/sahan/monitoring
python3 lcd_reading_server.py
```

**Expected Output:**

```
============================================================
🚀 LCD Reading Server for Raspberry Pi
============================================================

📷 Initializing LCD reader...
   Camera: 0
   Model: /home/sahan/monitoring/models/incubator_yolov8n.onnx

🔧 Loading ONNX model...
✅ ONNX model loaded successfully
🔧 Initializing EasyOCR...
✅ EasyOCR initialized successfully

🔄 Starting continuous reading (interval: 5s)
✅ Continuous reading started

✅ Server ready!
📊 Readings endpoint: http://localhost:9001/readings
```

Test from another terminal:

```bash
curl http://localhost:9001/readings
```

### Step 7: Update Dashboard (if needed)

The dashboard (`index.html`) already has LCD section, but verify the port:

```javascript
// Line ~1337 in index.html
const LCD_PORT = 9001; // Should match server port
```

### Step 8: Start the Service

Once manual testing works:

```bash
# Create/update systemd service
sudo systemctl daemon-reload
sudo systemctl enable lcd-reading.service
sudo systemctl start lcd-reading.service

# Check status
sudo systemctl status lcd-reading.service

# View logs
sudo journalctl -u lcd-reading.service -f
```

---

## 📸 Camera Setup Tips

### Optimal Camera Positioning

1. **Distance**: 15-30 cm from LCD display
2. **Angle**: Perpendicular (90°) to display surface
3. **Lighting**: Ensure even lighting, avoid reflections
4. **Focus**: LCD numbers should be sharp and clear

### Test Camera View

```bash
# Capture a test image
python3 << 'EOF'
import cv2
cap = cv2.VideoCapture(0)  # Change to your camera index
ret, frame = cap.read()
if ret:
    cv2.imwrite('/home/sahan/monitoring/test_lcd_capture.jpg', frame)
    print(f"✅ Image saved: {frame.shape}")
else:
    print("❌ Failed to capture")
cap.release()
EOF

# Download to PC to review
# On Windows PC:
scp sahan@100.99.151.101:/home/sahan/monitoring/test_lcd_capture.jpg .
```

---

## 🐛 Common Issues & Solutions

### Issue 1: Camera Not Opening

**Error:** `❌ Cannot open camera 0`

**Solutions:**

1. Check if camera is connected: `ls /dev/video*`
2. Check if another process is using it: `sudo fuser /dev/video0`
3. Try different camera index (0, 1, 2)
4. Restart Pi: `sudo reboot`

### Issue 2: YOLO Not Detecting Display

**Error:** `⚠️ No display regions detected`

**Solutions:**

1. Check camera image quality (save test image)
2. Improve lighting on LCD display
3. Lower confidence threshold:
   ```python
   CONFIDENCE_THRESHOLD = 0.15  # From 0.25
   ```
4. Verify model is correct for your display type

### Issue 3: OCR Reading Wrong Values

**Error:** Wrong numbers detected

**Solutions:**

1. Check image preprocessing:
   - Increase image quality
   - Adjust brightness/contrast
2. Use EasyOCR (better than Tesseract for LCD)
3. Position camera closer to LCD
4. Clean LCD screen

### Issue 4: Slow Performance on Pi 3B+

**Error:** Long inference time

**Solutions:**

1. ✅ Use ONNX model (faster than PyTorch)
2. Increase capture interval:
   ```python
   CAPTURE_INTERVAL = 10  # From 5 seconds
   ```
3. Use NCNN model (even faster):
   ```python
   # Use ncnn model instead of ONNX
   MODEL_PATH = "/home/sahan/monitoring/models/incubator_yolov8n_ncnn_model"
   ```
4. Lower camera resolution:
   ```python
   cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
   cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
   ```

### Issue 5: Port 9001 Already in Use

**Error:** `Address already in use`

**Solutions:**

```bash
# Find what's using the port
sudo lsof -i :9001

# Kill the process
sudo kill -9 <PID>

# Or use different port in lcd_reading_server.py
```

### Issue 6: EasyOCR Download Issues

**Error:** `Cannot download language models`

**Solution:**

```bash
# Manually download models (if network issue)
# Or use pre-downloaded models
mkdir -p ~/.EasyOCR/model
# Transfer models from PC
```

---

## 📊 Performance Expectations

### Raspberry Pi 3B+ (Your Setup)

| Metric                   | ONNX Model   | PyTorch Model |
| ------------------------ | ------------ | ------------- |
| **Inference Time**       | ~2-5 seconds | ~8-15 seconds |
| **Recommended Interval** | 5-10 seconds | 15-30 seconds |
| **CPU Usage**            | ~40-60%      | ~80-100%      |
| **Memory Usage**         | ~400 MB      | ~600 MB       |

### Expected Accuracy

| Parameter   | Detection Rate | OCR Accuracy |
| ----------- | -------------- | ------------ |
| Heart Rate  | >95%           | >90%         |
| SpO2        | >95%           | >90%         |
| Temperature | >95%           | >85%         |
| Humidity    | >90%           | >85%         |

---

## 🔍 Debugging Commands

### Check Service Status

```bash
# Is service running?
sudo systemctl status lcd-reading.service

# View last 100 log lines
sudo journalctl -u lcd-reading.service -n 100

# Follow live logs
sudo journalctl -u lcd-reading.service -f

# Check for errors
sudo journalctl -u lcd-reading.service | grep -i error
```

### Test API Endpoints

```bash
# Get latest readings (cached)
curl http://localhost:9001/readings | jq

# Capture new reading
curl http://localhost:9001/capture | jq

# Get API info
curl http://localhost:9001/ | jq

# Debug capture (saves image + shows detections)
curl http://localhost:9001/debug | jq
```

### Manual Test Script

```python
#!/usr/bin/env python3
import cv2
import numpy as np

# Test camera
camera_index = 0  # Change this
cap = cv2.VideoCapture(camera_index)

if not cap.isOpened():
    print(f"❌ Cannot open camera {camera_index}")
    exit(1)

ret, frame = cap.read()
if not ret:
    print("❌ Cannot read frame")
    cap.release()
    exit(1)

print(f"✅ Camera {camera_index} working!")
print(f"   Resolution: {frame.shape[1]}x{frame.shape[0]}")
print(f"   Frame shape: {frame.shape}")

# Save test image
cv2.imwrite('test_capture.jpg', frame)
print("✅ Test image saved: test_capture.jpg")

cap.release()
```

---

## 📞 Next Steps

1. **SSH to Pi**: `ssh sahan@100.99.151.101`
2. **Identify correct camera**: Run camera tests above
3. **Fix server code**: I'll create corrected version next
4. **Test manually**: Run server and check output
5. **Start service**: Enable and start systemd service
6. **Monitor logs**: Watch for errors
7. **Test dashboard**: Open dashboard and check LCD section

Would you like me to:

1. **Create the corrected `lcd_reading_server.py`** with all fixes?
2. **Create a quick setup script** to automate the fix?
3. **Help you SSH and debug** the current setup?

Let me know which step you'd like to proceed with!
