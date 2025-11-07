#!/usr/bin/env python3
"""
Simple Health API Server for Raspberry Pi Monitoring
Run this on your Raspberry Pi to provide system health data.

Usage:
    python3 health_server.py

The server will run on port 9000 and provide health data at /health endpoint.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import psutil
import json
import uvicorn
from typing import Dict, Any
import subprocess
import os

app = FastAPI(title="Raspberry Pi Health API", version="1.0.0")

# Enable CORS for web dashboard
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your dashboard URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_cpu_temperature():
    """Get CPU temperature from Raspberry Pi."""
    try:
        # Method 1: Try thermal zone (most common)
        with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
            temp = float(f.read().strip()) / 1000.0
            return temp
    except:
        try:
            # Method 2: Try vcgencmd (requires root or video group)
            result = subprocess.run(['vcgencmd', 'measure_temp'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                temp_str = result.stdout.strip()
                # Extract temperature from "temp=45.1'C" format
                temp = float(temp_str.split('=')[1].split("'")[0])
                return temp
        except:
            pass
    return None

def get_throttled_status():
    """Get throttling status from Raspberry Pi."""
    try:
        result = subprocess.run(['vcgencmd', 'get_throttled'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            output = result.stdout.strip()
            # Extract hex value from "throttled=0x0" format
            throttled_hex = output.split('=')[1]
            return throttled_hex
    except:
        pass
    return None

@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "message": "Raspberry Pi Health API",
        "version": "1.0.0",
        "endpoints": {
            "/health": "Get system health metrics",
            "/docs": "API documentation"
        }
    }

@app.get("/health")
async def get_health() -> Dict[str, Any]:
    """Get comprehensive system health metrics."""
    try:
        # CPU usage (average over 1 second)
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # Memory usage
        memory = psutil.virtual_memory()
        ram_percent = memory.percent
        
        # Disk usage (root filesystem)
        disk = psutil.disk_usage('/')
        disk_percent = (disk.used / disk.total) * 100
        
        # Network I/O
        network = psutil.net_io_counters()
        
        # System load
        load_avg = os.getloadavg()
        
        # Temperature
        temperature = get_cpu_temperature()
        
        # Throttling status
        throttled = get_throttled_status()
        
        # System uptime
        boot_time = psutil.boot_time()
        uptime = psutil.time.time() - boot_time
        
        # Process count
        process_count = len(psutil.pids())
        
        health_data = {
            "cpu": round(cpu_percent, 1),
            "ram": round(ram_percent, 1),
            "disk": round(disk_percent, 1),
            "temp": round(temperature, 1) if temperature else None,
            "throttled": throttled,
            "load_1m": round(load_avg[0], 2),
            "load_5m": round(load_avg[1], 2),
            "load_15m": round(load_avg[2], 2),
            "uptime_hours": round(uptime / 3600, 1),
            "process_count": process_count,
            "network": {
                "bytes_sent": network.bytes_sent,
                "bytes_recv": network.bytes_recv,
                "packets_sent": network.packets_sent,
                "packets_recv": network.packets_recv
            },
            "memory": {
                "total_gb": round(memory.total / (1024**3), 2),
                "available_gb": round(memory.available / (1024**3), 2),
                "used_gb": round(memory.used / (1024**3), 2)
            },
            "timestamp": psutil.time.time()
        }
        
        return health_data
        
    except Exception as e:
        return {
            "error": str(e),
            "cpu": 0,
            "ram": 0,
            "temp": None,
            "throttled": None,
            "timestamp": psutil.time.time()
        }

@app.get("/health/simple")
async def get_simple_health():
    """Get basic health metrics (compatible with original dashboard)."""
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        temperature = get_cpu_temperature()
        throttled = get_throttled_status()
        
        return {
            "cpu": round(cpu_percent, 1),
            "ram": round(memory.percent, 1),
            "temp": round(temperature, 1) if temperature else 0,
            "throttled": throttled or "0x0"
        }
    except Exception as e:
        return {
            "cpu": 0,
            "ram": 0,
            "temp": 0,
            "throttled": "0x0",
            "error": str(e)
        }

if __name__ == "__main__":
    print("Starting Raspberry Pi Health API Server...")
    print("Dashboard will be available at: http://localhost:9000")
    print("Health endpoint: http://localhost:9000/health")
    print("API docs: http://localhost:9000/docs")
    print("\nPress Ctrl+C to stop the server")
    
    uvicorn.run(
        app, 
        host="0.0.0.0",  # Listen on all interfaces
        port=9000,
        log_level="info"
    )
