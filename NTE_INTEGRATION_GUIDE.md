# NTE Recommendation Engine Integration Guide

## 🎯 Overview

This guide explains how to integrate the NTE (Neutral Thermal Environment) Recommendation Engine into your Raspberry Pi incubator monitoring system.

## 📋 Features

✅ **Baby Registration** - Register babies with birth date/time and weight  
✅ **Automatic Age Calculation** - Age calculated in real-time from birth date  
✅ **NTE Range Calculation** - Based on baby's age and weight  
✅ **Recommendations** - Real-time temperature, humidity, and skin temp advice  
✅ **ThingsBoard Integration** - Publishes NTE data to ThingsBoard  
✅ **Test Dashboard UI** - Easy-to-use web interface  
✅ **Hardcoded Air Temperature** - Uses 28°C until LCD reader is trained

## 🏗️ Architecture

```
┌─────────────────┐
│  Test Dashboard │ (Port 8090)
│   (index.html)  │
└────────┬────────┘
         │ HTTP REST
         ▼
┌─────────────────┐
│   NTE Server    │ (Port 8886)
│  (nte_server.py)│
└────────┬────────┘
         │ MQTT
         ▼
┌─────────────────┐
│  ThingsBoard    │
│   Cloud MQTT    │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ React Dashboard │
│ (Port 3000)     │
└─────────────────┘
```

## 📁 Files Created

1. **nte_server.py** - FastAPI server for NTE recommendations
2. **nte-server.service** - Systemd service file
3. **index.html** - Updated test dashboard with NTE UI
4. **baby_data.json** - Baby registration data (auto-created)

## 🔧 Installation Steps

### 1. Install Dependencies

```bash
# On Raspberry Pi
cd /home/sahan
pip3 install fastapi uvicorn paho-mqtt
```

### 2. Deploy Files

```powershell
# From Windows machine
scp nte_server.py sahan@100.89.162.22:/home/sahan/
scp nte-server.service sahan@100.89.162.22:/home/sahan/
scp index.html sahan@100.89.162.22:/home/sahan/test_dashboard.html
```

### 3. Setup Systemd Service

```bash
# On Raspberry Pi
sudo cp /home/sahan/nte-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable nte-server
sudo systemctl start nte-server
sudo systemctl status nte-server
```

### 4. Verify Installation

```bash
# Check if NTE server is running
curl http://localhost:8886/

# Check health endpoint
curl http://localhost:8886/health
```

### 5. Restart Test Dashboard

```bash
sudo systemctl restart pi-test-dashboard
```

## 🎨 Test Dashboard Usage

### Step 1: Register a Baby

1. Open test dashboard: http://192.168.1.232:8090/
2. Scroll to **NTE Recommendation Engine** section
3. Fill in baby registration form:
   - **Baby ID**: Unique identifier (e.g., "BABY-001")
   - **Baby Name**: Optional name
   - **Birth Date**: Select date
   - **Birth Time**: Select time (24-hour format)
   - **Weight**: Enter weight in grams (500-5000g)
4. Click **✅ Register**

### Step 2: Select Active Baby

1. Click **🔄** button to refresh baby list
2. Select baby from dropdown
3. NTE status display will appear showing:
   - Baby info (age, weight)
   - NTE range (target temperature)
   - Current readings
   - Recommendations

### Step 3: Monitor NTE

1. Click **▶️ Start** to begin automatic monitoring
2. Recommendations update every 60 seconds
3. Click **🔍 Check Recommendations** for manual check
4. Click **⏹️ Stop** to stop monitoring

## 📊 API Endpoints

### Baby Management

```http
POST /baby/register
{
  "baby_id": "BABY-001",
  "name": "Baby Name",
  "birth_date": "2025-10-25",
  "birth_time": "14:30",
  "weight_g": 2500
}

GET /baby/list
GET /baby/{baby_id}
PUT /baby/{baby_id}
DELETE /baby/{baby_id}
```

### NTE Recommendations

```http
POST /recommendations
{
  "baby_id": "BABY-001",
  "air_temp": null,      # Uses 28°C if null
  "skin_temp": null,     # Optional
  "humidity": null       # Optional
}
```

### Health Check

```http
GET /health
GET /
```

## 🔗 ThingsBoard Integration

### Published Telemetry Keys

The NTE server publishes the following data to ThingsBoard:

```json
{
  "nte_baby_id": "BABY-001",
  "nte_age_hours": 48.5,
  "nte_weight_g": 2500,
  "nte_range_min": 31.0,
  "nte_range_max": 33.2,
  "nte_advice_count": 3,
  "nte_critical_count": 0,
  "nte_warning_count": 1,
  "nte_info_count": 2,
  "nte_latest_advice": "Air temperature within NTE range",
  "nte_latest_detail": "28.0 °C; NTE 31.0–33.2 °C.",
  "nte_timestamp": 1729876543000
}
```

### View in ThingsBoard

1. Login to https://thingsboard.cloud
2. Go to **Devices** → **INC-001** → **Latest Telemetry**
3. Look for keys starting with `nte_`

## 🎯 React Dashboard Integration

### Add NTE Widget to React Dashboard

1. Create new component: `src/components/NTEWidget.js`

```jsx
import React, { useEffect, useState } from "react";
import { Card } from "antd";

const NTEWidget = ({ thingsBoardData }) => {
  const [nteData, setNTEData] = useState(null);

  useEffect(() => {
    if (thingsBoardData) {
      setNTEData({
        babyId: extractValue(thingsBoardData.nte_baby_id),
        ageHours: extractValue(thingsBoardData.nte_age_hours),
        weightG: extractValue(thingsBoardData.nte_weight_g),
        rangeMin: extractValue(thingsBoardData.nte_range_min),
        rangeMax: extractValue(thingsBoardData.nte_range_max),
        criticalCount: extractValue(thingsBoardData.nte_critical_count),
        warningCount: extractValue(thingsBoardData.nte_warning_count),
        latestAdvice: extractValue(thingsBoardData.nte_latest_advice),
        timestamp: extractValue(thingsBoardData.nte_timestamp),
      });
    }
  }, [thingsBoardData]);

  const extractValue = (field, defaultValue = 0) => {
    if (!field) return defaultValue;
    if (Array.isArray(field) && field.length > 0) {
      return field[0].value;
    }
    return defaultValue;
  };

  if (!nteData) {
    return <Card>Loading NTE data...</Card>;
  }

  return (
    <Card title="🌡️ NTE Recommendations">
      <div>
        <h3>Baby: {nteData.babyId}</h3>
        <p>Age: {nteData.ageHours.toFixed(1)} hours</p>
        <p>Weight: {nteData.weightG}g</p>
        <h4>
          NTE Range: {nteData.rangeMin}°C - {nteData.rangeMax}°C
        </h4>
        <div>
          {nteData.criticalCount > 0 && (
            <span className="badge badge-danger">
              🚨 {nteData.criticalCount} Critical
            </span>
          )}
          {nteData.warningCount > 0 && (
            <span className="badge badge-warning">
              ⚠️ {nteData.warningCount} Warnings
            </span>
          )}
        </div>
        <p>{nteData.latestAdvice}</p>
      </div>
    </Card>
  );
};

export default NTEWidget;
```

2. Add to dashboard:

```jsx
import NTEWidget from "./components/NTEWidget";

// In your dashboard component
<NTEWidget thingsBoardData={latestVitals} />;
```

## ⚙️ Configuration

### Hardcoded Air Temperature

Currently set to **28°C** in `nte_server.py`:

```python
DEFAULT_AIR_TEMP = 28.0  # °C
```

### Future: LCD Reader Integration

Once LCD reader model is trained to read air temperature:

1. Update `lcd_reading_server.py` to extract air temperature
2. Publish to ThingsBoard as `air_temp`
3. Update NTE server to fetch from ThingsBoard:

```python
# In checkNTERecommendations() in index.html
const requestData = {
  baby_id: activeBabyId,
  air_temp: latestVitals.air_temp,  // From ThingsBoard
  skin_temp: latestVitals.skin_temp,
  humidity: latestVitals.humidity
};
```

## 🐛 Troubleshooting

### NTE Server Not Starting

```bash
# Check logs
sudo journalctl -u nte-server -n 50 -f

# Check if port 8886 is in use
sudo netstat -tulpn | grep 8886

# Restart service
sudo systemctl restart nte-server
```

### ThingsBoard Not Publishing

```bash
# Check device credentials
cat /home/sahan/incubator_monitoring_with_thingsboard_integration/config/device_credentials.json

# Check MQTT connection
sudo journalctl -u nte-server -n 100 | grep -i thingsboard

# Test MQTT manually
mosquitto_pub -h thingsboard.cloud -p 1883 -u YOUR_ACCESS_TOKEN -t v1/devices/me/telemetry -m '{"test":1}'
```

### Baby Data Not Persisting

```bash
# Check if baby_data.json exists
ls -la /home/sahan/baby_data.json

# Check permissions
sudo chown sahan:sahan /home/sahan/baby_data.json
sudo chmod 644 /home/sahan/baby_data.json
```

### Test Dashboard Not Showing NTE

1. Open browser DevTools (F12)
2. Check Console tab for errors
3. Check Network tab for failed API calls
4. Verify NTE server is running: `curl http://192.168.1.232:8886/health`

## 📝 Example Workflow

### Complete Example

```bash
# 1. Register a baby
curl -X POST http://192.168.1.232:8886/baby/register \
  -H "Content-Type: application/json" \
  -d '{
    "baby_id": "BABY-001",
    "name": "John Doe",
    "birth_date": "2025-10-25",
    "birth_time": "08:30",
    "weight_g": 2800
  }'

# 2. Get baby list
curl http://192.168.1.232:8886/baby/list

# 3. Get recommendations
curl -X POST http://192.168.1.232:8886/recommendations \
  -H "Content-Type: application/json" \
  -d '{
    "baby_id": "BABY-001",
    "air_temp": null,
    "skin_temp": 36.8,
    "humidity": 55
  }'

# 4. Update baby weight
curl -X PUT http://192.168.1.232:8886/baby/BABY-001 \
  -H "Content-Type: application/json" \
  -d '{
    "weight_g": 2850
  }'
```

## 🔐 Security Notes

1. **Baby Data Storage**: Currently stored in JSON file. For production, use a database.
2. **Authentication**: No authentication currently. Add JWT tokens for production.
3. **HTTPS**: Use nginx reverse proxy with SSL certificate for production.

## 📚 Additional Resources

- NTE Rules: `NTE_recommendation_engine/nte_rules.py`
- ThingsBoard Docs: https://thingsboard.io/docs/
- FastAPI Docs: https://fastapi.tiangolo.com/

## ✅ Verification Checklist

- [ ] NTE server running on port 8886
- [ ] Test dashboard shows NTE section
- [ ] Baby registration works
- [ ] Baby list loads correctly
- [ ] NTE recommendations display
- [ ] ThingsBoard receives NTE telemetry
- [ ] Auto-monitoring works (60s interval)
- [ ] Manual check works
- [ ] React dashboard can fetch NTE data

## 🚀 Next Steps

1. **Train LCD Reader** - Add air temperature OCR detection
2. **Add Sensors** - Connect skin temperature and humidity sensors
3. **Database** - Replace JSON file with PostgreSQL/MongoDB
4. **Alerts** - Add critical alert notifications (SMS/Email)
5. **Historical Data** - Store NTE recommendations history
6. **Multi-Baby** - Support multiple babies in different incubators

---

**Last Updated**: October 25, 2025  
**Status**: ✅ Ready for Deployment  
**Version**: 1.0.0
