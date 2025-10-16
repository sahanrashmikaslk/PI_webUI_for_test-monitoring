#!/usr/bin/env python3
"""
LCD Reading Server for Raspberry Pi
Reads incubator display values using YOLO + OCR and serves via HTTP API

This server:
1. Captures frames from camera
2. Runs YOLO detection to find display regions
3. Runs OCR to extract values
4. Validates and corrects readings
5. Serves data as JSON via HTTP endpoint

Port: 9001
Endpoint: /readings

Usage:
    python3 lcd_reading_server.py
"""

import json
import http.server
import socketserver
import time
import threading
from datetime import datetime
from pathlib import Path
import sys

# Check if required packages are available
try:
    import cv2
    import numpy as np
except ImportError:
    print("❌ OpenCV not installed. Install with: pip install opencv-python")
    sys.exit(1)

try:
    from ultralytics import YOLO
except ImportError:
    print("⚠️  Ultralytics not installed. Install with: pip install ultralytics")
    print("   For ONNX inference: pip install onnxruntime")
    YOLO = None

try:
    import pytesseract
except ImportError:
    print("⚠️  pytesseract not installed. Install with: pip install pytesseract")
    pytesseract = None

# Configuration
# Camera options: video0/1 = USB2.0 PC CAMERA, video2/3 = V380 FHD Camera
# Use video0 (main device for USB2.0 PC CAMERA, not metadata device video1)
LCD_CAMERA_INDEX = 0  # USB2.0 PC CAMERA
LCD_PORT = 9001
MODEL_PATH = "/home/sahan/monitoring/models/incubator_yolov8n.pt"  # Using PyTorch model for better accuracy
CAPTURE_INTERVAL = 5  # Capture every 5 seconds
CONFIDENCE_THRESHOLD = 0.25

# Medical parameter ranges
PARAMETER_RANGES = {
    'heart_rate_value': {'min': 60, 'max': 220, 'unit': 'bpm', 'name': 'Heart Rate'},
    'spo2_value': {'min': 70, 'max': 100, 'unit': '%', 'name': 'SpO2'},
    'skin_temp_value': {'min': 32.0, 'max': 39.0, 'unit': '°C', 'name': 'Skin Temperature'},
    'humidity_value': {'min': 30, 'max': 95, 'unit': '%', 'name': 'Humidity'}
}

class LCDReader:
    """Handles LCD reading using YOLO + OCR"""
    
    def __init__(self, model_path, camera_index=1):
        self.camera_index = camera_index
        self.model_path = model_path
        self.model = None
        self.ocr_reader = None
        self.last_reading = {}
        self.reading_lock = threading.Lock()
        self.is_running = False
        
        # Initialize model
        self._init_model()
        
        # Initialize OCR
        self._init_ocr()
    
    def _init_model(self):
        """Initialize YOLO model"""
        try:
            if not Path(self.model_path).exists():
                print(f"❌ Model not found: {self.model_path}", flush=True)
                return False
            
            if self.model_path.endswith('.onnx'):
                print(f"🔧 Loading ONNX model: {self.model_path}", flush=True)
                # ONNX runtime inference
                try:
                    import onnxruntime as ort
                    self.model = ort.InferenceSession(self.model_path)
                    print(f"✅ ONNX model loaded successfully", flush=True)
                except ImportError:
                    print("❌ onnxruntime not installed. Install with: pip install onnxruntime", flush=True)
                    return False
            else:
                # PyTorch model
                if YOLO is None:
                    print("❌ Ultralytics not installed", flush=True)
                    return False
                print(f"🔧 Loading PyTorch model: {self.model_path}", flush=True)
                self.model = YOLO(self.model_path)
                print(f"✅ YOLO model loaded successfully", flush=True)
            
            return True
            
        except Exception as e:
            print(f"❌ Error loading model: {e}", flush=True)
            return False
    
    def _init_ocr(self):
        """Initialize Tesseract OCR"""
        try:
            if pytesseract is None:
                print("❌ pytesseract not available", flush=True)
                return False
            
            print(f"🔧 Checking Tesseract installation...", flush=True)
            # Test if tesseract is available
            try:
                version = pytesseract.get_tesseract_version()
                print(f"✅ Tesseract OCR initialized successfully (version: {version})", flush=True)
                self.ocr_reader = True  # Flag to indicate OCR is ready
                return True
            except Exception as e:
                print(f"❌ Tesseract command not found. Install with: sudo apt-get install tesseract-ocr", flush=True)
                return False
            
        except Exception as e:
            print(f"❌ Error initializing OCR: {e}", flush=True)
            return False
    
    def capture_frame(self):
        """Capture a frame from mjpg_streamer HTTP stream on port 8081"""
        try:
            import urllib.request
            import numpy as np
            
            # Read one frame from the MJPEG stream
            stream_url = "http://localhost:8081/?action=stream"
            
            req = urllib.request.Request(stream_url)
            with urllib.request.urlopen(req, timeout=10) as stream:
                # Read the boundary line
                boundary = stream.readline()  # --boundarydonotcross
                
                # Read headers until we find Content-Length
                content_length = 0
                while True:
                    line = stream.readline()
                    if not line or line.strip() == b'':
                        break
                    if line.startswith(b'Content-Length:'):
                        content_length = int(line.split(b':')[1].strip())
                
                # Read the JPEG data based on content length
                if content_length > 0:
                    jpeg_data = stream.read(content_length)
                    img_array = np.frombuffer(jpeg_data, dtype=np.uint8)
                    frame = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
                    
                    if frame is not None:
                        return frame
                
                # Fallback: search for JPEG markers
                bytes_data = b''
                for _ in range(100):  # Read up to 100 chunks
                    chunk = stream.read(4096)
                    if not chunk:
                        break
                    bytes_data += chunk
                    
                    # Look for JPEG start (FFD8) and end (FFD9) markers
                    start = bytes_data.find(b'\xff\xd8')
                    end = bytes_data.find(b'\xff\xd9')
                    
                    if start != -1 and end != -1 and end > start:
                        # Extract JPEG data
                        jpeg_data = bytes_data[start:end+2]
                        img_array = np.frombuffer(jpeg_data, dtype=np.uint8)
                        frame = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
                        
                        if frame is not None:
                            return frame
                        break
            
            print(f"❌ Failed to capture frame from mjpg_streamer")
            return None
            
        except Exception as e:
            print(f"❌ Error capturing frame from HTTP stream: {e}")
            return None
    
    def run_detection(self, frame):
        """Run YOLO detection on frame"""
        if self.model is None:
            return []
        
        try:
            # Check if using ONNX or PyTorch model
            if self.model_path.endswith('.onnx'):
                return self._run_onnx_detection(frame)
            else:
                return self._run_pytorch_detection(frame)
            
        except Exception as e:
            print(f"❌ Error during detection: {e}")
            return []
    
    def _run_onnx_detection(self, frame):
        """Run YOLO detection using ONNX Runtime"""
        import numpy as np
        
        # Get model input details
        input_name = self.model.get_inputs()[0].name
        input_shape = self.model.get_inputs()[0].shape
        
        # Preprocess frame
        img = cv2.resize(frame, (640, 640))
        img = img.transpose(2, 0, 1)  # HWC to CHW
        img = img.astype(np.float32) / 255.0
        img = np.expand_dims(img, axis=0)
        
        # Run inference
        outputs = self.model.run(None, {input_name: img})
        predictions = outputs[0][0]  # Get first batch
        
        # Parse predictions (YOLO format: [x, y, w, h, conf, class_scores...])
        detections = []
        h, w = frame.shape[:2]
        
        for pred in predictions.T:  # Transpose to iterate over detections
            # Extract box and confidence
            box = pred[:4]
            conf = pred[4]
            class_scores = pred[5:]
            
            # Filter by confidence
            if conf < CONFIDENCE_THRESHOLD:
                continue
            
            # Get class with highest score
            cls_id = int(np.argmax(class_scores))
            cls_conf = class_scores[cls_id]
            
            if cls_conf < CONFIDENCE_THRESHOLD:
                continue
            
            # Convert box from center format to corner format
            x_center, y_center, box_w, box_h = box
            x1 = int((x_center - box_w / 2) * w / 640)
            y1 = int((y_center - box_h / 2) * h / 640)
            x2 = int((x_center + box_w / 2) * w / 640)
            y2 = int((y_center + box_h / 2) * h / 640)
            
            # Clip to frame bounds
            x1, y1 = max(0, x1), max(0, y1)
            x2, y2 = min(w, x2), min(h, y2)
            
            # Crop the detected region
            crop = frame[y1:y2, x1:x2]
            
            if crop.size == 0:
                continue
            
            # Map class ID to name
            class_names = ['heart_rate_value', 'spo2_value', 'skin_temp_value', 'humidity_value']
            cls_name = class_names[cls_id] if cls_id < len(class_names) else f'class_{cls_id}'
            
            print(f"  └─ ONNX: {cls_name}: {float(conf * cls_conf):.3f} at [{x1}, {y1}, {x2}, {y2}]", flush=True)
            
            detections.append({
                'class': cls_name,
                'confidence': float(conf * cls_conf),
                'bbox': [x1, y1, x2, y2],
                'crop': crop
            })
        
        if detections:
            print(f"🔍 ONNX YOLO found {len(detections)} detections", flush=True)
        
        return detections
    
    def _run_pytorch_detection(self, frame):
        """Run YOLO detection using PyTorch/Ultralytics"""
        results = self.model.predict(source=frame, conf=CONFIDENCE_THRESHOLD, verbose=False)
        
        detections = []
        for result in results:
            boxes = result.boxes
            print(f"🔍 PyTorch YOLO found {len(boxes)} boxes", flush=True)
            for box in boxes:
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                conf = float(box.conf[0])
                cls_id = int(box.cls[0])
                cls_name = result.names[cls_id]
                
                print(f"  └─ {cls_name}: {conf:.3f} at [{int(x1)}, {int(y1)}, {int(x2)}, {int(y2)}]", flush=True)
                
                # Crop the detected region
                crop = frame[int(y1):int(y2), int(x1):int(x2)]
                
                detections.append({
                    'class': cls_name,
                    'confidence': conf,
                    'bbox': [int(x1), int(y1), int(x2), int(y2)],
                    'crop': crop
                })
        
        return detections
    
    def preprocess_roi(self, roi):
        """Preprocess ROI for better OCR accuracy (from notebook)"""
        if roi is None or roi.size == 0:
            return None
        
        # Convert to grayscale
        gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY) if roi.ndim == 3 else roi
        
        # Apply histogram equalization to improve contrast
        gray = cv2.equalizeHist(gray)
        
        # Apply Gaussian blur to reduce noise
        blur = cv2.GaussianBlur(gray, (3, 3), 0)
        
        # Upscale by 2x for better character recognition
        upscaled = cv2.resize(blur, None, fx=2.0, fy=2.0, interpolation=cv2.INTER_CUBIC)
        
        return upscaled
    
    def clean_numeric(self, text):
        """Clean OCR text to extract numeric values"""
        import re
        cleaned = re.sub(r'[^0-9.%]', '', text)
        cleaned = cleaned.replace('..', '.')
        return cleaned.strip('.')
    
    def run_ocr(self, crop):
        """Run Tesseract OCR on cropped image with preprocessing"""
        if self.ocr_reader is None or pytesseract is None:
            return None, 0.0
        
        try:
            # Preprocess the ROI
            processed = self.preprocess_roi(crop)
            if processed is None:
                return None, 0.0
            
            # Run Tesseract OCR with custom config for digits
            # --psm 7 = Treat image as a single text line
            # --oem 3 = Default OCR Engine Mode (LSTM)
            # -c tessedit_char_whitelist = Only recognize these characters
            custom_config = r'--psm 7 --oem 3 -c tessedit_char_whitelist=0123456789.%'
            
            # Get OCR result with confidence
            data = pytesseract.image_to_data(processed, config=custom_config, output_type=pytesseract.Output.DICT)
            
            # Extract text with highest confidence
            confidences = [int(conf) for conf in data['conf'] if int(conf) > -1]
            texts = [text for i, text in enumerate(data['text']) if int(data['conf'][i]) > -1 and text.strip()]
            
            if not texts:
                return None, 0.0
            
            # Combine all text and get average confidence
            text = ''.join(texts)
            confidence = sum(confidences) / len(confidences) / 100.0 if confidences else 0.0
            
            # Clean the text to extract numeric values
            text = self.clean_numeric(text)
            
            return text if text else None, confidence
            
        except Exception as e:
            print(f"❌ Error during OCR: {e}")
            return None, 0.0
    
    def validate_and_correct(self, class_name, value_str):
        """Validate and correct reading"""
        if class_name not in PARAMETER_RANGES:
            return None
        
        try:
            # Try to parse as float
            value = float(value_str)
            
            # Get valid range
            param_config = PARAMETER_RANGES[class_name]
            min_val = param_config['min']
            max_val = param_config['max']
            
            # Check if in range
            if min_val <= value <= max_val:
                # For integer parameters, round
                if class_name in ['heart_rate_value', 'spo2_value', 'humidity_value']:
                    return int(value)
                return round(value, 1)
            
            # Try decimal correction for out-of-range values
            # e.g., 356 -> 35.6 for temperature
            if class_name == 'skin_temp_value' and value > max_val:
                corrected = value / 10
                if min_val <= corrected <= max_val:
                    return round(corrected, 1)
            
            return None
            
        except ValueError:
            return None
    
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
        # Capture frame
        frame = self.capture_frame()
        if frame is None:
            return {
                'status': 'error',
                'message': 'Failed to capture frame',
                'timestamp': time.time()
            }
        
        # Save debug frame (only save every 10th reading to avoid filling disk)
        if not hasattr(self, '_debug_counter'):
            self._debug_counter = 0
        self._debug_counter += 1
        if self._debug_counter % 10 == 1:  # Save 1st, 11th, 21st, etc.
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
        readings = {}
        for det in detections:
            class_name = det['class']
            crop = det['crop']
            det_conf = det['confidence']
            
            # Run OCR
            text, ocr_conf = self.run_ocr(crop)
            
            if text:
                # Validate and correct
                validated_value = self.validate_and_correct(class_name, text)
                
                if validated_value is not None:
                    param_config = PARAMETER_RANGES.get(class_name, {})
                    readings[class_name] = {
                        'value': validated_value,
                        'unit': param_config.get('unit', ''),
                        'name': param_config.get('name', class_name),
                        'detection_confidence': round(det_conf, 2),
                        'ocr_confidence': round(ocr_conf, 2),
                        'raw_text': text
                    }
        
        # Update last reading
        with self.reading_lock:
            self.last_reading = {
                'status': 'success',
                'readings': readings,
                'timestamp': time.time(),
                'detections_count': len(detections)
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
            print(f"🔄 Starting continuous reading (interval: {interval}s)")
            while self.is_running:
                try:
                    result = self.read_lcd()
                    if result['status'] == 'success':
                        print(f"✅ Reading updated: {len(result['readings'])} parameters")
                    else:
                        print(f"⚠️  Reading status: {result['status']}")
                except Exception as e:
                    print(f"❌ Error in reading loop: {e}")
                
                time.sleep(interval)
        
        thread = threading.Thread(target=reading_loop, daemon=True)
        thread.start()
        print(f"✅ Continuous reading started")
    
    def stop_continuous_reading(self):
        """Stop continuous reading"""
        self.is_running = False
        print(f"🛑 Continuous reading stopped")


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
    
    def send_info_response(self):
        """Send API info"""
        info = {
            "message": "LCD Reading API",
            "version": "1.1.0",
            "endpoints": {
                "/readings": "Get latest LCD readings (cached)",
                "/capture": "Capture new reading immediately",
                "/debug": "Capture debug frame and show detection info",
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
        print(f"[{timestamp}] {format % args}")


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    """HTTP Server with threading support"""
    allow_reuse_address = True


def run_server(port=LCD_PORT):
    """Run the LCD reading server"""
    global lcd_reader
    
    print("=" * 60, flush=True)
    print("🚀 LCD Reading Server for Raspberry Pi", flush=True)
    print("=" * 60, flush=True)
    
    # Initialize LCD reader
    print(f"\n📷 Initializing LCD reader...", flush=True)
    print(f"   Camera: {LCD_CAMERA_INDEX}", flush=True)
    print(f"   Model: {MODEL_PATH}", flush=True)
    
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
