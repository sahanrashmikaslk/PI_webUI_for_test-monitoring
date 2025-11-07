# 🚀 Quick Deploy - Hybrid Cry Detection System

## One-Command Deployment (Copy-Paste Ready)

### 1️⃣ Upload Files to Pi (From Local Machine)

```bash
cd c:\Users\sahan\Desktop\MYProjects\PI_webUI_for_test-monitoring
scp cry_classification_service.py cry_detector_enhanced.py sahan@100.89.162.22:/home/sahan/
scp cry-classification.service sahan@100.89.162.22:/tmp/
```

### 2️⃣ SSH to Pi

```bash
ssh sahan@100.89.162.22
```

### 3️⃣ Install Dependencies (One Command)

```bash
pip3 install fastapi uvicorn python-multipart tensorflow tensorflow-hub librosa soundfile requests --break-system-packages
```

### 4️⃣ Setup Classification Service

```bash
# Move service file
sudo cp /tmp/cry-classification.service /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload && \
sudo systemctl enable cry-classification.service && \
sudo systemctl start cry-classification.service

# Verify it's running
sudo systemctl status cry-classification.service
curl http://localhost:8890/health
```

### 5️⃣ Update Cry Detector

```bash
# Backup original
sudo cp /home/sahan/cry_detector.py /home/sahan/cry_detector.py.backup

# Replace with enhanced version
sudo cp /home/sahan/cry_detector_enhanced.py /home/sahan/cry_detector.py

# Restart service
sudo systemctl restart cry-detector.service

# Check status
sudo systemctl status cry-detector.service
```

### 6️⃣ Monitor Both Services

```bash
# Terminal 1: Watch cry detector
sudo journalctl -u cry-detector.service -f

# Terminal 2: Watch classification service
sudo journalctl -u cry-classification.service -f
```

## ⚡ Quick Tests

### Test 1: Check Services Are Running

```bash
systemctl is-active cry-detector.service cry-classification.service
# Expected: active, active
```

### Test 2: Check Ports

```bash
netstat -tuln | grep -E '8888|8890'
# Expected:
# 0.0.0.0:8888 (cry detector)
# 0.0.0.0:8890 (classification service)
```

### Test 3: Test Classification API

```bash
curl http://localhost:8890/health
# Expected: {"status":"healthy","models_loaded":true}
```

### Test 4: Check Cry Detector Status

```bash
curl http://localhost:8888/cry/status | jq
# Expected: JSON with classification_enabled:true, classification_service_available:true
```

## 🐛 Quick Fixes

### Issue: Classification service won't start

```bash
# Check what's wrong
sudo journalctl -u cry-classification.service -n 20

# Common fix: Kill port 8890 process
sudo lsof -i :8890 | grep LISTEN | awk '{print $2}' | xargs sudo kill -9

# Restart
sudo systemctl restart cry-classification.service
```

### Issue: Models not loading

```bash
# Verify model files exist
ls -la ~/Cry-Detection-Classification-Model/cry_project/det_models/
ls -la ~/Cry-Detection-Classification-Model/cry_project/models/

# If missing, upload from local machine:
# scp -r Cry-Detection-Classification-Model sahan@100.89.162.22:/home/sahan/
```

### Issue: Cry detector can't reach classifier

```bash
# Test from Pi
curl http://localhost:8890/health

# If fails, restart classification service
sudo systemctl restart cry-classification.service

# Then restart cry detector
sudo systemctl restart cry-detector.service
```

## 📊 Monitoring Commands

### View Logs (Live)

```bash
# Cry detector
sudo journalctl -u cry-detector.service -f

# Classification service
sudo journalctl -u cry-classification.service -f

# Both (in separate terminals)
watch -n 1 'systemctl status cry-detector.service cry-classification.service'
```

### Check System Resources

```bash
# CPU and RAM usage
htop

# Service-specific memory
systemctl status cry-classification.service | grep Memory

# Disk space
df -h
```

### Check ThingsBoard Connection

```bash
# Should see "Connected to ThingsBoard successfully"
sudo journalctl -u cry-detector.service | grep ThingsBoard | tail -n 5

# Check telemetry publishing
sudo journalctl -u cry-detector.service | grep "Cry data published" | tail -n 5
```

## 🔄 Restart Services (Clean Slate)

```bash
# Stop both
sudo systemctl stop cry-detector.service cry-classification.service

# Start classification first (dependency)
sudo systemctl start cry-classification.service
sleep 5

# Start cry detector
sudo systemctl start cry-detector.service

# Verify both running
systemctl is-active cry-detector.service cry-classification.service
```

## 🔙 Rollback (If Needed)

```bash
# Stop services
sudo systemctl stop cry-detector.service cry-classification.service

# Restore original cry detector
sudo cp /home/sahan/cry_detector.py.backup /home/sahan/cry_detector.py

# Restart only cry detector
sudo systemctl start cry-detector.service

# Disable classification service
sudo systemctl disable cry-classification.service
```

## ✅ Verification Checklist

```bash
# Run this to check everything
echo "=== Services Status ===" && \
systemctl is-active cry-detector.service cry-classification.service && \
echo "=== Ports Listening ===" && \
netstat -tuln | grep -E '8888|8890' && \
echo "=== Classification Health ===" && \
curl -s http://localhost:8890/health | jq '.status' && \
echo "=== Cry Detector Status ===" && \
curl -s http://localhost:8888/cry/status | jq '.classification_service_available' && \
echo "=== ThingsBoard Connection ===" && \
sudo journalctl -u cry-detector.service | grep "Connected to ThingsBoard" | tail -n 1
```

Expected output:

```
=== Services Status ===
active
active
=== Ports Listening ===
tcp  0.0.0.0:8888  LISTEN
tcp  0.0.0.0:8890  LISTEN
=== Classification Health ===
"healthy"
=== Cry Detector Status ===
true
=== ThingsBoard Connection ===
✓ Connected to ThingsBoard successfully
```

## 📱 Dashboard Check

1. Open React dashboard: http://localhost:3000 (or production URL)
2. Navigate to Clinical Dashboard
3. Check Cry Widget
4. **Expected:**
   - Widget shows "Monitoring active"
   - No errors displayed
   - If cry detected, shows classification label and confidence
   - Statistics show "X verified • Y false positives"

## 🎯 Success Indicators

✅ Both services show "active (running)" status  
✅ Ports 8888 and 8890 are listening  
✅ Classification health check returns "healthy"  
✅ Cry detector shows "classification_service_available: true"  
✅ ThingsBoard connection established  
✅ Dashboard displays cry detection data  
✅ Test cry triggers classification within 10 seconds  
✅ Classification result published to ThingsBoard  
✅ Dashboard shows cry type and confidence

## 📞 Get Help

**View last 50 error logs:**

```bash
sudo journalctl -p err -u cry-classification.service -n 50
sudo journalctl -p err -u cry-detector.service -n 50
```

**Full documentation:** `CRY_CLASSIFICATION_DEPLOYMENT.md`

**Check model info:**

```bash
curl http://localhost:8890/model-info | jq
```

---

**Deployment Time:** ~10-15 minutes  
**Prerequisites:** Raspberry Pi with existing cry detector  
**Required Files:** cry_classification_service.py, cry_detector_enhanced.py, cry-classification.service, model files
