# Weight Update API - Pi Server Implementation

This document describes the API endpoint you need to add to your Pi server to handle weight updates and sync them to ThingsBoard.

## API Endpoint

### Update Baby Weight

**Endpoint:** `PUT /api/baby/{baby_id}/weight`

**Request Body:**

```json
{
  "weight_g": 2250
}
```

**Response:**

```json
{
  "success": true,
  "baby_id": "BABY-104",
  "weight_g": 2250,
  "updated_at": "2025-11-03T10:30:00Z",
  "thingsboard_synced": true
}
```

## Python Flask Implementation

Add this to your Pi server (e.g., `simple_health_server.py` or create a new `baby_weight_server.py`):

```python
from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import json
from datetime import datetime
import os

app = Flask(__name__)
CORS(app)  # Enable CORS for React dashboard

# ThingsBoard Configuration
THINGSBOARD_HOST = os.getenv('THINGSBOARD_HOST', 'thingsboard.cloud')
DEVICE_TOKEN = os.getenv('DEVICE_TOKEN', 'your-device-access-token')

# In-memory storage (replace with your database)
baby_data = {}

@app.route('/api/baby/<baby_id>/weight', methods=['PUT'])
def update_baby_weight(baby_id):
    """
    Update baby weight and sync to ThingsBoard
    """
    try:
        data = request.get_json()
        weight_g = data.get('weight_g')

        if weight_g is None or weight_g <= 0:
            return jsonify({
                'success': False,
                'error': 'Invalid weight value'
            }), 400

        # Update local storage
        if baby_id not in baby_data:
            baby_data[baby_id] = {}

        baby_data[baby_id]['weight_g'] = weight_g
        baby_data[baby_id]['updated_at'] = datetime.utcnow().isoformat()

        # Sync to ThingsBoard
        thingsboard_synced = send_to_thingsboard(baby_id, weight_g)

        return jsonify({
            'success': True,
            'baby_id': baby_id,
            'weight_g': weight_g,
            'updated_at': baby_data[baby_id]['updated_at'],
            'thingsboard_synced': thingsboard_synced
        }), 200

    except Exception as e:
        print(f"Error updating weight: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

def send_to_thingsboard(baby_id, weight_g):
    """
    Send weight telemetry to ThingsBoard
    """
    try:
        url = f'http://{THINGSBOARD_HOST}/api/v1/{DEVICE_TOKEN}/telemetry'

        telemetry_data = {
            'baby_weight_g': weight_g,
            'baby_id': baby_id,
            'timestamp': int(datetime.utcnow().timestamp() * 1000)
        }

        response = requests.post(
            url,
            json=telemetry_data,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )

        if response.status_code == 200:
            print(f"Weight {weight_g}g for {baby_id} synced to ThingsBoard")
            return True
        else:
            print(f"ThingsBoard sync failed: {response.status_code} - {response.text}")
            return False

    except Exception as e:
        print(f"Error syncing to ThingsBoard: {e}")
        return False

@app.route('/api/baby/<baby_id>', methods=['GET'])
def get_baby_data(baby_id):
    """
    Get baby data including current weight
    """
    if baby_id in baby_data:
        return jsonify({
            'success': True,
            'baby_id': baby_id,
            **baby_data[baby_id]
        }), 200
    else:
        return jsonify({
            'success': False,
            'error': 'Baby not found'
        }), 404

if __name__ == '__main__':
    # Run on port 8886 to match your existing setup
    app.run(host='0.0.0.0', port=8886, debug=True)
```

## Alternative: Add to Existing Flask Server

If you already have a Flask server running, add this route to it:

```python
@app.route('/api/baby/<baby_id>/weight', methods=['PUT'])
def update_baby_weight(baby_id):
    data = request.get_json()
    weight_g = data.get('weight_g')

    # Your existing baby data update logic here
    # ...

    # Then sync to ThingsBoard
    telemetry_url = f'http://thingsboard.cloud/api/v1/{DEVICE_TOKEN}/telemetry'
    requests.post(telemetry_url, json={'baby_weight_g': weight_g})

    return jsonify({'success': True, 'weight_g': weight_g})
```

## Data Pipeline

```
┌─────────────────┐
│  React Dashboard│
│  (Clinical)     │
└────────┬────────┘
         │ PUT /api/baby/{id}/weight
         │ { "weight_g": 2250 }
         ▼
┌─────────────────┐
│   Pi Server     │
│  (Flask/Python) │
│   Port 8886     │
└────────┬────────┘
         │ POST /api/v1/{token}/telemetry
         │ { "baby_weight_g": 2250 }
         ▼
┌─────────────────┐
│  ThingsBoard    │
│     Cloud       │
│  (IoT Platform) │
└─────────────────┘
```

## Environment Variables

Set these on your Pi:

```bash
export THINGSBOARD_HOST="thingsboard.cloud"
export DEVICE_TOKEN="your-device-access-token-here"
```

## Testing

Test the endpoint with curl:

```bash
curl -X PUT http://100.89.162.22:8886/api/baby/BABY-104/weight \
  -H "Content-Type: application/json" \
  -d '{"weight_g": 2250}'
```

## Notes

1. The dashboard will call this API when the clinician updates the weight
2. The Pi server updates its local database
3. The Pi server immediately sends telemetry to ThingsBoard
4. ThingsBoard stores the weight as a time-series data point
5. The dashboard can then query ThingsBoard for historical weight trends

## Security (Production)

For production, add:

- API authentication (JWT tokens)
- Rate limiting
- Input validation
- HTTPS/TLS encryption
- Database persistence (SQLite/PostgreSQL)
