# 🔍 Pi Device Status Report - Current Configuration

**Date:** November 6, 2025
**Pi IP:** 100.89.162.22
**User:** sahan

---

## ✅ Currently Running Services

### 1. **LCD Reading Server** ⚡ MAIN SERVICE

- **Process:** `python3 /home/sahan/monitoring/lcd_reading_server.py`
- **PID:** 840
- **CPU Usage:** 108% (high usage - needs optimization)
- **Memory:** 626MB (16.1%)
- **Port:** 9001
- **Status:** ✅ RUNNING & WORKING
- **Current Model:** `/home/sahan/monitoring/models/incubator_yolov8n.pt` (v1 - **NO AIR TEMP**)
- **Detected Parameters:** 4 (heart_rate, spo2, skin_temp, humidity) ❌ **Missing air_temp**

### 2. **Cry Detector Service**

- **Process:** `/usr/bin/python3 /home/sahan/cry_detector.py`
- **PID:** 838, 11608
- **Port:** Likely 8888
- **Status:** ✅ RUNNING

### 3. **Cry Classification Service**

- **Process:** `/usr/bin/python3 -m uvicorn cry_classification_service:app`
- **Port:** 8890
- **Status:** ✅ RUNNING

### 4. **Health Server**

- **Process:** `python3 /home/sahan/simple_health_server.py`
- **PID:** 839
- **Status:** ✅ RUNNING

### 5. **NTE Server**

- **Process:** `/usr/bin/python3 /home/sahan/nte_server.py`
- **PID:** 841, 11808
- **Status:** ✅ RUNNING
- **Note:** This likely uses hardcoded air temp for NTE calculations

### 6. **Test Dashboard Server**

- **Process:** `/usr/bin/python3 /home/sahan/test_dashboard_server.py`
- **PID:** 842
- **Service:** pi-test-dashboard.service
- **Status:** ✅ RUNNING

### 7. **Jaundice Detection Server**

- **Process:** `python3 /home/sahan/jaundice_detection/jaundice_server.py`
- **PID:** 922
- **Status:** ✅ RUNNING

### 8. **LCD Reader (ThingsBoard Integration)**

- **Process:** `python3 /home/sahan/incubator_monitoring_with_thingsboard_integration/pi_client/lcd_reader.py`
- **PID:** 940
- **Status:** ✅ RUNNING
- **Note:** This is separate from main LCD reading server

### 9. **Camera Server**

- **Process:** `python3 /home/sahan/camera_server.py`
- **PID:** 1025
- **Status:** ✅ RUNNING

---

## 📦 Available Models on Pi

```
/home/sahan/monitoring/models/
├── incubator_yolov8n.pt        (6.0MB) - ✅ CURRENTLY IN USE
├── incubator_yolov8n_v2.pt     (6.0MB) - Available
└── incubator_yolov8n.onnx      (12MB)  - ONNX format
```

**⚠️ MISSING:** `incubator_yolov8n_v4.pt` (with air_temp support)

---

## 🔧 Current LCD Reading Server Configuration

### Model Settings

```python
MODEL_PATH = "/home/sahan/monitoring/models/incubator_yolov8n.pt"
CONFIDENCE_THRESHOLD = 0.25
LCD_PORT = 9001
```

### Parameter Detection (Current)

```python
PARAMETER_RANGES = {
    'heart_rate_value': {'min': 60, 'max': 220, 'unit': 'bpm'},
    'spo2_value': {'min': 70, 'max': 100, 'unit': '%'},
    'skin_temp_value': {'min': 32.0, 'max': 39.0, 'unit': '°C'},
    'humidity_value': {'min': 30, 'max': 99, 'unit': '%'}
}
```

❌ **MISSING:** `'air_temp_value'` parameter

### Class Names (Current)

```python
CLASS_NAMES = ['heart_rate_value', 'humidity_value', 'skin_temp_value', 'spo2_value']
```

❌ **MISSING:** `'air_temp_value'` in class names

---

## 📊 Current API Response (Test)

**Endpoint:** `http://100.89.162.22:9001/readings`

**Response:**

```json
{
  "status": "success",
  "readings": {
    "spo2_value": {
      "value": 98,
      "unit": "%",
      "detection_confidence": 0.89,
      "ocr_confidence": 1.0
    },
    "humidity_value": {
      "value": 60,
      "unit": "%",
      "detection_confidence": 0.79,
      "ocr_confidence": 0.26
    },
    "heart_rate_value": {
      "value": 162,
      "unit": "bpm",
      "detection_confidence": 0.84,
      "ocr_confidence": 1.0
    },
    "skin_temp_value": {
      // ... (not shown in first 30 lines)
    }
  }
}
```

✅ Working with 4 parameters
❌ No `air_temp_value` in response

---

## 🎯 Required Changes for Air Temperature Integration

### 1. Upload New Model

```bash
# From Windows to Pi
scp C:\Users\sahan\Desktop\MYProjects\PI_webUI_for_test-monitoring\lcd_ocr_readings\notebooks\incubator\yolov8n-incubator-v4\weights\best.pt \
    sahan@100.89.162.22:/home/sahan/monitoring/models/incubator_yolov8n_v4.pt
```

### 2. Update lcd_reading_server.py

**Changes needed:**

- ✏️ MODEL_PATH: `/home/sahan/monitoring/models/incubator_yolov8n_v4.pt`
- ✏️ Add `air_temp_value` to PARAMETER_RANGES
- ✏️ Add `air_temp_value` to CLASS_NAMES
- ✏️ Update class mapping to match v4 model

### 3. Update LCD Reader (ThingsBoard Integration)

**File:** `/home/sahan/incubator_monitoring_with_thingsboard_integration/pi_client/lcd_reader.py`

- ✏️ Add air_temp to telemetry posting

### 4. Update NTE Server

**File:** `/home/sahan/nte_server.py`

- ✏️ Use real air_temp from LCD reading instead of hardcoded 35.0°C

### 5. Restart Services

```bash
# Kill current LCD reading server
kill 840

# Start with new configuration
cd /home/sahan/monitoring
python3 lcd_reading_server.py &

# Or if using systemd
sudo systemctl restart pi-lcd-reader
```

---

## ⚠️ Critical Observations

### Performance Issue

The LCD reading server is using **108% CPU** - this is very high and suggests:

- Continuous frame processing without delay
- No frame skipping
- Possibly running detection on every frame
- **Recommendation:** Add frame delay or reduce capture frequency

### Multiple LCD Readers

There are **TWO** LCD reading processes:

1. `/home/sahan/monitoring/lcd_reading_server.py` (Port 9001)
2. `/home/sahan/incubator_monitoring_with_thingsboard_integration/pi_client/lcd_reader.py`

**Question:** Are both needed? Should they use the same model?

### NTE Calculation

NTE server is running separately - needs to be updated to use real air_temp from LCD readings.

---

## ✅ Deployment Checklist

- [ ] 1. Backup current model and script
- [ ] 2. Upload `incubator_yolov8n_v4.pt` to Pi
- [ ] 3. Update `lcd_reading_server.py` configuration
- [ ] 4. Update `pi_client/lcd_reader.py` for ThingsBoard
- [ ] 5. Update `nte_server.py` to use real air_temp
- [ ] 6. Test API endpoint for air_temp_value
- [ ] 7. Update Pi test dashboard HTML
- [ ] 8. Update React dashboard
- [ ] 9. Verify ThingsBoard receives air_temp
- [ ] 10. Test NTE calculations with real air_temp

---

## 🔗 Service Dependencies

```
LCD Reading Server (Port 9001)
    ↓
    ├─→ Test Dashboard (displays readings)
    ├─→ ThingsBoard Integration (sends telemetry)
    ├─→ NTE Server (calculates thermal range)
    └─→ React Dashboard (displays in UI)
```

---

## 📝 Next Steps

1. **Upload the new v4 model** to Pi
2. **Update the configuration** files (already done locally)
3. **Test on Pi** before deploying to production
4. **Monitor CPU usage** - optimize if needed
5. **Update all dependent services**

---

**Status:** Ready for Deployment
**Estimated Downtime:** 5-10 minutes
**Risk Level:** Medium (active service replacement)
