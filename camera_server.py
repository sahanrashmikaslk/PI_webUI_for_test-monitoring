#!/usr/bin/env python3
"""
Camera Server for Pi Monitoring System
Manages mjpg-streamer processes for multiple cameras
Includes direct autostart for specified camera configurations
"""

import subprocess
import json
import time
import os
import signal
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

class CameraManager:
    def __init__(self):
        self.processes = {}
        self.camera_configs = {
            'camera1': {
                'name': 'Live Stream (Infant)',
                'device': '/dev/video2',  # V380 camera for infant monitoring
                'port': 8080,
                'resolution': '640x480',
                'fps': 30,
                'process': None
            },
            'camera2': {
                'name': 'LCD Display Stream',
                'device': '/dev/video0',  # USB 2.0 camera for LCD display
                'port': 8081,
                'resolution': '640x480',
                'fps': 30,
                'process': None
            }
        }
    
    def start_camera(self, camera_id):
        """Start a specific camera stream"""
        if camera_id not in self.camera_configs:
            return False, f"Unknown camera: {camera_id}"
        
        config = self.camera_configs[camera_id]
        
        # Check if camera is already running
        if self.is_camera_running(camera_id):
            return True, f"Camera {camera_id} is already running"
        
        # Check if device exists
        if not os.path.exists(config['device']):
            return False, f"Camera device {config['device']} not found"
        
        # Check if port is already in use
        if self.is_port_in_use(config['port']):
            return False, f"Port {config['port']} is already in use"
        
        try:
            # Build mjpg_streamer command
            cmd = [
                'mjpg_streamer',
                '-i', f"input_uvc.so -d {config['device']} -r {config['resolution']} -f {config['fps']}",
                '-o', f"output_http.so -p {config['port']} -w /usr/local/share/mjpg-streamer/www"
            ]
            
            print(f"🚀 Starting {config['name']} on {config['device']}:{config['port']}")
            print(f"Command: {' '.join(cmd)}")
            
            # Start the process
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                preexec_fn=os.setsid  # Create new process group
            )
            
            # Store process reference
            config['process'] = process
            self.processes[camera_id] = process
            
            # Give it a moment to start
            time.sleep(2)
            
            # Check if process is still running
            if process.poll() is None:
                print(f"✅ {config['name']} started successfully on port {config['port']}")
                return True, f"Camera {camera_id} started successfully"
            else:
                # Process failed to start
                stdout, stderr = process.communicate()
                error_msg = stderr.decode() if stderr else "Unknown error"
                print(f"❌ Failed to start {config['name']}: {error_msg}")
                return False, f"Failed to start camera {camera_id}: {error_msg}"
                
        except Exception as e:
            print(f"❌ Exception starting {config['name']}: {str(e)}")
            return False, f"Exception starting camera {camera_id}: {str(e)}"
    
    def stop_camera(self, camera_id):
        """Stop a specific camera stream"""
        if camera_id not in self.camera_configs:
            return False, f"Unknown camera: {camera_id}"
        
        config = self.camera_configs[camera_id]
        process = config.get('process')
        
        if not process:
            return True, f"Camera {camera_id} is not running"
        
        try:
            # Kill process group to ensure all child processes are terminated
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
            
            # Wait for process to terminate
            process.wait(timeout=5)
            
            # Clean up references
            config['process'] = None
            if camera_id in self.processes:
                del self.processes[camera_id]
            
            print(f"⏹️ {config['name']} stopped")
            return True, f"Camera {camera_id} stopped successfully"
            
        except subprocess.TimeoutExpired:
            # Force kill if it doesn't terminate gracefully
            try:
                os.killpg(os.getpgid(process.pid), signal.SIGKILL)
                config['process'] = None
                if camera_id in self.processes:
                    del self.processes[camera_id]
                return True, f"Camera {camera_id} force stopped"
            except:
                return False, f"Failed to stop camera {camera_id}"
        except Exception as e:
            return False, f"Error stopping camera {camera_id}: {str(e)}"
    
    def is_camera_running(self, camera_id):
        """Check if a camera is currently running"""
        if camera_id not in self.camera_configs:
            return False
        
        process = self.camera_configs[camera_id].get('process')
        if not process:
            return False
        
        # Check if process is still alive
        return process.poll() is None
    
    def is_port_in_use(self, port):
        """Check if a port is already in use"""
        try:
            result = subprocess.run(
                ['netstat', '-tln'], 
                capture_output=True, 
                text=True, 
                timeout=5
            )
            return f":{port} " in result.stdout
        except:
            return False
    
    def get_status(self):
        """Get status of all cameras"""
        status = {}
        for camera_id, config in self.camera_configs.items():
            status[camera_id] = {
                'name': config['name'],
                'device': config['device'],
                'port': config['port'],
                'running': self.is_camera_running(camera_id),
                'device_exists': os.path.exists(config['device'])
            }
        return status
    
    def start_all_cameras(self):
        """Start all configured cameras"""
        results = {}
        for camera_id in self.camera_configs:
            success, message = self.start_camera(camera_id)
            results[camera_id] = {'success': success, 'message': message}
        return results
    
    def stop_all_cameras(self):
        """Stop all running cameras"""
        results = {}
        for camera_id in self.camera_configs:
            success, message = self.stop_camera(camera_id)
            results[camera_id] = {'success': success, 'message': message}
        return results

# Global camera manager instance
camera_manager = CameraManager()

class CameraHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        """Handle GET requests"""
        # Add CORS headers
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        
        # Parse URL
        parsed_url = urlparse(self.path)
        path = parsed_url.path
        query_params = parse_qs(parsed_url.query)
        
        try:
            if path == '/camera/status':
                # Get status of all cameras
                status = camera_manager.get_status()
                response = {
                    'success': True,
                    'cameras': status,
                    'timestamp': time.time()
                }
                
            elif path == '/camera/start':
                # Start specific camera or all cameras
                camera_id = query_params.get('id', [None])[0]
                
                if camera_id:
                    success, message = camera_manager.start_camera(camera_id)
                    response = {
                        'success': success,
                        'message': message,
                        'camera_id': camera_id
                    }
                else:
                    # Start all cameras
                    results = camera_manager.start_all_cameras()
                    response = {
                        'success': True,
                        'message': 'Started all cameras',
                        'results': results
                    }
                    
            elif path == '/camera/stop':
                # Stop specific camera or all cameras  
                camera_id = query_params.get('id', [None])[0]
                
                if camera_id:
                    success, message = camera_manager.stop_camera(camera_id)
                    response = {
                        'success': success,
                        'message': message,
                        'camera_id': camera_id
                    }
                else:
                    # Stop all cameras
                    results = camera_manager.stop_all_cameras()
                    response = {
                        'success': True,
                        'message': 'Stopped all cameras',
                        'results': results
                    }
                    
            elif path == '/' or path == '/health':
                # Health check endpoint
                response = {
                    'success': True,
                    'service': 'Camera Server',
                    'version': '1.0',
                    'cameras': camera_manager.get_status()
                }
                
            else:
                # Invalid endpoint
                response = {
                    'success': False,
                    'error': 'Invalid endpoint',
                    'available_endpoints': [
                        '/camera/status',
                        '/camera/start?id=camera1',
                        '/camera/stop?id=camera2',
                        '/camera/start (all)',
                        '/camera/stop (all)'
                    ]
                }
                
        except Exception as e:
            response = {
                'success': False,
                'error': str(e)
            }
        
        # Send response
        self.wfile.write(json.dumps(response, indent=2).encode())
    
    def do_OPTIONS(self):
        """Handle OPTIONS requests for CORS"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def log_message(self, format, *args):
        """Override to provide better logging"""
        print(f"📹 {self.address_string()} - {format % args}")

def auto_start_cameras():
    """Auto-start cameras on server startup"""
    print("🚀 Auto-starting cameras...")
    time.sleep(3)  # Wait for system to be ready
    
    results = camera_manager.start_all_cameras()
    
    for camera_id, result in results.items():
        if result['success']:
            print(f"✅ Auto-started {camera_id}: {result['message']}")
        else:
            print(f"❌ Failed to auto-start {camera_id}: {result['message']}")

def main():
    print("🎬 Pi Camera Server Starting...")
    print("=" * 50)
    
    # Start auto-start thread
    auto_start_thread = threading.Thread(target=auto_start_cameras, daemon=True)
    auto_start_thread.start()
    
    # Start HTTP server
    server_address = ('', 8889)
    httpd = HTTPServer(server_address, CameraHandler)
    
    print(f"📹 Camera Server running on port 8889")
    print("🌐 Available endpoints:")
    print("  http://localhost:8889/camera/status")
    print("  http://localhost:8889/camera/start")
    print("  http://localhost:8889/camera/stop")
    print("  http://localhost:8889/camera/start?id=camera1")
    print("  http://localhost:8889/camera/stop?id=camera2")
    print("")
    print("📷 Camera Configuration:")
    for camera_id, config in camera_manager.camera_configs.items():
        print(f"  {camera_id}: {config['name']}")
        print(f"    Device: {config['device']}")
        print(f"    Port: {config['port']}")
        print(f"    Resolution: {config['resolution']}")
        print("")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n⏹️ Shutting down camera server...")
        
        # Stop all cameras
        print("🛑 Stopping all cameras...")
        camera_manager.stop_all_cameras()
        
        httpd.shutdown()
        print("✅ Camera server stopped")

if __name__ == "__main__":
    main()
