#!/usr/bin/env python3
"""
NTE Recommendation Engine Server for Raspberry Pi
Integrates with ThingsBoard and provides REST API for recommendations

Usage:
    python3 nte_server.py

Features:
- REST API for NTE recommendations
- Baby registration with birth date/time and weight
- Age calculation from birth date
- Hardcoded air temperature (28°C) until LCD reader is trained
- ThingsBoard integration for publishing recommendations
- CORS enabled for test dashboard access
"""

import json
import os
import sys
import time
import threading
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import uvicorn

# Add NTE_recommendation_engine to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'NTE_recommendation_engine'))
from nte_rules import recommend

# Import MQTT for ThingsBoard
try:
    import paho.mqtt.client as mqtt
    MQTT_AVAILABLE = True
except ImportError:
    print("⚠️ paho-mqtt not installed. ThingsBoard publishing disabled.")
    MQTT_AVAILABLE = False

# ThingsBoard Configuration
CONFIG_DIR = os.path.join(os.path.dirname(__file__), 'incubator_monitoring_with_thingsboard_integration', 'config')
CONFIG_PATH = os.path.join(CONFIG_DIR, 'device_credentials.json')

# Load ThingsBoard credentials
TB_HOST = "thingsboard.cloud"
TB_PORT = 1883
ACCESS_TOKEN = None

try:
    with open(CONFIG_PATH, 'r') as f:
        device_config = json.load(f)
    TB_HOST = device_config.get('thingsboard_host', TB_HOST)
    TB_PORT = device_config.get('mqtt_port', TB_PORT)
    ACCESS_TOKEN = device_config.get('access_token')
    print(f"✓ ThingsBoard configuration loaded from {CONFIG_PATH}")
except Exception as e:
    print(f"⚠️ Could not load ThingsBoard config: {e}")
    print("ThingsBoard publishing will be disabled")

# Default air temperature (fallback if LCD reader is unavailable)
DEFAULT_AIR_TEMP = 28.0  # °C

# LCD reading server configuration
LCD_SERVER_HOST = "localhost"
LCD_SERVER_PORT = 9001

# Baby data storage (in production, use a database)
BABY_DATA_FILE = os.path.join(os.path.dirname(__file__), 'baby_data.json')

def fetch_air_temp_from_lcd() -> Optional[float]:
    """
    Fetch real-time air temperature from LCD reading server.
    Returns None if unavailable, allowing fallback to DEFAULT_AIR_TEMP.
    """
    try:
        import requests
        response = requests.get(
            f"http://{LCD_SERVER_HOST}:{LCD_SERVER_PORT}/readings",
            timeout=2
        )
        if response.status_code == 200:
            data = response.json()
            if data.get('status') == 'success':
                readings = data.get('readings', {})
                air_temp_data = readings.get('air_temp_value')
                if air_temp_data and 'value' in air_temp_data:
                    air_temp = float(air_temp_data['value'])
                    print(f"✅ Fetched air_temp from LCD: {air_temp}°C")
                    return air_temp
    except Exception as e:
        print(f"⚠️ Failed to fetch air_temp from LCD server: {e}")
    
    return None

app = FastAPI(
    title="NTE Recommendation Engine",
    description="Neutral Thermal Environment recommendations for neonatal incubators",
    version="1.0.0"
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic Models
class BabyRegistration(BaseModel):
    baby_id: str = Field(..., description="Unique identifier for the baby")
    birth_date: str = Field(..., description="Birth date in format YYYY-MM-DD")
    birth_time: str = Field(..., description="Birth time in format HH:MM")
    weight_g: int = Field(..., description="Birth weight in grams", gt=0)
    name: Optional[str] = Field(None, description="Baby's name (optional)")

class BabyUpdate(BaseModel):
    weight_g: Optional[int] = Field(None, description="Updated weight in grams", gt=0)
    skin_temp: Optional[float] = Field(None, description="Current skin temperature in °C")
    humidity: Optional[float] = Field(None, description="Current humidity in %")

class NTERequest(BaseModel):
    baby_id: str = Field(..., description="Baby identifier")
    air_temp: Optional[float] = Field(None, description="Air temperature override (otherwise uses hardcoded 28°C)")
    skin_temp: Optional[float] = Field(None, description="Current skin temperature in °C")
    humidity: Optional[float] = Field(None, description="Current humidity in %")

# ThingsBoard Client
class ThingsBoardClient:
    """MQTT client for ThingsBoard communication"""
    
    def __init__(self):
        if not ACCESS_TOKEN or not MQTT_AVAILABLE:
            print("⚠️ ThingsBoard not configured or paho-mqtt not available")
            self.enabled = False
            return
            
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, clean_session=True)
        self.client.username_pw_set(ACCESS_TOKEN)
        self.client.on_connect = self.on_connect
        self.client.on_disconnect = self.on_disconnect
        self.client.reconnect_delay_set(min_delay=1, max_delay=120)
        self.connected = False
        self.enabled = True
        self.telemetry_topic = 'v1/devices/me/telemetry'
        
    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            print("✓ Connected to ThingsBoard successfully")
            self.connected = True
        else:
            print(f"✗ ThingsBoard connection failed with code {rc}")
            self.connected = False
    
    def on_disconnect(self, client, userdata, rc):
        print(f"⚠️ Disconnected from ThingsBoard (code: {rc})")
        self.connected = False
    
    def connect(self):
        """Connect to ThingsBoard MQTT broker"""
        if not self.enabled:
            return False
            
        try:
            print(f"🔗 Connecting to ThingsBoard at {TB_HOST}:{TB_PORT}")
            self.client.connect(TB_HOST, TB_PORT, 60)
            self.client.loop_start()
            
            # Wait for connection
            timeout = 5
            start_time = time.time()
            while not self.connected and (time.time() - start_time) < timeout:
                time.sleep(0.1)
            
            return self.connected
        except Exception as e:
            print(f"❌ Failed to connect to ThingsBoard: {e}")
            return False
    
    def publish_nte_data(self, nte_result: Dict[str, Any], baby_id: str):
        """Publish NTE recommendation data to ThingsBoard"""
        if not self.enabled:
            return False
        
        # Reconnect if not connected
        if not self.connected:
            print("🔄 Not connected to ThingsBoard, attempting to reconnect...")
            if not self.connect():
                print("❌ Failed to reconnect to ThingsBoard")
                return False
        
        try:
            # Prepare telemetry data
            telemetry = {
                'nte_baby_id': baby_id,
                'nte_age_hours': round(nte_result.get('age_hours', 0), 2),
                'nte_weight_g': nte_result.get('weight_g', 0),
                'nte_range_min': nte_result.get('nte_range', [0, 0])[0] if nte_result.get('nte_range') else 0,
                'nte_range_max': nte_result.get('nte_range', [0, 0])[1] if nte_result.get('nte_range') else 0,
                'nte_advice_count': len(nte_result.get('advice', [])),
                'nte_timestamp': int(time.time() * 1000),
            }
            
            # Add severity counts
            advice_list = nte_result.get('advice', [])
            critical_count = sum(1 for a in advice_list if a.get('severity') == 'critical')
            warning_count = sum(1 for a in advice_list if a.get('severity') == 'warning')
            info_count = sum(1 for a in advice_list if a.get('severity') == 'info')
            
            telemetry['nte_critical_count'] = critical_count
            telemetry['nte_warning_count'] = warning_count
            telemetry['nte_info_count'] = info_count
            
            # Add latest advice messages
            if advice_list:
                telemetry['nte_latest_advice'] = advice_list[0].get('message', '')
                if len(advice_list) > 1:
                    telemetry['nte_latest_detail'] = advice_list[0].get('detail', '')
            
            payload = json.dumps(telemetry)
            result = self.client.publish(self.telemetry_topic, payload, qos=1)
            result.wait_for_publish()
            
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                print(f"✅ Published NTE data to ThingsBoard for baby {baby_id}")
                return True
            else:
                print(f"❌ Failed to publish NTE data (error code: {result.rc})")
                return False
                
        except Exception as e:
            print(f"❌ Error publishing NTE data: {e}")
            return False
    
    def disconnect(self):
        """Disconnect from ThingsBoard"""
        if self.enabled and self.connected:
            self.client.loop_stop()
            self.client.disconnect()
            print("👋 Disconnected from ThingsBoard")

# Initialize ThingsBoard client
tb_client = None
if ACCESS_TOKEN and MQTT_AVAILABLE:
    tb_client = ThingsBoardClient()

# Baby Data Management Functions
def load_baby_data() -> Dict[str, Any]:
    """Load baby data from JSON file"""
    if os.path.exists(BABY_DATA_FILE):
        try:
            with open(BABY_DATA_FILE, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"⚠️ Error loading baby data: {e}")
    return {}

def save_baby_data(data: Dict[str, Any]):
    """Save baby data to JSON file"""
    try:
        with open(BABY_DATA_FILE, 'w') as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        print(f"❌ Error saving baby data: {e}")

def calculate_age_hours(birth_date: str, birth_time: str) -> float:
    """Calculate age in hours from birth date and time"""
    try:
        birth_datetime_str = f"{birth_date} {birth_time}"
        birth_datetime = datetime.strptime(birth_datetime_str, "%Y-%m-%d %H:%M")
        current_datetime = datetime.now()
        age_delta = current_datetime - birth_datetime
        age_hours = age_delta.total_seconds() / 3600
        return max(0, age_hours)  # Ensure non-negative
    except Exception as e:
        raise ValueError(f"Invalid date/time format: {e}")

# API Endpoints

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "service": "NTE Recommendation Engine",
        "version": "1.0.0",
        "status": "running",
        "thingsboard_enabled": tb_client is not None and tb_client.enabled,
        "thingsboard_connected": tb_client.connected if tb_client else False,
        "endpoints": {
            "register": "POST /baby/register - Register a new baby",
            "update": "PUT /baby/{baby_id} - Update baby information",
            "list": "GET /baby/list - List all registered babies",
            "get": "GET /baby/{baby_id} - Get baby details",
            "recommend": "POST /recommendations - Get NTE recommendations",
            "health": "GET /health - Service health check"
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    babies = load_baby_data()
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "registered_babies": len(babies),
        "thingsboard_enabled": tb_client is not None and tb_client.enabled,
        "thingsboard_connected": tb_client.connected if tb_client else False,
        "default_air_temp": DEFAULT_AIR_TEMP
    }

@app.post("/baby/register")
async def register_baby(baby: BabyRegistration):
    """Register a new baby in the incubator"""
    babies = load_baby_data()
    
    # Check if baby already exists
    if baby.baby_id in babies:
        raise HTTPException(status_code=400, detail=f"Baby {baby.baby_id} is already registered")
    
    # Validate and calculate age
    try:
        age_hours = calculate_age_hours(baby.birth_date, baby.birth_time)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    # Store baby data
    baby_data = {
        "baby_id": baby.baby_id,
        "name": baby.name,
        "birth_date": baby.birth_date,
        "birth_time": baby.birth_time,
        "weight_g": baby.weight_g,
        "registered_at": datetime.now().isoformat(),
        "last_updated": datetime.now().isoformat()
    }
    
    babies[baby.baby_id] = baby_data
    save_baby_data(babies)
    
    return {
        "status": "success",
        "message": f"Baby {baby.baby_id} registered successfully",
        "data": baby_data,
        "current_age_hours": round(age_hours, 2)
    }

@app.put("/baby/{baby_id}")
async def update_baby(baby_id: str, update: BabyUpdate):
    """Update baby information (weight, vitals)"""
    babies = load_baby_data()
    
    if baby_id not in babies:
        raise HTTPException(status_code=404, detail=f"Baby {baby_id} not found")
    
    baby_data = babies[baby_id]
    
    # Update fields
    if update.weight_g is not None:
        baby_data['weight_g'] = update.weight_g
    
    if update.skin_temp is not None:
        baby_data['last_skin_temp'] = update.skin_temp
    
    if update.humidity is not None:
        baby_data['last_humidity'] = update.humidity
    
    baby_data['last_updated'] = datetime.now().isoformat()
    
    babies[baby_id] = baby_data
    save_baby_data(babies)
    
    return {
        "status": "success",
        "message": f"Baby {baby_id} updated successfully",
        "data": baby_data
    }

@app.get("/baby/list")
async def list_babies():
    """List all registered babies"""
    babies = load_baby_data()
    
    # Calculate current ages
    baby_list = []
    for baby_id, baby_data in babies.items():
        try:
            age_hours = calculate_age_hours(baby_data['birth_date'], baby_data['birth_time'])
            baby_info = {
                **baby_data,
                "current_age_hours": round(age_hours, 2),
                "age_days": round(age_hours / 24, 1)
            }
            baby_list.append(baby_info)
        except Exception as e:
            print(f"⚠️ Error calculating age for {baby_id}: {e}")
            baby_list.append(baby_data)
    
    return {
        "status": "success",
        "count": len(baby_list),
        "babies": baby_list
    }

@app.get("/baby/{baby_id}")
async def get_baby(baby_id: str):
    """Get baby details"""
    babies = load_baby_data()
    
    if baby_id not in babies:
        raise HTTPException(status_code=404, detail=f"Baby {baby_id} not found")
    
    baby_data = babies[baby_id]
    
    try:
        age_hours = calculate_age_hours(baby_data['birth_date'], baby_data['birth_time'])
        baby_data['current_age_hours'] = round(age_hours, 2)
        baby_data['age_days'] = round(age_hours / 24, 1)
    except Exception as e:
        print(f"⚠️ Error calculating age: {e}")
    
    return {
        "status": "success",
        "data": baby_data
    }

@app.get("/api/baby/current")
async def get_current_baby():
    """Get the most recently registered baby (for single incubator setup)"""
    babies = load_baby_data()
    
    if not babies:
        return {
            "status": "success",
            "baby": None,
            "message": "No babies registered"
        }
    
    # Get the most recently registered baby (last in the dictionary)
    baby_id = list(babies.keys())[-1]
    baby_data = babies[baby_id]
    
    try:
        age_hours = calculate_age_hours(baby_data['birth_date'], baby_data['birth_time'])
        baby_data['age_hours'] = round(age_hours, 2)
        baby_data['age_days'] = round(age_hours / 24, 1)
    except Exception as e:
        print(f"⚠️ Error calculating age: {e}")
    
    return {
        "status": "success",
        "baby": baby_data
    }

@app.delete("/baby/{baby_id}")
async def delete_baby(baby_id: str):
    """Remove a baby from the system"""
    babies = load_baby_data()
    
    if baby_id not in babies:
        raise HTTPException(status_code=404, detail=f"Baby {baby_id} not found")
    
    deleted_baby = babies.pop(baby_id)
    save_baby_data(babies)
    
    return {
        "status": "success",
        "message": f"Baby {baby_id} removed successfully",
        "data": deleted_baby
    }

@app.post("/recommendations")
async def get_recommendations(request: NTERequest):
    """Get NTE recommendations for a baby"""
    babies = load_baby_data()
    
    if request.baby_id not in babies:
        raise HTTPException(status_code=404, detail=f"Baby {request.baby_id} not found. Please register first.")
    
    baby_data = babies[request.baby_id]
    
    # Calculate current age
    try:
        age_hours = calculate_age_hours(baby_data['birth_date'], baby_data['birth_time'])
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error calculating age: {e}")
    
    # Determine air_temp: use override from request, or fetch from LCD, or use default
    if request.air_temp is not None:
        air_temp = request.air_temp
        print(f"📝 Using air_temp from request: {air_temp}°C")
    else:
        # Try to fetch from LCD reading server
        fetched_temp = fetch_air_temp_from_lcd()
        if fetched_temp is not None:
            air_temp = fetched_temp
            print(f"🌡️ Using air_temp from LCD: {air_temp}°C")
        else:
            air_temp = DEFAULT_AIR_TEMP
            print(f"⚠️ Using default air_temp: {air_temp}°C")
    
    # Prepare readings
    readings = {
        "air_temp": air_temp,
        "skin_temp": request.skin_temp,
        "humidity": request.humidity
    }
    
    # Get recommendations
    result = recommend(
        age_hours=age_hours,
        weight_g=baby_data['weight_g'],
        readings=readings
    )
    
    # Add baby info to result
    result['baby_id'] = request.baby_id
    result['baby_name'] = baby_data.get('name', 'Unknown')
    result['timestamp'] = datetime.now().isoformat()
    
    # Publish to ThingsBoard
    if tb_client and tb_client.enabled:
        try:
            tb_client.publish_nte_data(result, request.baby_id)
        except Exception as e:
            print(f"⚠️ Failed to publish to ThingsBoard: {e}")
    
    return {
        "status": "success",
        "data": result
    }

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    print("🚀 Starting NTE Recommendation Engine Server...")
    print(f"📂 Baby data file: {BABY_DATA_FILE}")
    print(f"🌡️ Default air temperature: {DEFAULT_AIR_TEMP}°C")
    
    # Initialize ThingsBoard connection
    if tb_client and tb_client.enabled:
        print("🔗 Initializing ThingsBoard connection...")
        
        def connect_tb():
            if tb_client.connect():
                print("✅ ThingsBoard connected successfully")
            else:
                print("⚠️ ThingsBoard connection failed, will retry during publishing")
        
        # Connect in background thread
        threading.Thread(target=connect_tb, daemon=True).start()
    else:
        print("⚠️ ThingsBoard publishing disabled")
    
    print("✅ NTE Server ready on http://localhost:8886")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    print("👋 Shutting down NTE Recommendation Engine Server...")
    if tb_client:
        tb_client.disconnect()

if __name__ == "__main__":
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8886,
        log_level="info"
    )
