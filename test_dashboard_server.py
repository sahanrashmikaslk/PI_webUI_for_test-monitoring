#!/usr/bin/env python3
"""
Simple HTTP server for test dashboard
Serves the test_dashboard.html on port 8090
"""

import http.server
import socketserver
import os
import signal
import sys

PORT = 8090
DASHBOARD_FILE = '/home/sahan/test_dashboard.html'

class DashboardHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler to serve the dashboard"""
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/' or self.path == '/index.html':
            # Serve the dashboard
            try:
                with open(DASHBOARD_FILE, 'rb') as f:
                    content = f.read()
                
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.send_header('Content-length', len(content))
                self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
                self.send_header('Pragma', 'no-cache')
                self.send_header('Expires', '0')
                self.end_headers()
                self.wfile.write(content)
            except Exception as e:
                self.send_error(500, f"Error serving dashboard: {e}")
        else:
            # Return 404 for other paths
            self.send_error(404, "File not found")
    
    def log_message(self, format, *args):
        """Custom log format"""
        print(f"[{self.log_date_time_string()}] {format % args}")

def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    print("\n🛑 Shutting down test dashboard server...")
    sys.exit(0)

def main():
    """Main function"""
    signal.signal(signal.SIGINT, signal_handler)
    
    print("🌐 Test Dashboard Server Starting...")
    print("=" * 50)
    
    # Check if dashboard file exists
    if not os.path.exists(DASHBOARD_FILE):
        print(f"❌ Dashboard file not found: {DASHBOARD_FILE}")
        sys.exit(1)
    
    try:
        with socketserver.TCPServer(("", PORT), DashboardHandler) as httpd:
            print(f"✅ Test Dashboard Server running on port {PORT}")
            print(f"📊 Dashboard URL: http://localhost:{PORT}/")
            print(f"📊 Network URL: http://<raspberry-pi-ip>:{PORT}/")
            print(f"📄 Serving: {DASHBOARD_FILE}")
            print("=" * 50)
            print("⏹️  Press Ctrl+C to stop")
            
            httpd.serve_forever()
            
    except OSError as e:
        if e.errno == 98:
            print(f"❌ Port {PORT} is already in use")
            print(f"💡 Try: sudo lsof -i :{PORT} to find the process")
        else:
            print(f"❌ Server error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
