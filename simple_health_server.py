#!/usr/bin/env python3
"""
Simple HTTP Health Server for Raspberry Pi Monitoring
Uses only built-in Python libraries - no external dependencies required!

Usage:
    python3 simple_health_server.py

The server will run on port 9000 and provide health data at /health endpoint.
"""

import json
import http.server
import socketserver
import urllib.parse
import subprocess
import os
import time
import threading
from datetime import datetime

class HealthHTTPRequestHandler(http.server.BaseHTTPRequestHandler):
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/health':
            self.send_health_response()
        elif self.path == '/services':
            self.send_services_status()
        elif self.path == '/':
            self.send_info_response()
        else:
            self.send_error(404, "Not Found")
    
    def do_POST(self):
        """Handle POST requests"""
        if self.path == '/shutdown':
            self.handle_shutdown()
        elif self.path == '/reboot':
            self.handle_reboot()
        else:
            self.send_error(404, "Not Found")
    
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.add_cors_headers()
        self.end_headers()
    
    def add_cors_headers(self):
        """Add CORS headers to allow cross-origin requests"""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
    
    def handle_shutdown(self):
        """Handle system shutdown request"""
        try:
            # Send response first
            response_data = {
                "status": "success",
                "message": "Raspberry Pi will shutdown in 5 seconds",
                "timestamp": time.time()
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.add_cors_headers()
            self.end_headers()
            
            response = json.dumps(response_data, indent=2)
            self.wfile.write(response.encode('utf-8'))
            
            # Schedule shutdown in a separate thread
            def delayed_shutdown():
                time.sleep(5)
                subprocess.run(['sudo', 'shutdown', '-h', 'now'], check=False)
            
            shutdown_thread = threading.Thread(target=delayed_shutdown, daemon=True)
            shutdown_thread.start()
            
        except Exception as e:
            error_data = {
                "status": "error",
                "message": str(e),
                "timestamp": time.time()
            }
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.add_cors_headers()
            self.end_headers()
            response = json.dumps(error_data, indent=2)
            self.wfile.write(response.encode('utf-8'))
    
    def handle_reboot(self):
        """Handle system reboot request"""
        try:
            # Send response first
            response_data = {
                "status": "success",
                "message": "Raspberry Pi will reboot in 5 seconds",
                "timestamp": time.time()
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.add_cors_headers()
            self.end_headers()
            
            response = json.dumps(response_data, indent=2)
            self.wfile.write(response.encode('utf-8'))
            
            # Schedule reboot in a separate thread
            def delayed_reboot():
                time.sleep(5)
                subprocess.run(['sudo', 'reboot'], check=False)
            
            reboot_thread = threading.Thread(target=delayed_reboot, daemon=True)
            reboot_thread.start()
            
        except Exception as e:
            error_data = {
                "status": "error",
                "message": str(e),
                "timestamp": time.time()
            }
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.add_cors_headers()
            self.end_headers()
            response = json.dumps(error_data, indent=2)
            self.wfile.write(response.encode('utf-8'))
    
    def send_services_status(self):
        """Send services status by calling the health check script"""
        try:
            # Run the health check script
            result = subprocess.run(
                ['/usr/local/bin/check_services_health.sh'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.add_cors_headers()
                self.end_headers()
                self.wfile.write(result.stdout.encode('utf-8'))
            else:
                raise Exception("Health check script failed")
                
        except Exception as e:
            error_data = {
                "status": "error",
                "message": f"Failed to check services: {str(e)}",
                "timestamp": time.time()
            }
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.add_cors_headers()
            self.end_headers()
            response = json.dumps(error_data, indent=2)
            self.wfile.write(response.encode('utf-8'))
    
    def send_health_response(self):
        """Send health data as JSON response"""
        try:
            health_data = self.get_health_data()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.add_cors_headers()
            self.end_headers()
            
            response = json.dumps(health_data, indent=2)
            self.wfile.write(response.encode('utf-8'))
            
        except Exception as e:
            self.send_error(500, f"Internal Server Error: {str(e)}")
    
    def send_info_response(self):
        """Send API info"""
        info = {
            "message": "Raspberry Pi Simple Health API",
            "version": "1.0.0",
            "endpoints": {
                "/health": "Get system health metrics",
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
    
    def get_health_data(self):
        """Get system health metrics using built-in tools"""
        health = {
            "cpu": self.get_cpu_usage(),
            "ram": self.get_memory_usage(),
            "temp": self.get_cpu_temperature(),
            "throttled": self.get_throttled_status(),
            "uptime": self.get_uptime(),
            "load": self.get_load_average(),
            "timestamp": time.time()
        }
        return health
    
    def get_cpu_usage(self):
        """Get CPU usage percentage"""
        try:
            # Read /proc/stat for CPU usage
            with open('/proc/stat', 'r') as f:
                line = f.readline()
            cpu_times = [int(x) for x in line.split()[1:]]
            idle_time = cpu_times[3]
            total_time = sum(cpu_times)
            
            # Simple CPU usage calculation (not perfect but works)
            cpu_usage = 100.0 - (idle_time * 100.0 / total_time)
            return round(max(0, min(100, cpu_usage)), 1)
        except:
            return 0.0
    
    def get_memory_usage(self):
        """Get memory usage percentage"""
        try:
            with open('/proc/meminfo', 'r') as f:
                lines = f.readlines()
            
            mem_info = {}
            for line in lines:
                if ':' in line:
                    key, value = line.split(':', 1)
                    mem_info[key.strip()] = int(value.strip().split()[0])
            
            total = mem_info.get('MemTotal', 0)
            available = mem_info.get('MemAvailable', mem_info.get('MemFree', 0))
            
            if total > 0:
                used_percent = ((total - available) / total) * 100
                return round(used_percent, 1)
            return 0.0
        except:
            return 0.0
    
    def get_cpu_temperature(self):
        """Get CPU temperature"""
        try:
            # Try thermal zone first
            with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
                temp = float(f.read().strip()) / 1000.0
                return round(temp, 1)
        except:
            try:
                # Try vcgencmd
                result = subprocess.run(['vcgencmd', 'measure_temp'], 
                                      capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    temp_str = result.stdout.strip()
                    temp = float(temp_str.split('=')[1].split("'")[0])
                    return round(temp, 1)
            except:
                pass
        return 0.0
    
    def get_throttled_status(self):
        """Get throttling status"""
        try:
            result = subprocess.run(['vcgencmd', 'get_throttled'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                output = result.stdout.strip()
                throttled_hex = output.split('=')[1]
                return throttled_hex
        except:
            pass
        return "0x0"
    
    def get_uptime(self):
        """Get system uptime in hours"""
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.read().split()[0])
                return round(uptime_seconds / 3600, 1)
        except:
            return 0.0
    
    def get_load_average(self):
        """Get system load average"""
        try:
            load_avg = os.getloadavg()
            return {
                "1m": round(load_avg[0], 2),
                "5m": round(load_avg[1], 2),
                "15m": round(load_avg[2], 2)
            }
        except:
            return {"1m": 0.0, "5m": 0.0, "15m": 0.0}
    
    def log_message(self, format, *args):
        """Custom log message format"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {format % args}")

class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    """HTTP Server that handles requests in separate threads"""
    allow_reuse_address = True

def run_server(port=9000):
    """Run the health server"""
    server_address = ('', port)
    
    try:
        httpd = ThreadedHTTPServer(server_address, HealthHTTPRequestHandler)
        print(f"🚀 Simple Health API Server starting...")
        print(f"📊 Health endpoint: http://localhost:{port}/health")
        print(f"ℹ️  API info: http://localhost:{port}/")
        print(f"🌐 External access: http://<your-pi-ip>:{port}/health")
        print(f"⏹️  Press Ctrl+C to stop the server")
        print("=" * 50)
        
        httpd.serve_forever()
        
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
        httpd.shutdown()
    except Exception as e:
        print(f"❌ Server error: {e}")

if __name__ == "__main__":
    run_server()
