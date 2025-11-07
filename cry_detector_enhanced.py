#!/usr/bin/env python3
"""
Enhanced Real-time Cry Detection System for Raspberry Pi
Hybrid architecture: Real-time detection → 5-sec recording → Classification

Features:
- Real-time audio monitoring with basic cry detection (existing)
- 5-second audio recording when cry detected
- Integration with cry classification service (YAMNet + Ensemble)
- HTTP API for status updates
- ThingsBoard telemetry with classification data
- Audio level monitoring
- Configurable sensitivity

Usage:
    python3 cry_detector_enhanced.py

Dependencies:
    sudo apt install python3-pyaudio python3-numpy python3-scipy
    pip3 install librosa soundfile requests --break-system-packages
"""

import numpy as np
import pyaudio
import threading
import time
import json
import http.server
import socketserver
from datetime import datetime
import queue
import wave
import os
import signal
import sys
import paho.mqtt.client as mqtt
import logging
import requests
from collections import deque
import tempfile

# ThingsBoard Configuration
TB_HOST = "thingsboard.cloud"
TB_PORT = 1883
ACCESS_TOKEN = os.getenv("TB_ACCESS_TOKEN", "2ztut7be6ppooyiueorb")

# Cry Classification Service Configuration
CLASSIFICATION_SERVICE_URL = os.getenv("CRY_CLASSIFY_URL", "http://localhost:8890/classify")
CLASSIFICATION_ENABLED = True  # Enable/disable classification integration

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ThingsBoardClient:
    """MQTT client for ThingsBoard communication with cry classification telemetry"""
    
    def __init__(self):
        if not ACCESS_TOKEN:
            logger.warning("ThingsBoard not configured")
            self.enabled = False
            return
            
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, clean_session=True)
        self.client.username_pw_set(ACCESS_TOKEN)
        self.client.on_connect = self.on_connect
        self.client.on_disconnect = self.on_disconnect
        self.connected = False
        self.enabled = True
        self.telemetry_topic = 'v1/devices/me/telemetry'
        
        # Enable automatic reconnection
        self.client.reconnect_delay_set(min_delay=1, max_delay=120)
        
    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            logger.info("✓ Connected to ThingsBoard successfully")
            self.connected = True
        else:
            logger.error(f"✗ ThingsBoard connection failed with code {rc}")
            self.connected = False
    
    def on_disconnect(self, client, userdata, rc):
        logger.warning(f"Disconnected from ThingsBoard (code: {rc})")
        self.connected = False
        
    def connect(self):
        """Connect to ThingsBoard MQTT broker"""
        if not self.enabled:
            return False
            
        try:
            self.client.connect(TB_HOST, TB_PORT, keepalive=60)
            self.client.loop_start()
            
            # Wait for connection
            timeout = 10
            start_time = time.time()
            while not self.connected and (time.time() - start_time) < timeout:
                time.sleep(0.5)
            
            if not self.connected:
                raise Exception("Connection timeout")
                
            return True
        except Exception as e:
            logger.error(f"Failed to connect to ThingsBoard: {e}")
            return False
    
    def disconnect(self):
        """Disconnect from ThingsBoard"""
        if self.enabled and self.client:
            try:
                self.client.loop_stop()
                self.client.disconnect()
                logger.info("Disconnected from ThingsBoard")
            except Exception as e:
                logger.error(f"Error disconnecting from ThingsBoard: {e}")
    
    def publish_cry_data(self, cry_status):
        """Publish enhanced cry detection data with classification to ThingsBoard"""
        if not self.enabled or not self.connected:
            return False
        
        try:
            # Prepare base telemetry data
            telemetry = {
                'cry_detected': cry_status.get('cry_detected', False),
                'cry_audio_level': round(cry_status.get('audio_level', 0), 3),
                'cry_sensitivity': cry_status.get('sensitivity', 0.6),
                'cry_total_detections': cry_status.get('total_detections', 0),
                'cry_monitoring': cry_status.get('is_monitoring', False),
                'timestamp': int(time.time() * 1000)
            }
            
            # Add last cry time if available
            if cry_status.get('last_cry_time'):
                telemetry['cry_last_detected'] = cry_status['last_cry_time']
            
            # Add classification data if available
            if cry_status.get('classification'):
                telemetry['cry_classification'] = cry_status['classification']
                telemetry['cry_classification_confidence'] = cry_status.get('classification_confidence', 0)
                
                # Add top 3 probabilities for dashboard display
                if cry_status.get('classification_probabilities'):
                    probs = cry_status['classification_probabilities']
                    sorted_probs = sorted(probs.items(), key=lambda x: x[1], reverse=True)[:3]
                    telemetry['cry_classification_top1'] = f"{sorted_probs[0][0]}: {sorted_probs[0][1]:.2%}"
                    if len(sorted_probs) > 1:
                        telemetry['cry_classification_top2'] = f"{sorted_probs[1][0]}: {sorted_probs[1][1]:.2%}"
                    if len(sorted_probs) > 2:
                        telemetry['cry_classification_top3'] = f"{sorted_probs[2][0]}: {sorted_probs[2][1]:.2%}"
            
            # Add verification status
            if cry_status.get('verified'):
                telemetry['cry_verified'] = cry_status['verified']
                telemetry['cry_verification_confidence'] = cry_status.get('verification_confidence', 0)
            
            payload = json.dumps(telemetry)
            result = self.client.publish(self.telemetry_topic, payload, qos=1)
            
            # Wait for publish to complete
            result.wait_for_publish()
            
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                logger.info(f"✓ Cry data published to ThingsBoard (classification: {cry_status.get('classification', 'N/A')})")
                return True
            else:
                logger.error(f"✗ Publish failed with code {result.rc}")
                return False
        except Exception as e:
            logger.error(f"Error publishing to ThingsBoard: {e}")
            return False

class AudioRecorder:
    """Records audio in rolling buffer for 5-second capture on trigger"""
    
    def __init__(self, sample_rate=16000, buffer_duration=5.0):
        self.sample_rate = sample_rate
        self.buffer_duration = buffer_duration
        self.buffer_size = int(sample_rate * buffer_duration)
        
        # Rolling buffer to keep last 5 seconds
        self.audio_buffer = deque(maxlen=self.buffer_size)
        self.lock = threading.Lock()
        
    def add_audio(self, audio_chunk):
        """Add audio chunk to rolling buffer"""
        with self.lock:
            self.audio_buffer.extend(audio_chunk)
    
    def get_recording(self):
        """Get current 5-second recording as numpy array"""
        with self.lock:
            if len(self.audio_buffer) == 0:
                return None
            return np.array(list(self.audio_buffer), dtype=np.float32)
    
    def save_recording(self, filepath):
        """Save current buffer to WAV file"""
        recording = self.get_recording()
        if recording is None:
            return False
        
        try:
            import wave
            with wave.open(filepath, 'wb') as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)  # 16-bit
                wf.setframerate(self.sample_rate)
                # Convert float32 to int16
                audio_int16 = (recording * 32767).astype(np.int16)
                wf.writeframes(audio_int16.tobytes())
            return True
        except Exception as e:
            logger.error(f"Failed to save recording: {e}")
            return False

class CryClassificationClient:
    """Client for cry classification service integration"""
    
    def __init__(self, service_url):
        self.service_url = service_url
        self.enabled = CLASSIFICATION_ENABLED
        self.last_health_check = 0
        self.service_available = False
        
    def check_health(self):
        """Check if classification service is available"""
        try:
            health_url = self.service_url.replace('/classify', '/health')
            response = requests.get(health_url, timeout=2)
            self.service_available = response.status_code == 200
            self.last_health_check = time.time()
            return self.service_available
        except Exception as e:
            logger.warning(f"Classification service health check failed: {e}")
            self.service_available = False
            return False
    
    def classify_audio(self, audio_filepath):
        """
        Send audio file to classification service
        Returns: dict with classification results or None on failure
        """
        if not self.enabled:
            return None
        
        # Check service health if last check was > 60 seconds ago
        if time.time() - self.last_health_check > 60:
            self.check_health()
        
        if not self.service_available:
            logger.warning("Classification service not available, skipping classification")
            return None
        
        try:
            with open(audio_filepath, 'rb') as audio_file:
                files = {'file': (os.path.basename(audio_filepath), audio_file, 'audio/wav')}
                response = requests.post(self.service_url, files=files, timeout=10)
                
                if response.status_code == 200:
                    result = response.json()
                    logger.info(f"✓ Classification result: {result.get('message')}")
                    return result
                else:
                    logger.error(f"✗ Classification failed: {response.status_code} - {response.text}")
                    return None
                    
        except Exception as e:
            logger.error(f"Classification request error: {e}")
            self.service_available = False
            return None

class EnhancedCryDetector:
    """Enhanced cry detector with recording and classification"""
    
    def __init__(self, sample_rate=16000, chunk_size=1024, sensitivity=0.6):
        self.sample_rate = sample_rate
        self.chunk_size = chunk_size
        self.sensitivity = sensitivity
        self.is_monitoring = False
        self.cry_detected = False
        self.audio_level = 0.0
        self.last_cry_time = None
        
        # Audio processing
        self.audio_queue = queue.Queue()
        self.audio_thread = None
        
        # Detection parameters
        self.cry_threshold = 0.7
        self.noise_threshold = 0.1
        self.cry_frequency_range = (300, 2000)  # Hz
        self.detection_window = 2.0  # seconds
        
        # Statistics
        self.total_detections = 0
        self.verified_cries = 0
        self.false_positives = 0
        
        # Recording and classification
        self.audio_recorder = AudioRecorder(sample_rate=sample_rate, buffer_duration=5.0)
        self.classification_client = CryClassificationClient(CLASSIFICATION_SERVICE_URL)
        
        # Current classification state
        self.current_classification = None
        self.current_classification_confidence = None
        self.current_classification_probs = None
        self.cry_verified = False
        self.verification_confidence = 0.0
        
        # ThingsBoard publishing
        self.last_publish_time = 0
        self.publish_interval = 30  # Publish every 30 seconds
        self.monitoring_start_time = None
        
        # Prevent duplicate classifications for same cry event
        self.last_classification_time = 0
        self.classification_cooldown = 10  # seconds
        
        logger.info("🍼 Enhanced Cry Detector initialized")
        logger.info(f"📊 Sample Rate: {sample_rate} Hz")
        logger.info(f"🔊 Chunk Size: {chunk_size}")
        logger.info(f"⚙️ Sensitivity: {sensitivity}")
        logger.info(f"🎯 Classification service: {CLASSIFICATION_SERVICE_URL}")

    def start_monitoring(self):
        """Start audio monitoring for cry detection"""
        if self.is_monitoring:
            return False
            
        try:
            self.p = pyaudio.PyAudio()
            
            # Find audio input device
            device_index = self.find_audio_device()
            if device_index is None:
                logger.error("❌ No audio input device found!")
                return False
            
            logger.info(f"🎤 Using audio device: {device_index}")
            
            # Open audio stream
            self.stream = self.p.open(
                format=pyaudio.paFloat32,
                channels=1,
                rate=self.sample_rate,
                input=True,
                input_device_index=device_index,
                frames_per_buffer=self.chunk_size,
                stream_callback=self.audio_callback
            )
            
            self.is_monitoring = True
            self.monitoring_start_time = time.time()
            self.stream.start_stream()
            
            # Start processing thread
            self.audio_thread = threading.Thread(target=self.process_audio, daemon=True)
            self.audio_thread.start()
            
            # Check classification service health
            if self.classification_client.enabled:
                if self.classification_client.check_health():
                    logger.info("✅ Classification service is available")
                else:
                    logger.warning("⚠️ Classification service not available (will retry)")
            
            logger.info("🎧 Started enhanced cry detection monitoring")
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to start monitoring: {e}")
            return False

    def stop_monitoring(self):
        """Stop audio monitoring"""
        if not self.is_monitoring:
            return
            
        self.is_monitoring = False
        
        if hasattr(self, 'stream'):
            self.stream.stop_stream()
            self.stream.close()
            
        if hasattr(self, 'p'):
            self.p.terminate()
            
        logger.info("⏹️ Stopped cry detection monitoring")
        
        # Publish monitoring stopped status to ThingsBoard
        if tb_client and tb_client.connected:
            status = self.get_status()
            tb_client.publish_cry_data(status)
            logger.info("📡 Monitoring stopped status published to ThingsBoard")

    def find_audio_device(self):
        """Find a suitable audio input device"""
        try:
            device_count = self.p.get_device_count()
            
            for i in range(device_count):
                device_info = self.p.get_device_info_by_index(i)
                
                # Look for input devices
                if device_info['maxInputChannels'] > 0:
                    logger.info(f"🎤 Found input device {i}: {device_info['name']}")
                    return i
                    
            return None
        except:
            return None

    def audio_callback(self, in_data, frame_count, time_info, status):
        """Audio stream callback"""
        if self.is_monitoring:
            audio_data = np.frombuffer(in_data, dtype=np.float32)
            self.audio_queue.put(audio_data)
            
            # Add to rolling buffer for recording
            self.audio_recorder.add_audio(audio_data)
            
        return (None, pyaudio.paContinue)

    def process_audio(self):
        """Process audio data for cry detection with classification integration"""
        audio_buffer = []
        
        while self.is_monitoring:
            try:
                # Get audio data
                if not self.audio_queue.empty():
                    audio_chunk = self.audio_queue.get(timeout=0.1)
                    audio_buffer.extend(audio_chunk)
                    
                    # Update audio level
                    self.audio_level = float(np.abs(audio_chunk).mean())
                    
                    # Keep buffer at reasonable size (2 seconds of audio)
                    buffer_size = int(self.sample_rate * self.detection_window)
                    if len(audio_buffer) > buffer_size:
                        audio_buffer = audio_buffer[-buffer_size:]
                        
                        # Analyze audio for crying
                        if len(audio_buffer) >= buffer_size:
                            self.analyze_audio(np.array(audio_buffer))
                
                # Periodic publishing to ThingsBoard
                current_time = time.time()
                if tb_client and tb_client.connected:
                    if current_time - self.last_publish_time >= self.publish_interval:
                        status = self.get_status()
                        if tb_client.publish_cry_data(status):
                            self.last_publish_time = current_time
                
                time.sleep(0.01)  # Small delay to prevent CPU overload
                
            except queue.Empty:
                continue
            except Exception as e:
                logger.error(f"❌ Audio processing error: {e}")

    def analyze_audio(self, audio_data):
        """Analyze audio data for cry patterns with classification"""
        try:
            # Basic cry detection algorithm (Stage 1: Real-time trigger)
            is_cry = self.detect_cry_simple(audio_data)
            
            if is_cry and not self.cry_detected:
                self.cry_detected = True
                self.last_cry_time = time.time()
                self.total_detections += 1
                logger.info(f"👶 CRY DETECTED! (#{self.total_detections})")
                
                # Trigger 5-second recording and classification
                # Only classify if cooldown period has passed
                if time.time() - self.last_classification_time > self.classification_cooldown:
                    self.classify_current_cry()
                else:
                    logger.info(f"⏳ Classification cooldown active (last: {time.time() - self.last_classification_time:.1f}s ago)")
                
                # Publish to ThingsBoard with classification data
                if tb_client and tb_client.connected:
                    status = self.get_status()
                    tb_client.publish_cry_data(status)
                
            elif not is_cry and self.cry_detected:
                # Reset cry detection after 3 seconds of no crying
                if time.time() - self.last_cry_time > 3.0:
                    self.cry_detected = False
                    logger.info("😴 Cry stopped")
                    
                    # Clear classification state
                    self.current_classification = None
                    self.current_classification_confidence = None
                    self.current_classification_probs = None
                    self.cry_verified = False
                    self.verification_confidence = 0.0
                    
                    # Publish status update when cry stops
                    if tb_client and tb_client.connected:
                        status = self.get_status()
                        tb_client.publish_cry_data(status)
                    
        except Exception as e:
            logger.error(f"❌ Analysis error: {e}")

    def classify_current_cry(self):
        """
        Classify current cry by saving 5-second recording and sending to classification service
        """
        logger.info("🎙️ Recording 5-second audio for classification...")
        
        try:
            # Save current 5-second buffer to temp file
            with tempfile.NamedTemporaryFile(mode='wb', suffix='.wav', delete=False) as temp_file:
                temp_path = temp_file.name
            
            if not self.audio_recorder.save_recording(temp_path):
                logger.error("Failed to save recording")
                return
            
            logger.info(f"💾 Recording saved: {temp_path}")
            
            # Send to classification service
            classification_result = self.classification_client.classify_audio(temp_path)
            
            # Update classification time
            self.last_classification_time = time.time()
            
            # Clean up temp file
            try:
                os.unlink(temp_path)
            except:
                pass
            
            if classification_result and classification_result.get('success'):
                # Stage 2: Verify with YAMNet detection
                self.cry_verified = classification_result.get('is_cry', False)
                self.verification_confidence = classification_result.get('cry_confidence', 0.0)
                
                if self.cry_verified:
                    logger.info(f"✅ Cry verified by YAMNet (confidence: {self.verification_confidence:.2%})")
                    
                    # Stage 3: Store classification results
                    self.current_classification = classification_result.get('classification')
                    self.current_classification_confidence = classification_result.get('classification_confidence')
                    self.current_classification_probs = classification_result.get('probabilities')
                    
                    if self.current_classification:
                        self.verified_cries += 1
                        logger.info(f"🏷️ Classification: {self.current_classification} ({self.current_classification_confidence:.2%})")
                    else:
                        logger.warning("⚠️ Cry verified but classification confidence too low")
                else:
                    # False positive detected
                    self.false_positives += 1
                    logger.warning(f"⚠️ False positive detected by YAMNet (confidence: {self.verification_confidence:.2%})")
                    self.current_classification = None
                    self.current_classification_confidence = None
                    self.current_classification_probs = None
            else:
                logger.warning("⚠️ Classification service returned no results")
                
        except Exception as e:
            logger.error(f"❌ Classification error: {e}")

    def detect_cry_simple(self, audio_data):
        """Simple cry detection based on audio characteristics (Stage 1: Real-time trigger)"""
        try:
            # Calculate basic audio features
            rms = np.sqrt(np.mean(audio_data**2))
            
            # Check if audio level is above noise threshold
            if rms < self.noise_threshold:
                return False
            
            # FFT for frequency analysis
            fft = np.fft.fft(audio_data)
            freqs = np.fft.fftfreq(len(fft), 1/self.sample_rate)
            magnitude = np.abs(fft)
            
            # Focus on cry frequency range (300-2000 Hz)
            cry_freq_mask = (freqs >= self.cry_frequency_range[0]) & (freqs <= self.cry_frequency_range[1])
            cry_power = np.sum(magnitude[cry_freq_mask])
            total_power = np.sum(magnitude)
            
            if total_power > 0:
                cry_ratio = cry_power / total_power
                
                # Detect cry based on frequency characteristics
                is_loud = rms > (self.sensitivity * 0.1)
                has_cry_frequencies = cry_ratio > 0.3
                
                return is_loud and has_cry_frequencies
            
            return False
            
        except Exception as e:
            logger.error(f"❌ Detection error: {e}")
            return False

    def get_status(self):
        """Get current detection status with classification data"""
        uptime = time.time() - self.monitoring_start_time if self.monitoring_start_time else 0
        
        status = {
            "is_monitoring": self.is_monitoring,
            "cry_detected": self.cry_detected,
            "audio_level": round(self.audio_level, 3),
            "sensitivity": self.sensitivity,
            "total_detections": self.total_detections,
            "verified_cries": self.verified_cries,
            "false_positives": self.false_positives,
            "last_cry_time": self.last_cry_time,
            "uptime_minutes": round(uptime / 60, 1),
            "timestamp": time.time(),
            "classification_enabled": self.classification_client.enabled,
            "classification_service_available": self.classification_client.service_available
        }
        
        # Add classification data if available
        if self.current_classification:
            status["classification"] = self.current_classification
            status["classification_confidence"] = self.current_classification_confidence
            status["classification_probabilities"] = self.current_classification_probs
        
        # Add verification status
        if self.cry_detected:
            status["verified"] = self.cry_verified
            status["verification_confidence"] = self.verification_confidence
        
        return status

# HTTP API for cry detection status
class CryDetectionHTTPHandler(http.server.BaseHTTPRequestHandler):
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/cry/status':
            self.send_cry_status()
        elif self.path == '/cry/start':
            self.start_cry_detection()
        elif self.path == '/cry/stop':
            self.stop_cry_detection()
        elif self.path == '/':
            self.send_info()
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
    
    def send_cry_status(self):
        """Send cry detection status"""
        try:
            status = cry_detector.get_status()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.add_cors_headers()
            self.end_headers()
            
            response = json.dumps(status, indent=2)
            self.wfile.write(response.encode('utf-8'))
            
        except Exception as e:
            self.send_error(500, f"Error: {str(e)}")
    
    def start_cry_detection(self):
        """Start cry detection"""
        try:
            success = cry_detector.start_monitoring()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.add_cors_headers()
            self.end_headers()
            
            response = json.dumps({"success": success, "message": "Started" if success else "Failed to start"})
            self.wfile.write(response.encode('utf-8'))
            
        except Exception as e:
            self.send_error(500, f"Error: {str(e)}")
    
    def stop_cry_detection(self):
        """Stop cry detection"""
        try:
            cry_detector.stop_monitoring()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.add_cors_headers()
            self.end_headers()
            
            response = json.dumps({"success": True, "message": "Stopped"})
            self.wfile.write(response.encode('utf-8'))
            
        except Exception as e:
            self.send_error(500, f"Error: {str(e)}")
    
    def send_info(self):
        """Send API info"""
        info = {
            "message": "Enhanced Cry Detection API with Classification",
            "version": "2.0.0",
            "architecture": "Hybrid: Real-time detection → 5-sec recording → YAMNet verification → Ensemble classification",
            "endpoints": {
                "/cry/status": "Get detection status (includes classification)",
                "/cry/start": "Start monitoring",
                "/cry/stop": "Stop monitoring"
            },
            "classification_service": CLASSIFICATION_SERVICE_URL,
            "classification_enabled": CLASSIFICATION_ENABLED
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
        logger.info(f"[HTTP] {format % args}")

# Global cry detector instance
cry_detector = EnhancedCryDetector()

# Global ThingsBoard client instance
tb_client = None

def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    logger.info("\n🛑 Shutting down enhanced cry detector...")
    cry_detector.stop_monitoring()
    if tb_client:
        tb_client.disconnect()
    sys.exit(0)

def main():
    """Main function"""
    global tb_client
    
    signal.signal(signal.SIGINT, signal_handler)
    
    logger.info("=" * 70)
    logger.info("🍼 Enhanced Cry Detection System Starting...")
    logger.info("=" * 70)
    
    # Initialize ThingsBoard client
    try:
        tb_client = ThingsBoardClient()
        if tb_client.enabled:
            tb_client.connect()
            logger.info("✅ ThingsBoard connection initialized")
        else:
            logger.warning("⚠️ ThingsBoard integration disabled (missing credentials)")
    except Exception as e:
        logger.warning(f"⚠️ Failed to initialize ThingsBoard: {e}")
        tb_client = None
    
    # Start HTTP server
    port = 8888
    server_address = ('', port)
    
    try:
        httpd = http.server.HTTPServer(server_address, CryDetectionHTTPHandler)
        logger.info(f"🌐 Enhanced Cry Detection API: http://localhost:{port}")
        logger.info(f"📊 Status endpoint: http://localhost:{port}/cry/status")
        logger.info(f"▶️  Start endpoint: http://localhost:{port}/cry/start")
        logger.info(f"⏹️  Stop endpoint: http://localhost:{port}/cry/stop")
        logger.info(f"🎤 Audio monitoring ready")
        logger.info(f"🎯 Classification service: {CLASSIFICATION_SERVICE_URL}")
        logger.info("=" * 70)
        
        # Auto-start monitoring on server startup
        logger.info("🚀 Auto-starting enhanced cry detection monitoring...")
        if cry_detector.start_monitoring():
            logger.info("✅ Cry detection monitoring started automatically")
            # Publish initial status to ThingsBoard
            if tb_client and tb_client.connected:
                status = cry_detector.get_status()
                tb_client.publish_cry_data(status)
                logger.info("📡 Initial status published to ThingsBoard")
        else:
            logger.warning("⚠️ Failed to auto-start monitoring")
        
        logger.info("⏹️  Press Ctrl+C to stop")
        
        httpd.serve_forever()
        
    except Exception as e:
        logger.error(f"❌ Server error: {e}")
        cry_detector.stop_monitoring()

if __name__ == "__main__":
    main()
