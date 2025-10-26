#!/usr/bin/env python3
"""
Real-time Cry Detection System for Raspberry Pi
Uses audio input to detect baby crying sounds.

Features:
- Real-time audio monitoring
- Machine learning-based cry detection
- HTTP API for status updates
- Audio level monitoring
- Configurable sensitivity

Usage:
    python3 cry_detector.py

Dependencies:
    sudo apt install python3-pyaudio python3-numpy python3-scipy
    pip3 install librosa soundfile --break-system-packages
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

# ThingsBoard Configuration
TB_HOST = "thingsboard.cloud"
TB_PORT = 1883
ACCESS_TOKEN = os.getenv("TB_ACCESS_TOKEN", "2ztut7be6ppooyiueorb")  # Replace with your device token

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ThingsBoardClient:
    """MQTT client for ThingsBoard communication"""
    
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
        """Publish cry detection data to ThingsBoard"""
        if not self.enabled or not self.connected:
            return False
        
        try:
            # Prepare telemetry data
            telemetry = {
                'cry_detected': cry_status.get('cry_detected', False),
                'cry_audio_level': round(cry_status.get('audio_level', 0), 3),  # 3 decimal places for better precision
                'cry_sensitivity': cry_status.get('sensitivity', 0.6),
                'cry_total_detections': cry_status.get('total_detections', 0),
                'cry_monitoring': cry_status.get('is_monitoring', False),
                'timestamp': int(time.time() * 1000)
            }
            
            # Add last cry time if available
            if cry_status.get('last_cry_time'):
                telemetry['cry_last_detected'] = cry_status['last_cry_time']
            
            payload = json.dumps(telemetry)
            result = self.client.publish(self.telemetry_topic, payload, qos=1)
            
            # Wait for publish to complete
            result.wait_for_publish()
            
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                logger.info(f"✓ Cry data published to ThingsBoard")
                return True
            else:
                logger.error(f"✗ Publish failed with code {result.rc}")
                return False
        except Exception as e:
            logger.error(f"Error publishing to ThingsBoard: {e}")
            return False
    
    def disconnect(self):
        """Disconnect from ThingsBoard"""
        if self.enabled:
            self.client.loop_stop()
            self.client.disconnect()
            logger.info("Disconnected from ThingsBoard")

class CryDetector:
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
        
        # ThingsBoard publishing
        self.last_publish_time = 0
        self.publish_interval = 30  # Publish every 30 seconds
        self.false_positives = 0
        self.monitoring_start_time = None
        
        print("🍼 Cry Detector initialized")
        print(f"📊 Sample Rate: {sample_rate} Hz")
        print(f"🔊 Chunk Size: {chunk_size}")
        print(f"⚙️ Sensitivity: {sensitivity}")

    def start_monitoring(self):
        """Start audio monitoring for cry detection"""
        if self.is_monitoring:
            return False
            
        try:
            self.p = pyaudio.PyAudio()
            
            # Find audio input device
            device_index = self.find_audio_device()
            if device_index is None:
                print("❌ No audio input device found!")
                return False
            
            print(f"🎤 Using audio device: {device_index}")
            
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
            
            print("🎧 Started cry detection monitoring")
            return True
            
        except Exception as e:
            print(f"❌ Failed to start monitoring: {e}")
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
            
        print("⏹️ Stopped cry detection monitoring")
        
        # Publish monitoring stopped status to ThingsBoard
        if tb_client and tb_client.connected:
            status = self.get_status()
            tb_client.publish_cry_data(status)
            print("📡 Monitoring stopped status published to ThingsBoard")

    def find_audio_device(self):
        """Find a suitable audio input device"""
        try:
            device_count = self.p.get_device_count()
            
            for i in range(device_count):
                device_info = self.p.get_device_info_by_index(i)
                
                # Look for input devices
                if device_info['maxInputChannels'] > 0:
                    print(f"🎤 Found input device {i}: {device_info['name']}")
                    return i
                    
            return None
        except:
            return None

    def audio_callback(self, in_data, frame_count, time_info, status):
        """Audio stream callback"""
        if self.is_monitoring:
            audio_data = np.frombuffer(in_data, dtype=np.float32)
            self.audio_queue.put(audio_data)
        return (None, pyaudio.paContinue)

    def process_audio(self):
        """Process audio data for cry detection"""
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
                            print(f"📡 Periodic status published to ThingsBoard")
                
                time.sleep(0.01)  # Small delay to prevent CPU overload
                
            except queue.Empty:
                continue
            except Exception as e:
                print(f"❌ Audio processing error: {e}")

    def analyze_audio(self, audio_data):
        """Analyze audio data for cry patterns"""
        try:
            # Basic cry detection algorithm
            is_cry = self.detect_cry_simple(audio_data)
            
            if is_cry and not self.cry_detected:
                self.cry_detected = True
                self.last_cry_time = time.time()
                self.total_detections += 1
                print(f"👶 CRY DETECTED! (#{self.total_detections})")
                
                # Publish to ThingsBoard when cry is detected
                if tb_client and tb_client.connected:
                    status = self.get_status()
                    tb_client.publish_cry_data(status)
                    print("📡 Cry detection published to ThingsBoard")
                
            elif not is_cry and self.cry_detected:
                # Reset cry detection after 3 seconds of no crying
                if time.time() - self.last_cry_time > 3.0:
                    self.cry_detected = False
                    print("😴 Cry stopped")
                    
                    # Publish status update when cry stops
                    if tb_client and tb_client.connected:
                        status = self.get_status()
                        tb_client.publish_cry_data(status)
                        print("📡 Cry stopped status published to ThingsBoard")
                    
        except Exception as e:
            print(f"❌ Analysis error: {e}")

    def detect_cry_simple(self, audio_data):
        """Simple cry detection based on audio characteristics"""
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
            print(f"❌ Detection error: {e}")
            return False

    def get_status(self):
        """Get current detection status"""
        uptime = time.time() - self.monitoring_start_time if self.monitoring_start_time else 0
        
        return {
            "is_monitoring": self.is_monitoring,
            "cry_detected": self.cry_detected,
            "audio_level": round(self.audio_level, 3),
            "sensitivity": self.sensitivity,
            "total_detections": self.total_detections,
            "last_cry_time": self.last_cry_time,
            "uptime_minutes": round(uptime / 60, 1),
            "timestamp": time.time()
        }

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
            "message": "Cry Detection API",
            "version": "1.0.0",
            "endpoints": {
                "/cry/status": "Get detection status",
                "/cry/start": "Start monitoring",
                "/cry/stop": "Stop monitoring"
            }
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

# Global cry detector instance
cry_detector = CryDetector()

# Global ThingsBoard client instance
tb_client = None

def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    print("\n🛑 Shutting down cry detector...")
    cry_detector.stop_monitoring()
    if tb_client:
        tb_client.disconnect()
    sys.exit(0)

def main():
    """Main function"""
    global tb_client
    
    signal.signal(signal.SIGINT, signal_handler)
    
    print("🍼 Cry Detection System Starting...")
    print("=" * 50)
    
    # Initialize ThingsBoard client
    try:
        tb_client = ThingsBoardClient()
        if tb_client.enabled:
            tb_client.connect()
            print("✅ ThingsBoard connection initialized")
        else:
            print("⚠️ ThingsBoard integration disabled (missing credentials)")
    except Exception as e:
        print(f"⚠️ Failed to initialize ThingsBoard: {e}")
        tb_client = None
    
    # Start HTTP server
    port = 8888
    server_address = ('', port)
    
    try:
        httpd = http.server.HTTPServer(server_address, CryDetectionHTTPHandler)
        print(f"🌐 Cry Detection API: http://localhost:{port}")
        print(f"📊 Status endpoint: http://localhost:{port}/cry/status")
        print(f"▶️  Start endpoint: http://localhost:{port}/cry/start")
        print(f"⏹️  Stop endpoint: http://localhost:{port}/cry/stop")
        print(f"🎤 Audio monitoring ready")
        print("=" * 50)
        
        # Auto-start monitoring on server startup
        print("🚀 Auto-starting cry detection monitoring...")
        if cry_detector.start_monitoring():
            print("✅ Cry detection monitoring started automatically")
            # Publish initial status to ThingsBoard
            if tb_client and tb_client.connected:
                status = cry_detector.get_status()
                tb_client.publish_cry_data(status)
                print("📡 Initial status published to ThingsBoard")
        else:
            print("⚠️ Failed to auto-start monitoring")
        
        print("⏹️  Press Ctrl+C to stop")
        
        httpd.serve_forever()
        
    except Exception as e:
        print(f"❌ Server error: {e}")
        cry_detector.stop_monitoring()

if __name__ == "__main__":
    main()
