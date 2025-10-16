# 🔍 LCD Detection Troubleshooting Results

**Date**: October 14, 2025, 14:03 IST  
**Test**: Lowered confidence threshold from 0.25 to 0.1

---

## 📊 Test Results

### Confidence Threshold Test
| Threshold | Detections | Result |
|-----------|------------|--------|
| **0.25** (Original) | 0 | ❌ No detections |
| **0.1** (Lowered) | 0 | ❌ No detections |

**Conclusion**: The issue is **NOT** the confidence threshold. The YOLO model is not detecting ANY objects in the captured frames, regardless of threshold.

---

## 🔍 Current System State

### Service Status
✅ **lcd-reading.service**: Running  
✅ **Camera capture**: Working (480x640 frames via HTTP stream)  
✅ **ONNX model**: Loaded successfully  
✅ **EasyOCR**: Initialized  
✅ **API endpoint**: Responding on port 9001  

### Debug Information
```json
{
  "frame_shape": [480, 640, 3],
  "detections_found": 0,
  "detections": [],
  "confidence_threshold": 0.1
}
```

### Debug Images Saved
- Latest: `/home/sahan/monitoring/lcd_capture_20251014_140150.jpg`
- Downloaded locally: `debug_lcd_capture.jpg`

---

## 🐛 Root Cause Analysis

The problem is **NOT** related to the fixed bugs (camera, OCR, model format). Those are all working correctly. The issue is:

### **The YOLO Model is Not Trained for This Camera View**

Possible reasons:

#### 1. **Camera Position/Angle**
- LCD display may not be visible in the camera frame
- Camera may be pointed at wrong angle
- LCD may be too far or too close
- Focus issues

#### 2. **Model Training Mismatch**
- The YOLOv8n model was trained on specific LCD display images
- Current camera setup may have different:
  - **Distance** from LCD
  - **Angle** to LCD
  - **Lighting conditions**
  - **Resolution** (640x480 vs training data)
  - **LCD display type** (different model?)

#### 3. **Image Quality**
- Resolution: 640x480 (relatively low)
- Compression from mjpg_streamer
- Possible blur or focus issues

---

## 🔧 Recommended Actions

### **Option 1: Check Camera View** ⭐ **START HERE**

1. **View the captured image**:
   ```powershell
   # Image already downloaded as debug_lcd_capture.jpg
   # Open it and check:
   - Is the LCD display visible?
   - Is it in focus?
   - Is it centered?
   - Can you read the numbers?
   ```

2. **If LCD is not visible or poorly positioned**:
   - Adjust camera position
   - Point camera directly at LCD display
   - Ensure adequate distance (30-50cm typically works best)
   - Check focus

3. **If LCD is visible but blurry**:
   - Adjust camera focus
   - Improve lighting (avoid glare)
   - Clean camera lens

### **Option 2: Test with Different Images**

Download multiple debug images to see patterns:
```powershell
# List all recent captures
ssh sahan@100.99.151.101 "ls -lt /home/sahan/monitoring/lcd_capture_*.jpg | head -5"

# Download several
scp sahan@100.99.151.101:/home/sahan/monitoring/lcd_capture_*.jpg ./debug_images/
```

### **Option 3: Model Verification**

The model might not be suitable for this setup. Check:

1. **Verify model was trained for incubator LCD displays**:
   ```bash
   # Check model info
   ssh sahan@100.99.151.101 "ls -lh /home/sahan/monitoring/models/"
   ```

2. **Test with different model** (if available):
   - Try `incubator_yolov8n_v2.pt` if exists
   - Or convert it to ONNX first

### **Option 4: Direct Testing** ⭐ **RECOMMENDED**

Test the model directly with the captured image:

```python
# On your PC or Pi
from ultralytics import YOLO
import cv2

# Load model
model = YOLO('incubator_yolov8n.pt')

# Load captured image
img = cv2.imread('debug_lcd_capture.jpg')

# Run detection
results = model(img, conf=0.1, verbose=True)

# Print results
for result in results:
    print(f"Detections: {len(result.boxes)}")
    for box in result.boxes:
        print(f"  Class: {box.cls}, Conf: {box.conf}")
```

### **Option 5: Manual Test via Web**

View the camera stream in your browser:
```
http://100.99.151.101:8081/?action=stream
```
Verify what the camera sees in real-time.

---

## 🎯 Next Steps Priority

### **High Priority** (Do First)
1. ✅ **Open `debug_lcd_capture.jpg`** and visually inspect
   - Is LCD display visible?
   - Is it readable?
   - Is image quality acceptable?

2. **If LCD NOT visible**: Reposition camera
   - Point directly at LCD
   - Adjust distance
   - Test again

3. **If LCD visible but model doesn't detect**: Model training issue
   - Model was trained on different images
   - Need to retrain or fine-tune model

### **Medium Priority**
4. **Test different confidence thresholds**: Try 0.05, 0.01 (very low)
5. **Check model classes**: Verify what the model was trained to detect
6. **Review training data**: Compare with current camera view

### **Low Priority** (If Nothing Else Works)
7. **Retrain YOLO model** with images from current setup
8. **Try different detection approach** (template matching, etc.)
9. **Use pre-trained LCD detection model** from other sources

---

## 📸 Camera Stream Check

View live camera feed:
```
Browser: http://100.99.151.101:8081/?action=stream
Snapshot: http://100.99.151.101:8081/?action=snapshot
```

This will show exactly what the LCD reading server sees.

---

## 🤖 Model Information

### Current Model
- **Path**: `/home/sahan/monitoring/models/incubator_yolov8n.onnx`
- **Size**: 12MB
- **Format**: ONNX (optimized)
- **Input**: 640x640 RGB
- **Classes**: Unknown (need to verify)

### Alternative Models Available
```bash
/home/sahan/monitoring/models/
├── incubator_yolov8n.onnx (12MB) ← Currently using
├── incubator_yolov8n.pt (6.0MB)
└── incubator_yolov8n_v2.pt (6.0MB) ← Try this?
```

---

## 💡 Quick Diagnostic Commands

### View latest capture
```bash
ssh sahan@100.99.151.101 "ls -lt /home/sahan/monitoring/lcd_capture_*.jpg | head -1"
```

### Download latest
```bash
scp sahan@100.99.151.101:/home/sahan/monitoring/lcd_capture_$(date +%Y%m%d)_*.jpg ./
```

### Test API
```bash
curl http://100.99.151.101:9001/debug
curl http://100.99.151.101:9001/readings
```

### Monitor live
```bash
ssh sahan@100.99.151.101 "sudo journalctl -u lcd-reading.service -f"
```

---

## 📋 Summary

| Component | Status | Notes |
|-----------|--------|-------|
| **Service** | ✅ Running | No issues |
| **Camera Capture** | ✅ Working | 640x480 frames via HTTP |
| **ONNX Model** | ✅ Loaded | Inference working |
| **EasyOCR** | ✅ Ready | Initialized successfully |
| **Detection** | ❌ **FAILING** | **0 detections at 0.1 threshold** |
| **Root Cause** | ⚠️ **Unknown** | Need to inspect captured image |

---

## 🎬 Action Plan

1. **IMMEDIATE**: Open `debug_lcd_capture.jpg` (already downloaded)
2. **Verify**: Is LCD display visible and readable?
3. **If NO**: Adjust camera position → retry
4. **If YES**: Model training issue → consider retraining or using v2 model
5. **Report back**: Share what you see in the image

---

**The server is working perfectly. We just need to figure out why YOLO isn't detecting the LCD in the frames. Let's start by looking at what the camera is actually capturing!**

Would you like me to help you open the debug image, or would you like to try the alternative model (`incubator_yolov8n_v2.pt`)?
