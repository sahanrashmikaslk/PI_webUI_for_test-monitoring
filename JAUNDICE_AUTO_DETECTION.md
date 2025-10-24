# Jaundice Auto-Detection System

## Overview

Enhanced jaundice detection system with automatic detection every 10 minutes, ThingsBoard cloud integration, and React dashboard support.

## Features

### 1. Automatic Detection (10 Minutes)

- **Server-side automation**: Detection runs on the Pi every 10 minutes automatically
- **Background task**: Uses FastAPI's async task for non-blocking operation
- **No browser needed**: Runs continuously even when dashboard is closed

### 2. ThingsBoard Integration

- **Real-time publishing**: Sends detection results to ThingsBoard cloud
- **Telemetry data**:
  - `jaundice_detected`: Boolean (true/false)
  - `jaundice_confidence`: Percentage (0-100)
  - `jaundice_probability`: Percentage (0-100)
  - `jaundice_brightness`: Image brightness (0-255)
  - `jaundice_status`: "Normal" or "Jaundice"
  - `jaundice_reliability`: Lighting quality (0-100)
  - `timestamp`: Detection timestamp

### 3. Manual "Detect Now" Feature

- **Instant detection**: Click button to check immediately
- **Independent**: Works alongside automatic detection
- **Fast response**: 5-10 second analysis time

### 4. Dashboard Display

- **Live updates**: Polls server every 30 seconds for latest results
- **Detection indicators**:
  - 🤖 = Automatic detection (10 min)
  - 👆 = Manual detection (button click)
- **Status display**:
  - ✅ Normal / ⚠️ Jaundice Detected
  - Confidence percentage
  - Image brightness
  - Detection timestamp

## API Endpoints

### Server Running on Port 8887

1. **GET /detect** - Manual Detection

   - Triggers immediate jaundice detection
   - Returns: Full detection result with timestamp
   - Use: For "Detect Now" button clicks

2. **GET /latest** - Get Latest Result

   - Returns most recent detection (auto or manual)
   - Updates automatically every 10 min via server
   - Use: For dashboard polling

3. **GET /health** - Service Health

   - Check if service is running
   - Shows auto-detection status
   - Shows ThingsBoard connection status

4. **GET /** - API Information
   - Service status
   - Auto-detection configuration
   - Available endpoints

## How It Works

### Server Side (Pi)

```
┌─────────────────────────────────────────┐
│   Jaundice Detection Server (8887)     │
├─────────────────────────────────────────┤
│                                         │
│  ┌────────────────────────────────┐    │
│  │  Auto-Detection Loop           │    │
│  │  • Every 10 minutes            │    │
│  │  • Capture frame from camera   │    │
│  │  • Run ML model inference      │    │
│  │  • Store result                │    │
│  │  • Publish to ThingsBoard      │    │
│  └────────────────────────────────┘    │
│                                         │
│  ┌────────────────────────────────┐    │
│  │  Manual Detection Endpoint     │    │
│  │  • /detect                     │    │
│  │  • Immediate analysis          │    │
│  │  • Also publishes to TB        │    │
│  └────────────────────────────────┘    │
│                                         │
│  ┌────────────────────────────────┐    │
│  │  ThingsBoard Client            │    │
│  │  • MQTT connection             │    │
│  │  • Publish telemetry           │    │
│  │  • Auto-reconnect              │    │
│  └────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

### Dashboard Side (Browser)

```
┌─────────────────────────────────────────┐
│        Test Dashboard UI                │
├─────────────────────────────────────────┤
│                                         │
│  ┌────────────────────────────────┐    │
│  │  Polling Loop (30s)            │    │
│  │  • Fetch /latest endpoint      │    │
│  │  • Check for new timestamp     │    │
│  │  • Update display if changed   │    │
│  └────────────────────────────────┘    │
│                                         │
│  ┌────────────────────────────────┐    │
│  │  Detect Now Button             │    │
│  │  • Calls /detect endpoint      │    │
│  │  • Immediate result display    │    │
│  └────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

### React Dashboard (Via ThingsBoard)

```
┌─────────────────────────────────────────┐
│      React Dashboard                    │
├─────────────────────────────────────────┤
│                                         │
│  ┌────────────────────────────────┐    │
│  │  ThingsBoard WebSocket         │    │
│  │  • Real-time telemetry         │    │
│  │  • Jaundice data updates       │    │
│  │  • Historical data access      │    │
│  └────────────────────────────────┘    │
│                                         │
│  Display:                               │
│  • Jaundice Status (Normal/Detected)   │
│  • Confidence Score                    │
│  • Brightness Level                    │
│  • Detection Timestamp                 │
│  • Reliability Score                   │
│                                         │
└─────────────────────────────────────────┘
```

## Configuration

### Auto-Detection Interval

Edit `jaundice_server.py`:

```python
AUTO_DETECT_INTERVAL = 600  # 10 minutes in seconds
```

### ThingsBoard Connection

Location: `incubator_monitoring_with_thingsboard_integration/config/device_credentials.json`

```json
{
  "thingsboard_host": "your-server.com",
  "mqtt_port": 1883,
  "access_token": "your-device-token"
}
```

## Deployment

### 1. Update Service on Pi

```bash
# SSH to Pi
ssh sahan@100.89.162.22

# Stop service
sudo systemctl stop jaundice-detector

# Update service file if needed
sudo nano /etc/systemd/system/jaundice-detector.service

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl start jaundice-detector
sudo systemctl status jaundice-detector
```

### 2. Check Logs

```bash
# View service logs
journalctl -u jaundice-detector -f

# Look for:
# ✅ Model loaded successfully
# ✅ ThingsBoard connected successfully
# 🔄 Starting automatic detection
# ✓ Detection result: Normal (confidence: 95.23%)
# ✓ Jaundice data published to ThingsBoard
```

### 3. Test Dashboard

1. Open `index.html` in browser
2. Check "Jaundice Detection" section
3. Should show: "⏳ Waiting..." initially
4. Click "🔍 Detect Now" to test manual detection
5. Auto-detection updates appear every 10 minutes

## React Dashboard Integration

### 1. Add to ThingsBoard Widget

```javascript
// In your React component
const [jaundiceData, setJaundiceData] = useState({
  detected: false,
  confidence: 0,
  status: "Unknown",
  timestamp: null,
});

// Subscribe to telemetry
useEffect(() => {
  const keys = [
    "jaundice_detected",
    "jaundice_confidence",
    "jaundice_probability",
    "jaundice_brightness",
    "jaundice_status",
    "jaundice_reliability",
  ];

  // ThingsBoard subscription code here
  // Update jaundiceData when new telemetry arrives
}, []);
```

### 2. Display Component

```jsx
<Card>
  <CardHeader>
    <h3>Jaundice Detection</h3>
  </CardHeader>
  <CardBody>
    <div className={`status ${jaundiceData.detected ? "warning" : "normal"}`}>
      {jaundiceData.detected ? "⚠️ Jaundice Detected" : "✅ Normal"}
    </div>
    <div className="metrics">
      <Metric label="Confidence" value={`${jaundiceData.confidence}%`} />
      <Metric label="Status" value={jaundiceData.status} />
      <Metric label="Last Check" value={formatTime(jaundiceData.timestamp)} />
    </div>
  </CardBody>
</Card>
```

## Data Flow

```
Camera (8081)
    ↓
Jaundice Server (8887)
    ↓ (every 10 min)
ML Model Inference
    ↓
Result Storage
    ↓
    ├─→ ThingsBoard MQTT → React Dashboard
    └─→ /latest endpoint → Test Dashboard
```

## Monitoring & Debugging

### Check Service Status

```bash
# On Pi
sudo systemctl status jaundice-detector

# Should show:
# Active: active (running)
# Memory usage
# Recent log lines
```

### Check ThingsBoard Connection

```bash
# On Pi - check service logs
journalctl -u jaundice-detector -n 50

# Look for:
# ✓ Connected to ThingsBoard successfully
# ✓ Jaundice data published to ThingsBoard
```

### Check Detection Results

```bash
# From any machine
curl http://100.89.162.22:8887/latest

# Returns:
# {
#   "status": "success",
#   "jaundice_detected": false,
#   "predicted_class": "Normal",
#   "confidence": 0.9523,
#   "probability": 0.0477,
#   "brightness": 87.3,
#   "reliability": 1.0,
#   "timestamp": "2025-10-24T10:30:15",
#   "detection_type": "auto"
# }
```

## Troubleshooting

### Problem: No auto-detections appearing

**Solution:**

1. Check service is running: `sudo systemctl status jaundice-detector`
2. Check logs: `journalctl -u jaundice-detector -f`
3. Verify camera stream: `curl http://localhost:8081/?action=stream`

### Problem: ThingsBoard not receiving data

**Solution:**

1. Check credentials in config file
2. Test MQTT connection: `mosquitto_pub -h your-server.com -p 1883 -u "your-token" -P "" -t "v1/devices/me/telemetry" -m "{}"`
3. Check firewall rules

### Problem: Dashboard not updating

**Solution:**

1. Check browser console for errors
2. Verify Pi IP is correct
3. Test endpoint: `curl http://100.89.162.22:8887/latest`

## Performance

- **Detection time**: 3-5 seconds per inference
- **Memory usage**: ~200MB (model + FastAPI)
- **CPU usage**: Spike during inference, idle otherwise
- **Network**: ~500 bytes per ThingsBoard publish

## Future Enhancements

1. **Configurable Interval**: Add API endpoint to change detection interval
2. **Alert Thresholds**: Notify when jaundice detected multiple times
3. **Historical Trends**: Store detection history on Pi
4. **Image Storage**: Save frames when jaundice detected
5. **Multiple Cameras**: Support detection from multiple infants

## Files Modified

1. `jaundice_detection/jaundice_server.py` - Main detection server
2. `index.html` - Dashboard UI and JavaScript
3. `JAUNDICE_AUTO_DETECTION.md` - This documentation

## Version

- **Version**: 2.0.0
- **Date**: October 24, 2025
- **Author**: Auto-detection + ThingsBoard integration
