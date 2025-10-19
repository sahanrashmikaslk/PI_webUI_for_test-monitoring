#!/usr/bin/env python3
"""
LCD Reading Server for Raspberry Pi - FIXED VERSION
Reads incubator display values using YOLO + EasyOCR and serves via HTTP API

This server:
1. Captures frames from HTTP stream (port 8081)
2. Runs YOLO detection to find display regions
3. Runs EasyOCR to extract values
4. Validates and corrects readings
5. Serves data as JSON via HTTP endpoint
6. Provides annotated video stream

Port: 9001
Endpoints: /readings, /capture, /debug, /stream, /

Usage:
    python3 lcd_reading_server_FIXED.py
"""

import json
import http.server
import socketserver
import time
import threading
from datetime import datetime
from pathlib import Path
import sys

# Check required packages
try:
    import cv2
    import numpy as np
except ImportError:
    print("❌ OpenCV not installed. Install with: pip3 install opencv-python-headless")
    sys.exit(1)

try:
    import onnxruntime as ort
except ImportError:
    print("❌ ONNX Runtime not installed. Install with: pip3 install onnxruntime")
    sys.exit(1)

try:
    import easyocr
except ImportError:
    print("❌ EasyOCR not installed. Install with: pip3 install easyocr")
    sys.exit(1)

# Configuration
LCD_CAMERA_INDEX = 0  # Fallback camera index (/dev/video0)
LCD_CAMERA_HTTP = "http://localhost:8081/?action=stream"  # Primary: use mjpg-streamer on 8081
LCD_PORT = 9001  # HTTP server port
MODEL_PATH = "/home/sahan/monitoring/models/incubator_yolov8n.pt"  # Using PyTorch for better detection
CAPTURE_INTERVAL = 15  # Capture every 15 seconds (reduce RAM usage)
CONFIDENCE_THRESHOLD = 0.1  # Lowered to detect more objects

# Medical parameter ranges (relaxed for real-world values)
PARAMETER_RANGES = {
    'heart_rate_value': {'min': 60, 'max': 220, 'unit': 'bpm', 'name': 'Heart Rate'},
    'spo2_value': {'min': 70, 'max': 100, 'unit': '%', 'name': 'SpO2'},
    'skin_temp_value': {'min': 32.0, 'max': 39.0, 'unit': '°C', 'name': 'Skin Temperature'},
    'humidity_value': {'min': 30, 'max': 99, 'unit': '%', 'name': 'Humidity'}  # Increased to 99% for real-world values
}

# YOLO class names - SWAPPED spo2_value and humidity_value to match actual LCD positions
# Model class 1 detects humidity (not spo2), Model class 3 detects spo2 (not humidity)
CLASS_NAMES = ['heart_rate_value', 'humidity_value', 'skin_temp_value', 'spo2_value']


class LCDReader:
    """Handles LCD reading using YOLO + EasyOCR"""
    
    def __init__(self, model_path, camera_index=0):
        self.camera_index = camera_index
        self.model_path = model_path
        self.model = None
        self.ocr_reader = None
        self.last_reading = {}
        self.reading_lock = threading.Lock()
        self.is_running = False
        
        # Initialize model
        if not self._init_model():
            raise RuntimeError("Failed to initialize YOLO model")
        
        # Initialize OCR
        if not self._init_ocr():
            raise RuntimeError("Failed to initialize EasyOCR")
    
    def _init_model(self):
        """Initialize YOLO model (PyTorch or ONNX)"""
        try:
            if not Path(self.model_path).exists():
                print(f"❌ Model not found: {self.model_path}", flush=True)
                return False
            
            if self.model_path.endswith('.pt'):
                # PyTorch model with Ultralytics
                print(f"🔧 Loading PyTorch model with Ultralytics: {self.model_path}", flush=True)
                from ultralytics import YOLO
                self.model = YOLO(self.model_path)
                self.model_type = 'pytorch'
                print(f"✅ PyTorch model loaded successfully", flush=True)
            else:
                # ONNX model
                print(f"🔧 Loading ONNX model: {self.model_path}", flush=True)
                self.model = ort.InferenceSession(self.model_path)
                self.model_type = 'onnx'
                print(f"✅ ONNX model loaded successfully", flush=True)
                
                # Get model input details for ONNX
                self.input_name = self.model.get_inputs()[0].name
                self.input_shape = self.model.get_inputs()[0].shape
                print(f"   Input: {self.input_name}, Shape: {self.input_shape}", flush=True)
            
            return True
            
        except Exception as e:
            print(f"❌ Error loading model: {e}", flush=True)
            import traceback
            traceback.print_exc()
            return False
    
    def _init_ocr(self):
        """Initialize EasyOCR"""
        try:
            print(f"🔧 Initializing EasyOCR...", flush=True)
            import easyocr
            
            # Initialize EasyOCR with English language
            # gpu=False for Raspberry Pi (no CUDA)
            self.ocr_reader = easyocr.Reader(['en'], gpu=False)
            print(f"✅ EasyOCR initialized successfully", flush=True)
            return True
            
        except Exception as e:
            print(f"❌ Error initializing OCR: {e}", flush=True)
            import traceback
            traceback.print_exc()
            return False
    
    def capture_frame(self):
        """Capture frame from HTTP stream (avoid camera conflicts with mjpg-streamer)"""
        # Use HTTP stream ONLY - camera is already in use by mjpg-streamer on port 8081
        try:
            import urllib.request
            import socket
            
            # Set socket timeout globally
            socket.setdefaulttimeout(10)
            
            # Use stream endpoint and grab first frame
            stream_url = "http://localhost:8081/?action=stream"
            
            # Open stream and read one JPEG frame
            req = urllib.request.Request(stream_url)
            with urllib.request.urlopen(req, timeout=10) as response:
                # Read stream in smaller chunks for faster processing
                bytes_buffer = b''
                max_read = 500000  # Max 500KB per frame (640x480 JPEG is typically 50-150KB)
                
                while len(bytes_buffer) < max_read:
                    chunk = response.read(4096)  # Read 4KB at a time
                    if not chunk:
                        break
                    bytes_buffer += chunk
                    
                    # Look for JPEG start (FFD8) and end (FFD9) markers
                    start_marker = bytes_buffer.find(b'\xff\xd8')
                    end_marker = bytes_buffer.find(b'\xff\xd9')
                    
                    if start_marker != -1 and end_marker != -1 and end_marker > start_marker:
                        # Extract one complete JPEG frame
                        jpeg_data = bytes_buffer[start_marker:end_marker+2]
                        img_array = np.frombuffer(jpeg_data, dtype=np.uint8)
                        frame = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
                        
                        if frame is not None:
                            return frame
                        else:
                            print("❌ Failed to decode frame from HTTP stream", flush=True)
                            return None
            
            print("❌ Could not extract frame from HTTP stream", flush=True)
            return None
            
        except Exception as e:
            print(f"❌ Error capturing frame from HTTP stream: {e}", flush=True)
            return None
    
    def preprocess_image(self, image):
        """Preprocess image for YOLO detection"""
        # Resize to 640x640 (YOLO input size)
        img = cv2.resize(image, (640, 640))
        
        # Convert BGR to RGB
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        
        # Normalize to [0, 1]
        img = img.astype(np.float32) / 255.0
        
        # Transpose to CHW format (channels first)
        img = img.transpose(2, 0, 1)
        
        # Add batch dimension
        img = np.expand_dims(img, axis=0)
        
        return img
    
    def run_detection(self, frame):
        """Run YOLO detection on frame"""
        if self.model is None:
            return []
        
        try:
            if self.model_type == 'pytorch':
                # Use Ultralytics YOLO inference
                results = self.model(frame, conf=CONFIDENCE_THRESHOLD, verbose=False)
                
                detections = []
                for result in results:
                    boxes = result.boxes
                    for i in range(len(boxes)):
                        box = boxes[i]
                        x1, y1, x2, y2 = map(int, box.xyxy[0].cpu().numpy())
                        confidence = float(box.conf[0].cpu().numpy())
                        cls_id = int(box.cls[0].cpu().numpy())
                        
                        # Crop the detected region
                        crop = frame[y1:y2, x1:x2]
                        
                        if crop.size == 0:
                            continue
                        
                        # Get class name
                        cls_name = CLASS_NAMES[cls_id] if cls_id < len(CLASS_NAMES) else f'class_{cls_id}'
                        
                        print(f"  └─ {cls_name}: {confidence:.3f} at [{x1}, {y1}, {x2}, {y2}]", flush=True)
                        
                        detections.append({
                            'class': cls_name,
                            'confidence': confidence,
                            'bbox': [x1, y1, x2, y2],
                            'crop': crop
                        })
                
                if detections:
                    print(f"🔍 YOLO found {len(detections)} detections", flush=True)
                else:
                    print(f"⚠️  No detections found (confidence threshold: {CONFIDENCE_THRESHOLD})", flush=True)
                
                return detections
            
            else:
                # ONNX inference
                input_tensor = self.preprocess_image(frame)
                outputs = self.model.run(None, {self.input_name: input_tensor})
                predictions = outputs[0][0]
                
                detections = []
                h, w = frame.shape[:2]
                
                for pred in predictions.T:
                    x_center, y_center, box_w, box_h = pred[:4]
                    class_scores = pred[4:]
                    cls_id = int(np.argmax(class_scores))
                    confidence = float(class_scores[cls_id])
                    
                    if confidence < CONFIDENCE_THRESHOLD:
                        continue
                    
                    x1 = int((x_center - box_w / 2) * w)
                    y1 = int((y_center - box_h / 2) * h)
                    x2 = int((x_center + box_w / 2) * w)
                    y2 = int((y_center + box_h / 2) * h)
                    
                    x1, y1 = max(0, x1), max(0, y1)
                    x2, y2 = min(w, x2), min(h, y2)
                    
                    crop = frame[y1:y2, x1:x2]
                    
                    if crop.size == 0:
                        continue
                    
                    cls_name = CLASS_NAMES[cls_id] if cls_id < len(CLASS_NAMES) else f'class_{cls_id}'
                    
                    print(f"  └─ {cls_name}: {confidence:.3f} at [{x1}, {y1}, {x2}, {y2}]", flush=True)
                    
                    detections.append({
                        'class': cls_name,
                        'confidence': confidence,
                        'bbox': [x1, y1, x2, y2],
                        'crop': crop
                    })
                
                if detections:
                    print(f"🔍 YOLO found {len(detections)} detections", flush=True)
                else:
                    print(f"⚠️  No detections found (confidence threshold: {CONFIDENCE_THRESHOLD})", flush=True)
                
                return detections
            
        except Exception as e:
            print(f"❌ Error during detection: {e}", flush=True)
            import traceback
            traceback.print_exc()
            return []
    
    def preprocess_roi(self, roi):
        """Preprocess ROI for OCR (optimized method from incubator_pipeline)"""
        # Convert to grayscale
        gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY) if roi.ndim == 3 else roi
        
        # Apply histogram equalization first for better contrast
        gray = cv2.equalizeHist(gray)
        
        # Apply Gaussian blur to reduce noise
        blur = cv2.GaussianBlur(gray, (3, 3), 0)
        
        # Upscale 2x for better OCR accuracy
        return cv2.resize(blur, None, fx=2.0, fy=2.0, interpolation=cv2.INTER_CUBIC)
    
    def clean_numeric(self, text):
        """Clean OCR text to extract numeric values"""
        import re
        # Remove all non-numeric characters except . and %
        cleaned = re.sub(r'[^0-9.%]', '', text)
        # Remove duplicate dots
        cleaned = cleaned.replace('..', '.')
        # Remove leading/trailing dots
        cleaned = cleaned.strip('.')
        return cleaned
    
    def run_ocr(self, crop):
        """Run EasyOCR on cropped image"""
        if self.ocr_reader is None:
            return None, 0.0
        
        try:
            # Preprocess
            processed = self.preprocess_roi(crop)
            
            # Run EasyOCR
            results = self.ocr_reader.readtext(processed, allowlist='0123456789.%')
            
            if not results:
                return None, 0.0
            
            # Get text with highest confidence
            best_result = max(results, key=lambda x: x[2])
            text = best_result[1]
            confidence = best_result[2]
            
            # Clean to extract numeric value
            cleaned_text = self.clean_numeric(text)
            
            return cleaned_text if cleaned_text else None, confidence
            
        except Exception as e:
            print(f"❌ Error during OCR: {e}", flush=True)
            return None, 0.0
    
    def try_fix_decimal(self, value_str, expected_decimals, min_val, max_val, integer_only=False):
        """Attempt to fix missing or misplaced decimal points"""
        if not value_str or not value_str.replace('.', '').replace('%', '').isdigit():
            return None
        
        clean = value_str.replace('%', '').strip()
        
        # For integer-only values, remove decimals
        if integer_only:
            if '.' in clean:
                clean = clean.split('.')[0]
            try:
                val = int(clean)
                if min_val <= val <= max_val:
                    return int(val)
            except ValueError:
                pass
            return None
        
        # If already in range, return as-is
        try:
            val = float(clean)
            if min_val <= val <= max_val:
                return val
        except ValueError:
            pass
        
        # Try to fix missing decimal point (e.g., 356 -> 35.6)
        if expected_decimals > 0 and '.' not in clean:
            for i in range(len(clean) - expected_decimals, 0, -1):
                candidate = clean[:i] + '.' + clean[i:]
                try:
                    val = float(candidate)
                    if min_val <= val <= max_val:
                        return round(val, expected_decimals)
                except ValueError:
                    continue
        
        return None
    
    def validate_and_correct(self, class_name, value_str):
        """Validate and correct reading with enhanced decimal fixing"""
        if class_name not in PARAMETER_RANGES:
            return None
        
        param_config = PARAMETER_RANGES[class_name]
        min_val = param_config['min']
        max_val = param_config['max']
        integer_only = class_name in ['heart_rate_value', 'spo2_value', 'humidity_value']
        expected_decimals = 0 if integer_only else 1
        
        try:
            value_str = value_str.replace('%', '').strip()
            value = float(value_str)
            
            # Check if in range
            if min_val <= value <= max_val:
                return int(value) if integer_only else round(value, 1)
            
            print(f"  ⚠️  Value {value} out of range, trying corrections...", flush=True)
            
        except ValueError:
            print(f"  ⚠️  Cannot parse '{value_str}', trying corrections...", flush=True)
        
        # Try advanced decimal fixing
        corrected = self.try_fix_decimal(value_str, expected_decimals, min_val, max_val, integer_only)
        
        if corrected is not None:
            print(f"  ✅ Corrected {value_str} -> {corrected} for {class_name}", flush=True)
            return corrected
        
        return None
    
    def draw_label(self, image, text, anchor, color):
        """Draw label with background on image (from incubator_pipeline)"""
        x, y = anchor
        text = text if text else ""
        font = cv2.FONT_HERSHEY_DUPLEX
        font_scale = 0.5
        font_thickness = 1
        (text_w, text_h), baseline = cv2.getTextSize(text, font, font_scale, font_thickness)
        pad = 6
        y = max(y, text_h + pad)
        top_left = (x, y - text_h - pad)
        bottom_right = (x + text_w + 2 * pad, y + baseline)
        cv2.rectangle(image, top_left, bottom_right, color, thickness=-1)
        text_org = (x + pad, y - pad)
        cv2.putText(image, text, text_org, font, font_scale, (255, 255, 255), font_thickness, cv2.LINE_AA)
    
    def annotate_frame(self, frame, detections, readings):
        """Annotate frame with bounding boxes and OCR results"""
        annotated = frame.copy()
        
        # Colors: orange for numeric values
        box_color = (60, 170, 255)  # BGR format (orange)
        box_thickness = 2
        
        for det in detections:
            class_name = det['class']
            bbox = det['bbox']
            det_conf = det['confidence']
            
            x1, y1, x2, y2 = map(int, bbox)
            
            # Draw bounding box
            cv2.rectangle(annotated, (x1, y1), (x2, y2), box_color, box_thickness)
            
            # Get OCR value if available
            if class_name in readings:
                reading_data = readings[class_name]
                value = reading_data.get('value', 'N/A')
                unit = reading_data.get('unit', '')
                label_text = f"{class_name}: {value}{unit}"
            else:
                label_text = f"{class_name}: --"
            
            # Draw label above box
            self.draw_label(annotated, label_text, (x1, y1 - 8), box_color)
        
        return annotated
    
    def save_debug_frame(self, frame, prefix="debug"):
        """Save debug frame to file"""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"/home/sahan/monitoring/{prefix}_{timestamp}.jpg"
            cv2.imwrite(filename, frame)
            print(f"💾 Debug frame saved: {filename}", flush=True)
            return filename
        except Exception as e:
            print(f"❌ Error saving debug frame: {e}", flush=True)
            return None
    
    def read_lcd(self):
        """Main reading function"""
        print(f"📸 Capturing new frame...", flush=True)
        
        # Capture frame
        frame = self.capture_frame()
        if frame is None:
            return {
                'status': 'error',
                'message': 'Failed to capture frame from camera',
                'timestamp': time.time()
            }
        
        print(f"✅ Frame captured: {frame.shape}", flush=True)
        
        # Save debug frame periodically
        if not hasattr(self, '_debug_counter'):
            self._debug_counter = 0
        self._debug_counter += 1
        if self._debug_counter % 10 == 1:
            self.save_debug_frame(frame, "lcd_capture")
        
        # Run detection
        detections = self.run_detection(frame)
        
        if not detections:
            return {
                'status': 'no_detection',
                'message': 'No display regions detected',
                'timestamp': time.time()
            }
        
        # Process each detection
        new_readings = {}
        for det in detections:
            class_name = det['class']
            crop = det['crop']
            det_conf = det['confidence']
            
            print(f"  🔤 Running OCR on {class_name}...", flush=True)
            
            # Run OCR
            text, ocr_conf = self.run_ocr(crop)
            
            print(f"     Text: '{text}', Confidence: {ocr_conf:.2f}", flush=True)
            
            if text:
                # Validate and correct
                validated_value = self.validate_and_correct(class_name, text)
                
                if validated_value is not None:
                    param_config = PARAMETER_RANGES.get(class_name, {})
                    new_readings[class_name] = {
                        'value': validated_value,
                        'unit': param_config.get('unit', ''),
                        'name': param_config.get('name', class_name),
                        'detection_confidence': round(det_conf, 2),
                        'ocr_confidence': round(ocr_conf, 2),
                        'raw_text': text,
                        'timestamp': time.time()  # Add timestamp per reading
                    }
                    print(f"  ✅ {class_name}: {validated_value} {param_config.get('unit', '')}", flush=True)
                else:
                    print(f"  ❌ {class_name}: Validation failed for '{text}'", flush=True)
        
        # Merge with previous readings (keep old values if not detected in new scan)
        with self.reading_lock:
            # Start with previous readings if available
            if self.last_reading and 'readings' in self.last_reading:
                readings = self.last_reading['readings'].copy()
            else:
                readings = {}
            
            # Update with new readings
            readings.update(new_readings)
            
            # Update last reading with merged data
            self.last_reading = {
                'status': 'success',
                'readings': readings,
                'timestamp': time.time(),
                'detections_count': len(new_readings)  # Count only new detections
            }
        
        return self.last_reading
    
    def get_last_reading(self):
        """Get the last successful reading"""
        with self.reading_lock:
            return self.last_reading.copy() if self.last_reading else {
                'status': 'no_data',
                'message': 'No readings available yet',
                'timestamp': time.time()
            }
    
    def start_continuous_reading(self, interval=CAPTURE_INTERVAL):
        """Start continuous reading in background thread"""
        self.is_running = True
        
        def reading_loop():
            import gc  # Garbage collector for memory cleanup
            print(f"🔄 Starting continuous reading (interval: {interval}s)", flush=True)
            while self.is_running:
                try:
                    result = self.read_lcd()
                    if result['status'] == 'success':
                        print(f"✅ Reading updated: {len(result['readings'])} parameters", flush=True)
                    else:
                        print(f"⚠️  Reading status: {result['status']}", flush=True)
                except Exception as e:
                    print(f"❌ Error in reading loop: {e}", flush=True)
                    import traceback
                    traceback.print_exc()
                
                # Force garbage collection to prevent memory leaks
                gc.collect()
                
                time.sleep(interval)
        
        thread = threading.Thread(target=reading_loop, daemon=True)
        thread.start()
        print(f"✅ Continuous reading started", flush=True)
    
    def stop_continuous_reading(self):
        """Stop continuous reading"""
        self.is_running = False
        print(f"🛑 Continuous reading stopped", flush=True)


# Global LCD reader instance
lcd_reader = None


class LCDReadingHTTPRequestHandler(http.server.BaseHTTPRequestHandler):
    """HTTP Request Handler for LCD readings"""
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/readings':
            self.send_readings_response()
        elif self.path == '/':
            self.send_info_response()
        elif self.path == '/capture':
            self.send_capture_response()
        elif self.path == '/debug':
            self.send_debug_capture_response()
        elif self.path == '/annotated_snapshot':
            self.send_annotated_snapshot()
        elif self.path == '/stream':
            self.send_mjpeg_stream()
        else:
            self.send_error(404, "Not Found")
    
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.add_cors_headers()
        self.end_headers()
    
    def add_cors_headers(self):
        """Add CORS headers"""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
    
    def send_readings_response(self):
        """Send LCD readings as JSON"""
        global lcd_reader
        
        if lcd_reader is None:
            self.send_error(500, "LCD reader not initialized")
            return
        
        try:
            readings = lcd_reader.get_last_reading()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.add_cors_headers()
            self.end_headers()
            
            response = json.dumps(readings, indent=2)
            self.wfile.write(response.encode('utf-8'))
            
        except Exception as e:
            self.send_error(500, f"Error: {str(e)}")
    
    def send_capture_response(self):
        """Capture a new reading immediately"""
        global lcd_reader
        
        if lcd_reader is None:
            self.send_error(500, "LCD reader not initialized")
            return
        
        try:
            readings = lcd_reader.read_lcd()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.add_cors_headers()
            self.end_headers()
            
            response = json.dumps(readings, indent=2)
            self.wfile.write(response.encode('utf-8'))
            
        except Exception as e:
            self.send_error(500, f"Error: {str(e)}")
    
    def send_debug_capture_response(self):
        """Capture frame and save debug image"""
        global lcd_reader
        
        if lcd_reader is None:
            self.send_error(500, "LCD reader not initialized")
            return
        
        try:
            # Capture frame
            frame = lcd_reader.capture_frame()
            
            if frame is None:
                result = {
                    "status": "error",
                    "message": "Failed to capture frame",
                    "timestamp": time.time()
                }
            else:
                # Save debug image
                filename = lcd_reader.save_debug_frame(frame, "debug_manual")
                
                # Try to run detection to see what YOLO finds
                detections = lcd_reader.run_detection(frame)
                
                result = {
                    "status": "success",
                    "message": "Debug frame captured",
                    "debug_image": filename,
                    "frame_shape": list(frame.shape),
                    "detections_found": len(detections) if detections else 0,
                    "detections": [
                        {
                            "class": d['class'],
                            "confidence": d['confidence'],
                            "bbox": d['bbox']
                        } for d in (detections or [])
                    ],
                    "timestamp": time.time()
                }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.add_cors_headers()
            self.end_headers()
            
            response = json.dumps(result, indent=2)
            self.wfile.write(response.encode('utf-8'))
            
        except Exception as e:
            self.send_error(500, f"Error: {str(e)}")
    
    def send_annotated_snapshot(self):
        """Send a single annotated frame as JPEG"""
        global lcd_reader
        
        if lcd_reader is None:
            self.send_error(500, "LCD reader not initialized")
            return
        
        try:
            # Capture frame
            frame = lcd_reader.capture_frame()
            
            if frame is None:
                self.send_error(500, "Failed to capture frame")
                return
            
            # Run detection
            detections = lcd_reader.run_detection(frame)
            
            # Get current readings for annotation
            readings = lcd_reader.get_last_reading().get('readings', {})
            
            # Annotate frame
            if detections:
                annotated = lcd_reader.annotate_frame(frame, detections, readings)
            else:
                annotated = frame
            
            # Encode as JPEG
            _, jpeg = cv2.imencode('.jpg', annotated, [cv2.IMWRITE_JPEG_QUALITY, 85])
            jpeg_bytes = jpeg.tobytes()
            
            # Send response
            self.send_response(200)
            self.send_header('Content-Type', 'image/jpeg')
            self.send_header('Content-Length', len(jpeg_bytes))
            self.add_cors_headers()
            self.end_headers()
            self.wfile.write(jpeg_bytes)
            
        except Exception as e:
            print(f"❌ Error sending annotated snapshot: {e}", flush=True)
            self.send_error(500, f"Error: {str(e)}")
    
    def send_mjpeg_stream(self):
        """Send MJPEG stream of annotated frames - DISABLED TO SAVE RESOURCES"""
        # COMMENTED OUT TO REDUCE RAM USAGE - Uncomment to re-enable annotated stream
        self.send_error(503, "Annotated stream temporarily disabled to save resources")
        return
        
        # global lcd_reader
        # 
        # if lcd_reader is None:
        #     self.send_error(500, "LCD reader not initialized")
        #     return
        # 
        # try:
        #     self.send_response(200)
        #     self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=frame')
        #     self.add_cors_headers()
        #     self.end_headers()
        #     
        #     while True:
        #         try:
        #             # Capture frame
        #             frame = lcd_reader.capture_frame()
        #             
        #             if frame is None:
        #                 time.sleep(0.1)
        #                 continue
        #             
        #             # Get last detections from cached reading (don't run detection on every frame!)
        #             last_reading = lcd_reader.get_last_reading()
        #             
        #             # Use cached detections and readings if available
        #             if last_reading.get('status') == 'success':
        #                 readings = last_reading.get('readings', {})
        #                 # Reconstruct detection boxes from cached readings
        #                 cached_detections = []
        #                 for param_name, param_data in readings.items():
        #                     if 'bbox' in param_data:  # If we have cached bbox data
        #                         cached_detections.append({
        #                             'class_name': param_name,
        #                             'confidence': param_data.get('detection_confidence', 0),
        #                             'bbox': param_data['bbox']
        #                         })
        #                 
        #                 # Annotate frame with cached detections
        #                 if cached_detections:
        #                     annotated = lcd_reader.annotate_frame(frame, cached_detections, readings)
        #                 else:
        #                     # No cached detections yet, just show raw frame
        #                     annotated = frame
        #             else:
        #                 # No readings yet, just show raw frame
        #                 annotated = frame
        #             
        #             # Encode as JPEG
        #             _, jpeg = cv2.imencode('.jpg', annotated, [cv2.IMWRITE_JPEG_QUALITY, 80])
        #             jpeg_bytes = jpeg.tobytes()
        #             
        #             # Send frame
        #             self.wfile.write(b'--frame\r\n')
        #             self.wfile.write(b'Content-Type: image/jpeg\r\n')
        #             self.wfile.write(f'Content-Length: {len(jpeg_bytes)}\r\n\r\n'.encode())
        #             self.wfile.write(jpeg_bytes)
        #             self.wfile.write(b'\r\n')
        #             
        #             # Clean up memory explicitly
        #             del frame, annotated, jpeg, jpeg_bytes
        #             
        #             # Control frame rate (3 FPS - lower to save RAM and sync with readings)
        #             time.sleep(0.33)
        #             
        #         except Exception as e:
        #             print(f"❌ Error in stream: {e}", flush=True)
        #             break
        #             
        # except Exception as e:
        #     print(f"❌ Error starting stream: {e}", flush=True)
    
    def send_info_response(self):
        """Send API info"""
        info = {
            "message": "LCD Reading API - FIXED VERSION (Stream Disabled)",
            "version": "2.0.1",
            "camera_index": LCD_CAMERA_INDEX,
            "model": MODEL_PATH,
            "endpoints": {
                "/readings": "Get latest LCD readings (cached)",
                "/capture": "Capture new reading immediately",
                "/debug": "Capture debug frame and show detection info",
                "/annotated_snapshot": "Get single annotated frame as JPEG",
                "/stream": "DISABLED - Annotated stream disabled to save resources",
                "/": "This info page"
            },
            "timestamp": time.time()
        }
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.add_cors_headers()
        self.end_headers()
        
        response = json.dumps(info, indent=2)
        self.wfile.write(response.encode('utf-8'))
    
    def log_message(self, format, *args):
        """Custom log format"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {format % args}", flush=True)


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    """HTTP Server with threading support"""
    allow_reuse_address = True


def run_server(port=LCD_PORT):
    """Run the LCD reading server"""
    global lcd_reader
    
    print("=" * 60, flush=True)
    print("🚀 LCD Reading Server for Raspberry Pi - FIXED VERSION", flush=True)
    print("=" * 60, flush=True)
    
    # Initialize LCD reader
    print(f"\n📷 Initializing LCD reader...", flush=True)
    print(f"   Camera: {LCD_CAMERA_INDEX}", flush=True)
    print(f"   Model: {MODEL_PATH}", flush=True)
    print(f"   Confidence: {CONFIDENCE_THRESHOLD}", flush=True)
    
    try:
        lcd_reader = LCDReader(MODEL_PATH, LCD_CAMERA_INDEX)
    except Exception as e:
        print(f"❌ Failed to initialize LCD reader: {e}", flush=True)
        import traceback
        traceback.print_exc()
        return
    
    # Start continuous reading
    lcd_reader.start_continuous_reading(interval=CAPTURE_INTERVAL)
    
    # Start HTTP server
    server_address = ('', port)
    
    try:
        httpd = ThreadedHTTPServer(server_address, LCDReadingHTTPRequestHandler)
        print(f"\n✅ Server ready!", flush=True)
        print(f"📊 Readings endpoint: http://localhost:{port}/readings", flush=True)
        print(f"📸 Capture endpoint: http://localhost:{port}/capture", flush=True)
        print(f"🐛 Debug endpoint: http://localhost:{port}/debug", flush=True)
        print(f"ℹ️  API info: http://localhost:{port}/", flush=True)
        print(f"🌐 External access: http://<your-pi-ip>:{port}/readings", flush=True)
        print(f"⏹️  Press Ctrl+C to stop", flush=True)
        print("=" * 60, flush=True)
        
        httpd.serve_forever()
        
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user", flush=True)
        if lcd_reader:
            lcd_reader.stop_continuous_reading()
        httpd.shutdown()
    except Exception as e:
        print(f"❌ Server error: {e}", flush=True)
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    run_server()
