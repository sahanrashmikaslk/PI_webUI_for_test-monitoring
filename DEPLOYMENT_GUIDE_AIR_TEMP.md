# 🚀 Air Temperature Integration - Complete Deployment Guide

## Overview

This guide will help you deploy the new YOLOv8 model (v4) with air temperature detection to your Raspberry Pi and integrate it across all dashboards and NTE calculations.

---

## 📋 Pre-Deployment Checklist

- [ ] New model trained: `incubator_yolov8n_v4.pt` with air_temp_value
- [ ] Model tested in Streamlit app locally
- [ ] SSH access to Raspberry Pi (100.89.162.22)
- [ ] Backup current model on Pi
- [ ] All backend services accessible

---

## Step 1: 🔍 Check Current Pi Services

### Connect to Pi via SSH

```powershell
ssh sahan@100.89.162.22
```

### Check running services

```bash
# View all monitoring services
./manage_services.sh status

# Specific services to check:
# - pi-health-server (Port 9000)
# - pi-cry-detector (Port 8888)
# - pi-camera-server (Port 8889)
# - pi-camera1-stream (Port 8080)
# - pi-camera2-stream (Port 8081)
# - LCD reading service (Port 9001) - if exists

# Check if LCD reading service exists
sudo systemctl status pi-lcd-reader
# OR check if process is running
ps aux | grep lcd_reading
```

### Check current model location

```bash
# Check models directory
ls -la /home/sahan/monitoring/models/

# Expected current model:
# incubator_yolov8n.pt (old - 4 parameters)
# incubator_yolov8n_v2.pt (if exists)
```

---

## Step 2: 📦 Upload New Model to Pi

### From Windows PowerShell:

```powershell
# Navigate to your trained model directory
cd C:\Users\sahan\Desktop\MYProjects\PI_webUI_for_test-monitoring\lcd_ocr_readings\notebooks\incubator\yolov8n-incubator-v4\weights

# Upload the new model to Pi
scp best.pt sahan@100.89.162.22:/home/sahan/monitoring/models/incubator_yolov8n_v4.pt

# Verify upload
ssh sahan@100.89.162.22 "ls -lh /home/sahan/monitoring/models/incubator_yolov8n_v4.pt"
```

---

## Step 3: 🔧 Update LCD Reading Server Script

### Create updated lcd_reading_server.py (see attached file)

The updated script includes:

- ✅ `air_temp_value` in CLASS_NAMES
- ✅ Air temperature validation ranges (20-40°C)
- ✅ Updated MODEL_PATH to v4
- ✅ Enhanced parameter ranges dictionary

### Upload updated script

```powershell
# From your Windows machine
scp C:\Users\sahan\Desktop\MYProjects\PI_webUI_for_test-monitoring\lcd_reading_server_v4.py sahan@100.89.162.22:/home/sahan/monitoring/lcd_reading_server.py
```

---

## Step 4: 🔄 Restart LCD Reading Service

### On the Pi:

```bash
# If service exists
sudo systemctl stop pi-lcd-reader
sudo systemctl start pi-lcd-reader
sudo systemctl status pi-lcd-reader

# OR if running as standalone script
# Find and kill old process
ps aux | grep lcd_reading_server
kill <PID>

# Start new one
cd /home/sahan/monitoring
python3 lcd_reading_server.py &

# Verify it's working
curl http://localhost:9001/readings
```

---

## Step 5: 🧪 Test LCD Reading API

### Test from Pi or Windows:

```bash
# Get readings
curl http://100.89.162.22:9001/readings

# Expected response should now include air_temp_value:
{
  "status": "success",
  "readings": {
    "heart_rate_value": {...},
    "spo2_value": {...},
    "skin_temp_value": {...},
    "humidity_value": {...},
    "air_temp_value": {
      "value": 36.5,
      "unit": "°C",
      "name": "Air Temperature",
      "detection_confidence": 0.85,
      "ocr_confidence": 0.92
    }
  },
  "timestamp": 1699...
}
```

---

## Step 6: 📊 Update Pi Test Dashboard (index.html)

### Update the main index.html on Pi

Location: `/var/www/html/index.html` or `/home/sahan/monitoring/index.html`

See attached `index_updated.html` file with:

- ✅ Air temperature display card
- ✅ Updated telemetry section
- ✅ Air temp chart
- ✅ NTE calculation using real air_temp

### Upload and deploy:

```powershell
# Upload updated index.html
scp C:\Users\sahan\Desktop\MYProjects\PI_webUI_for_test-monitoring\index_updated.html sahan@100.89.162.22:/var/www/html/index.html

# OR if using nginx
scp C:\Users\sahan\Desktop\MYProjects\PI_webUI_for_test-monitoring\index_updated.html sahan@100.89.162.22:/usr/share/nginx/html/index.html
```

---

## Step 7: 🌐 Update ThingsBoard Integration

### Update telemetry keys in parent backend or data sender

Files to update:

- `camera_server.py` or data posting script

Add air_temp_value to telemetry:

```python
telemetry = {
    'heart_rate': heart_rate,
    'spo2': spo2,
    'skin_temp': skin_temp,
    'humidity': humidity,
    'air_temp': air_temp,  # NEW
    'timestamp': timestamp
}
```

### Create ThingsBoard Dashboard Widget

1. Login to ThingsBoard
2. Navigate to your device dashboard
3. Add new widget for "Air Temperature"
4. Configure data key: `air_temp`
5. Set unit: °C
6. Configure alerts if needed

---

## Step 8: ⚛️ Update React Dashboard

### Files to update:

#### 1. DataContext.js

Add air_temp to data fetching:

```javascript
// Add to telemetry keys
const telemetryKeys = [
  "heart_rate",
  "spo2",
  "skin_temp",
  "humidity",
  "air_temp", // NEW
];
```

#### 2. ClinicalDashboard.js

Add air temperature display and NTE calculation with real value

#### 3. ParentPortal.js

Add air temperature to parent view

See attached React component files for complete updates.

### Deploy React updates:

```powershell
cd C:\Users\sahan\Desktop\MYProjects\PI_webUI_for_test-monitoring\incubator_monitoring_with_thingsboard_integration\react_dashboard

# Install dependencies if needed
npm install

# Build production version
npm run build

# Deploy to server (adjust path as needed)
scp -r build/* sahan@your-server:/var/www/react-dashboard/
```

---

## Step 9: 🧮 Update NTE Calculation Logic

### Current Issue

NTE is using hardcoded air temperature (35.0°C)

### Solution

Update NTE calculation to use real air_temp from LCD reading:

```javascript
// OLD (hardcoded)
const airTemp = 35.0;

// NEW (from telemetry)
const airTemp = telemetry.air_temp || 35.0; // fallback to 35 if not available
```

Apply this change in:

- React Dashboard: `ClinicalDashboard.js`
- Pi Dashboard: `index.html`
- Parent Backend: NTE calculation endpoint (if exists)

---

## Step 10: ✅ Testing & Validation

### 1. Test LCD Reading Service

```bash
curl http://100.89.162.22:9001/readings | jq
# Verify air_temp_value is present and has reasonable value (20-40°C)
```

### 2. Test Pi Dashboard

```
Open: http://100.89.162.22/index.html
- Check Air Temperature card displays value
- Check chart includes air temperature
- Verify NTE calculation uses real air temp
```

### 3. Test ThingsBoard

```
- Login to ThingsBoard
- Check device telemetry includes air_temp
- Verify dashboard widget shows current air temp
- Check historical data is being stored
```

### 4. Test React Dashboard

```
Open: http://localhost:3000 (or deployed URL)
- Clinical Dashboard shows air temperature
- Parent Portal displays air temp (if applicable)
- NTE calculation shows correct values with real air temp
```

### 5. End-to-End Test

```
1. Point camera at incubator display
2. Wait for LCD reading service to capture
3. Verify reading appears on Pi dashboard
4. Check ThingsBoard receives telemetry
5. Confirm React dashboard updates
6. Validate NTE calculation accuracy
```

---

## 🚨 Troubleshooting

### Model not loading

```bash
# Check model file exists and has correct permissions
ls -lh /home/sahan/monitoring/models/incubator_yolov8n_v4.pt
chmod 644 /home/sahan/monitoring/models/incubator_yolov8n_v4.pt
```

### Air temp not detected

```bash
# Check model was trained with air_temp annotations
# Verify CLASS_NAMES includes 'air_temp_value'
# Test with Streamlit app first to ensure model works
```

### Service not starting

```bash
# Check logs
sudo journalctl -u pi-lcd-reader -n 50
# OR
tail -f /home/sahan/monitoring/lcd_reader.log
```

### Readings not appearing on dashboard

```bash
# Check if API is accessible
curl http://100.89.162.22:9001/readings

# Check CORS headers
curl -v http://100.89.162.22:9001/readings

# Verify JavaScript console for errors
```

### NTE calculation still using 35.0

```
- Verify telemetry data includes air_temp field
- Check browser console for data structure
- Ensure fallback logic is working
- Validate air_temp is a number, not string
```

---

## 📝 Rollback Plan

If something goes wrong:

### 1. Restore old model

```bash
cd /home/sahan/monitoring/models
mv incubator_yolov8n.pt incubator_yolov8n_v4.pt.backup
mv incubator_yolov8n_v2.pt incubator_yolov8n.pt  # or restore from backup
```

### 2. Restore old script

```bash
git checkout lcd_reading_server.py
# OR restore from backup
cp lcd_reading_server.py.backup lcd_reading_server.py
```

### 3. Restart service

```bash
sudo systemctl restart pi-lcd-reader
```

---

## 📊 Validation Checklist

After deployment, verify:

- [ ] LCD reading service running without errors
- [ ] Air temperature detected in API response (9001/readings)
- [ ] Pi dashboard shows air temperature
- [ ] Air temp chart displays data
- [ ] ThingsBoard receives air_temp telemetry
- [ ] React dashboard displays air temperature
- [ ] NTE calculation uses real air temp (not 35.0)
- [ ] All 5 parameters displayed correctly
- [ ] Historical data being stored
- [ ] Alerts/notifications working (if configured)

---

## 🎯 Success Criteria

Deployment is successful when:

✅ All 5 parameters detected: heart_rate, spo2, skin_temp, humidity, **air_temp**
✅ Air temperature reading is between 20-40°C
✅ NTE suggestion uses **real air temperature** from LCD
✅ All dashboards show air temperature
✅ No performance degradation
✅ Services auto-restart on reboot

---

## 📞 Support

If you encounter issues:

1. Check service logs: `sudo journalctl -u pi-lcd-reader -f`
2. Test model locally in Streamlit first
3. Verify camera is accessible: `curl http://localhost:8081/?action=stream`
4. Check model file integrity: `md5sum incubator_yolov8n_v4.pt`

---

**Last Updated**: November 6, 2025
**Status**: Ready for Deployment
**Estimated Time**: 30-45 minutes
