# 🚀 Quick Start: LCD Reading Integration

## What You Have Now

I've created a complete system to integrate your incubator LCD display reading into the monitoring dashboard. Here's what's included:

### 📁 New Files Created

1. **`convert_model_to_onnx.py`** - Converts your `.pt` model to ONNX format for better Pi performance
2. **`lcd_reading_server.py`** - HTTP server that runs on Pi, reads LCD display via YOLO + OCR
3. **`setup_lcd_reading.sh`** - Automated setup script for Raspberry Pi
4. **`dashboard_lcd_section.html`** - HTML/JS code to add to your dashboard
5. **`INTEGRATION_GUIDE.md`** - Detailed step-by-step guide
6. **`README_LCD_INTEGRATION.md`** - This file (quick reference)

### 🎯 What It Does

The system:

- ✅ **Captures** frames from LCD display camera every 5 seconds
- ✅ **Detects** display regions using YOLOv8 (ONNX optimized)
- ✅ **Extracts** text using EasyOCR
- ✅ **Validates** readings against medical ranges
- ✅ **Corrects** common OCR errors automatically
- ✅ **Serves** data as JSON via HTTP API (port 9001)
- ✅ **Displays** on your monitoring dashboard

### 📊 Parameters Monitored

| Parameter        | Range     | Unit | Display Color |
| ---------------- | --------- | ---- | ------------- |
| Heart Rate       | 60-220    | bpm  | Red (❤️)      |
| SpO2             | 70-100    | %    | Cyan (🫁)     |
| Skin Temperature | 32.0-39.0 | °C   | Yellow (🌡️)   |
| Humidity         | 30-95     | %    | Purple (💧)   |

---

## 🏃 Quick Start (3 Steps)

### **Step 1: Convert Model (on Windows PC)**

```powershell
# In your project directory
cd lcd_ocr_readings
python convert_model_to_onnx.py
```

This creates `incubator_yolov8n.onnx` in the `models/` folder.

### **Step 2: Transfer to Raspberry Pi**

```powershell
# Transfer model
scp lcd_ocr_readings/models/incubator_yolov8n.onnx sahan@192.168.8.137:/home/sahan/monitoring/models/

# Transfer server script
scp lcd_reading_server.py sahan@192.168.8.137:/home/sahan/monitoring/

# Transfer setup script
scp setup_lcd_reading.sh sahan@192.168.8.137:/home/sahan/monitoring/
```

### **Step 3: Run Setup on Pi**

```bash
# SSH into Pi
ssh sahan@192.168.8.137

# Go to monitoring directory
cd /home/sahan/monitoring

# Make setup script executable
chmod +x setup_lcd_reading.sh

# Run setup
./setup_lcd_reading.sh
```

The setup script will:

- Install all dependencies (OpenCV, ONNX Runtime, EasyOCR)
- Create systemd service for auto-start
- Test camera access
- Start the service

**That's it!** The LCD reading server is now running on port 9001.

---

## 🧪 Test It Works

```bash
# Test the API
curl http://localhost:9001/readings

# Expected output:
{
  "status": "success",
  "readings": {
    "heart_rate_value": {
      "value": 145,
      "unit": "bpm",
      ...
    },
    "spo2_value": { ... },
    "skin_temp_value": { ... },
    "humidity_value": { ... }
  },
  "timestamp": 1728663420.5
}
```

---

## 🖥️ Add to Dashboard

### Option 1: Manual Integration (Recommended)

1. **Open `index.html` in your editor**

2. **Find the System Health section** (around line 820)

3. **Add the LCD section after it** - Copy the HTML from `dashboard_lcd_section.html`:

   - HTML markup for the LCD card
   - JavaScript functions for fetching data

4. **Save and reload** your dashboard

### Option 2: Quick Test (Separate Page)

Create a simple test page:

```html
<!DOCTYPE html>
<html>
  <head>
    <title>LCD Test</title>
  </head>
  <body>
    <h1>LCD Readings</h1>
    <div id="readings"></div>

    <script>
      setInterval(async () => {
        const response = await fetch("http://192.168.8.137:9001/readings");
        const data = await response.json();
        document.getElementById("readings").innerHTML =
          "<pre>" + JSON.stringify(data, null, 2) + "</pre>";
      }, 5000);
    </script>
  </body>
</html>
```

---

## 📱 API Endpoints

Your LCD reading server provides 3 endpoints:

### GET `/readings` (Fast - uses cached data)

```bash
curl http://192.168.8.137:9001/readings
```

### GET `/capture` (Slower - captures new frame)

```bash
curl http://192.168.8.137:9001/capture
```

### GET `/` (API info)

```bash
curl http://192.168.8.137:9001/
```

---

## 🔧 Configuration

Edit `lcd_reading_server.py` to adjust settings:

```python
# Camera (which camera is connected to LCD display)
LCD_CAMERA_INDEX = 1  # Try 0, 1, or 2

# Capture frequency
CAPTURE_INTERVAL = 5  # seconds (5-10 recommended)

# Detection confidence
CONFIDENCE_THRESHOLD = 0.25  # (0.1-0.9, lower = more detections)

# Model path
MODEL_PATH = "/home/sahan/monitoring/models/incubator_yolov8n.onnx"
```

---

## 🛠️ Service Management

```bash
# Check status
sudo systemctl status lcd-reading.service

# View logs
sudo journalctl -u lcd-reading.service -f

# Restart service
sudo systemctl restart lcd-reading.service

# Stop service
sudo systemctl stop lcd-reading.service

# Start service
sudo systemctl start lcd-reading.service

# Disable auto-start
sudo systemctl disable lcd-reading.service
```

---

## 🐛 Troubleshooting

### Problem: Camera not found

```bash
# List cameras
v4l2-ctl --list-devices

# Try different camera index
python3 -c "import cv2; cap = cv2.VideoCapture(1); print(cap.isOpened())"
```

### Problem: Low detection accuracy

1. **Improve lighting** - Add LED light
2. **Position camera** - Perpendicular to display
3. **Clean LCD** - Remove reflections
4. **Adjust confidence** - Lower threshold

### Problem: Slow inference

1. **Use ONNX model** (not .pt)
2. **Increase interval** - Set to 10 seconds
3. **Check CPU usage** - `htop`

### Problem: Wrong readings

1. **Check raw OCR text** in API response
2. **Adjust ranges** in `PARAMETER_RANGES`
3. **View logs** - `sudo journalctl -u lcd-reading.service -f`

---

## 📊 Dashboard Integration Preview

Once added to your dashboard, you'll see:

```
┌─────────────────────────────────────┐
│ 📊 Incubator Parameters    [▶️ Start]│
├─────────────────────────────────────┤
│ Status: ✅ 4 parameters detected    │
├──────────────────┬──────────────────┤
│ ❤️ Heart Rate    │ 🫁 SpO2          │
│ 145 bpm          │ 98%              │
│ Confidence: 89%  │ Confidence: 91%  │
├──────────────────┼──────────────────┤
│ 🌡️ Skin Temp     │ 💧 Humidity      │
│ 36.5°C           │ 65%              │
│ Confidence: 87%  │ Confidence: 88%  │
└──────────────────┴──────────────────┘
Last update: 10:45:23 AM
```

---

## 🎯 Performance Expectations

### Raspberry Pi 4:

- **Inference time**: ~2-3 seconds per frame
- **Update interval**: 5 seconds (recommended)
- **CPU usage**: ~15-20%

### Raspberry Pi 3:

- **Inference time**: ~5-7 seconds per frame
- **Update interval**: 10 seconds (recommended)
- **CPU usage**: ~30-40%

---

## 📚 Additional Resources

- **Full guide**: `INTEGRATION_GUIDE.md`
- **Dashboard code**: `dashboard_lcd_section.html`
- **Original OCR project**: `lcd_ocr_readings/README.md`
- **Server source**: `lcd_reading_server.py`

---

## ✅ Checklist

- [ ] Convert model to ONNX
- [ ] Transfer files to Pi
- [ ] Run setup script
- [ ] Test API endpoints
- [ ] Add dashboard HTML/JS
- [ ] Position camera properly
- [ ] Test with actual LCD display
- [ ] Monitor logs for errors
- [ ] Adjust settings if needed

---

## 🆘 Need Help?

1. **Check logs**: `sudo journalctl -u lcd-reading.service -n 100`
2. **Test API**: `curl http://localhost:9001/readings`
3. **Verify camera**: `python3 -c "import cv2; cap = cv2.VideoCapture(1); print(cap.isOpened())"`
4. **Read full guide**: `INTEGRATION_GUIDE.md`

---

## 🎉 You're Done!

Your monitoring dashboard now includes:

- ✅ Dual camera streams
- ✅ Cry detection
- ✅ System health monitoring
- ✅ **LCD parameter reading** (NEW!)
- ✅ SSH terminal access

All in one unified interface! 🚀
