# GCP Architecture Documentation - Neonatal Incubator Monitoring System

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Component Details](#component-details)
4. [Data Flow](#data-flow)
5. [Network Architecture](#network-architecture)
6. [Authentication & Authorization](#authentication--authorization)
7. [Deployment Architecture](#deployment-architecture)
8. [Edge Device Communication](#edge-device-communication)
9. [API Endpoints Reference](#api-endpoints-reference)
10. [Security & Access Control](#security--access-control)

---

## System Overview

The Neonatal Incubator Monitoring System is a cloud-based IoT solution that monitors incubators in real-time using:

- **Edge Device**: Raspberry Pi with 8 microservices
- **Cloud Platform**: Google Cloud Platform (GCP)
- **IoT Platform**: ThingsBoard Cloud
- **Network Bridge**: Tailscale VPN mesh network
- **Frontend**: React dashboard hosted on Cloud Run
- **Backends**: Python Flask services for admin and parent portals

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          INTERNET / PUBLIC ACCESS                                │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ HTTPS
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        GOOGLE CLOUD PLATFORM (us-central1)                       │
│                                                                                   │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │               Cloud Run Services (Serverless Containers)                │    │
│  │                                                                          │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │    │
│  │  │  Dashboard Frontend (incubator-dashboard)                         │  │    │
│  │  │  • React SPA with nginx                                           │  │    │
│  │  │  • Port: 80                                                       │  │    │
│  │  │  • URL: incubator-dashboard-571778410429.us-central1.run.app    │  │    │
│  │  │  • Routes:                                                        │  │    │
│  │  │    - /api/pi/* → Tailscale VM Proxy                             │  │    │
│  │  │    - /api/auth/* → Admin Backend                                │  │    │
│  │  │    - /api/admin/* → Admin Backend                               │  │    │
│  │  │    - /api/parent/* → Parent Backend                             │  │    │
│  │  └──────────────────────────────────────────────────────────────────┘  │    │
│  │                                                                          │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │    │
│  │  │  Admin Backend (incubator-admin-backend)                          │  │    │
│  │  │  • Python Flask + SQLite                                          │  │    │
│  │  │  • Port: 5056                                                     │  │    │
│  │  │  • URL: incubator-admin-backend-571778410429.us-central1.run.app│  │    │
│  │  │  • Functions:                                                     │  │    │
│  │  │    - Admin authentication (JWT)                                  │  │    │
│  │  │    - Admin user management                                       │  │    │
│  │  │    - Notifications management                                    │  │    │
│  │  └──────────────────────────────────────────────────────────────────┘  │    │
│  │                                                                          │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │    │
│  │  │  Parent Backend (incubator-parent-backend)                        │  │    │
│  │  │  • Python Flask + SQLite                                          │  │    │
│  │  │  • Port: 5000                                                     │  │    │
│  │  │  • URL: incubator-parent-backend-571778410429.us-central1.run.app│  │    │
│  │  │  • Functions:                                                     │  │    │
│  │  │    - Parent authentication (OTP)                                 │  │    │
│  │  │    - Parent-clinician messaging                                  │  │    │
│  │  │    - Baby information access                                     │  │    │
│  │  └──────────────────────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                   │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │           Compute Engine VM (Tailscale Proxy)                          │    │
│  │                                                                          │    │
│  │  Instance: tailscale-proxy-vm                                           │    │
│  │  Zone: us-central1-a                                                    │    │
│  │  Type: e2-medium (2 vCPU, 4GB RAM)                                     │    │
│  │  External IP: 34.60.196.25                                              │    │
│  │  Tailscale IP: 100.114.45.10                                            │    │
│  │                                                                          │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │    │
│  │  │  nginx Reverse Proxy                                              │  │    │
│  │  │  Config: /etc/nginx/sites-available/nginx-pi-proxy.conf          │  │    │
│  │  │                                                                    │  │    │
│  │  │  Routes (all proxy to Pi via Tailscale):                         │  │    │
│  │  │  • /api/pi:9000/* → http://100.89.162.22:9000  (Health)         │  │    │
│  │  │  • /api/pi:9001/* → http://100.89.162.22:9001  (LCD)            │  │    │
│  │  │  • /api/pi/camera/* → http://100.89.162.22:8080 (Infant cam)    │  │    │
│  │  │  • /api/pi/lcd-camera/* → http://100.89.162.22:8081 (LCD cam)   │  │    │
│  │  │  • /api/pi:8886/* → http://100.89.162.22:8886  (NTE)            │  │    │
│  │  │  • /api/pi/jaundice/* → http://100.89.162.22:8887 (Jaundice)    │  │    │
│  │  │  • /api/pi:8888/* → http://100.89.162.22:8888  (Cry detect)     │  │    │
│  │  │  • /api/pi/snapshot/* → http://100.89.162.22:8090 (Test dash)   │  │    │
│  │  └──────────────────────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                   │
└───────────────────────────────────────────────┬───────────────────────────────────┘
                                                │
                                                │ Tailscale VPN
                                                │ (100.x.x.x mesh network)
                                                │
┌───────────────────────────────────────────────┴───────────────────────────────────┐
│                        TAILSCALE MESH NETWORK                                      │
│  • Encrypted WireGuard tunnels                                                     │
│  • Direct peer-to-peer when possible                                              │
│  • DERP relay when NAT traversal fails                                            │
│  • Latency: ~1000ms (GCP us-central1 ↔ Pi)                                       │
└───────────────────────────────────────────────┬───────────────────────────────────┘
                                                │
                                                │
┌───────────────────────────────────────────────┴───────────────────────────────────┐
│                    EDGE DEVICE (Raspberry Pi 4)                                    │
│  Tailscale IP: 100.89.162.22                                                       │
│  Local Network: Private (behind router/NAT)                                        │
│                                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────┐    │
│  │                    8 Microservices Running                                │    │
│  │                                                                            │    │
│  │  1. Health Monitor (Port 9000)                                            │    │
│  │     • CPU, RAM, temperature monitoring                                    │    │
│  │     • System shutdown/reboot commands                                     │    │
│  │     • GET /health, POST /shutdown, POST /reboot                          │    │
│  │                                                                            │    │
│  │  2. LCD Reading Server (Port 9001)                                        │    │
│  │     • Incubator display OCR (YOLO + Tesseract)                           │    │
│  │     • Heart rate, SpO2, skin temperature                                  │    │
│  │     • GET /readings                                                       │    │
│  │                                                                            │    │
│  │  3. Infant Camera Stream (Port 8080)                                      │    │
│  │     • MJPEG video stream                                                  │    │
│  │     • GET /?action=stream                                                 │    │
│  │                                                                            │    │
│  │  4. LCD Camera Stream (Port 8081)                                         │    │
│  │     • MJPEG video stream of incubator display                            │    │
│  │     • GET /?action=stream                                                 │    │
│  │                                                                            │    │
│  │  5. NTE (Neutral Thermal Environment) Server (Port 8886)                 │    │
│  │     • Thermal zone calculations                                           │    │
│  │     • Baby registration and management                                    │    │
│  │     • POST /baby/register, GET /baby/list                                │    │
│  │     • GET /baby/{id}, DELETE /baby/{id}                                  │    │
│  │     • POST /recommendations                                               │    │
│  │                                                                            │    │
│  │  6. Jaundice Detection (Port 8887)                                        │    │
│  │     • MobileNetV3 ONNX model                                             │    │
│  │     • POST /jaundice/detect, GET /jaundice/latest                        │    │
│  │                                                                            │    │
│  │  7. Cry Detection (Port 8888)                                             │    │
│  │     • Audio analysis and classification                                   │    │
│  │     • Recording and playback                                              │    │
│  │     • GET /cry/status, POST /cry/start, POST /cry/stop                   │    │
│  │                                                                            │    │
│  │  8. Test/Snapshot Dashboard (Port 8090)                                   │    │
│  │     • HTML monitoring dashboard                                           │    │
│  │     • Displays all sensor data in one page                               │    │
│  │     • Accessible via /api/pi/snapshot/                                   │    │
│  └──────────────────────────────────────────────────────────────────────────┘    │
│                                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────┐    │
│  │              ThingsBoard MQTT Client (Python)                             │    │
│  │  • Publishes telemetry every 1 second                                     │    │
│  │  • Fetches data from local services                                       │    │
│  │  • Device Token: 2ztut7be6ppooyiueorb                                     │    │
│  └──────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────┘
                                                │
                                                │ MQTT over TLS (Port 1883/8883)
                                                ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    THINGSBOARD CLOUD (thingsboard.cloud)                         │
│                                                                                   │
│  Device: INC-001                                                                  │
│  Device ID: 1cb00cb0-acf5-11f0-b4af-b334f2239a02                                │
│                                                                                   │
│  Telemetry Keys (updated every 1 second):                                        │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │ Health Metrics:          │ Vitals:              │ NTE Data:               │  │
│  │ • cpu_percent            │ • heart_rate         │ • nte_baby_id          │  │
│  │ • memory_percent         │ • spo2               │ • nte_age_hours        │  │
│  │ • temperature            │ • skin_temp          │ • nte_weight_g         │  │
│  │ • disk_usage             │ • lcd_timestamp      │ • nte_range_min        │  │
│  │                          │                      │ • nte_range_max        │  │
│  │ Detection:               │ Environment:         │ • nte_critical_count   │  │
│  │ • cry_detected           │ • air_temperature    │ • nte_warning_count    │  │
│  │ • cry_timestamp          │ • humidity           │ • nte_info_count       │  │
│  │ • jaundice_risk          │ • incubator_mode     │ • nte_latest_advice    │  │
│  │ • jaundice_timestamp     │                      │ • nte_latest_detail    │  │
│  │                          │                      │ • nte_timestamp        │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                   │
│  REST API: https://thingsboard.cloud/api                                         │
│  • Authentication: JWT token (username/password)                                  │
│  • Dashboard accesses telemetry via REST API                                      │
│  • 10-30x faster than direct Pi polling                                          │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. Cloud Run Services (GCP Serverless)

#### Dashboard Frontend

- **Service Name**: `incubator-dashboard`
- **Image**: `gcr.io/neonatal-incubator-monitoring/incubator-dashboard:latest`
- **Technology**: React 18 + nginx
- **Current Revision**: `incubator-dashboard-00022-525`
- **Resources**: 1 CPU, 512MB RAM
- **Auto-scaling**: 0-10 instances
- **Startup**: nginx on port 80

**nginx Configuration**:

```nginx
# Routes traffic to appropriate backends
location /api/pi { → Tailscale VM (34.60.196.25)
location /api/auth/ { → Admin Backend
location /api/admin/ { → Admin Backend
location /api/parent/ { → Parent Backend
location / { → Serve React SPA
```

**Environment Variables**:

```
NODE_ENV=production
REACT_APP_ADMIN_API_URL=https://incubator-admin-backend-571778410429.us-central1.run.app
REACT_APP_PARENT_API_URL=https://incubator-parent-backend-571778410429.us-central1.run.app
REACT_APP_TB_API_URL=https://thingsboard.cloud/api
REACT_APP_TB_HOST=thingsboard.cloud
REACT_APP_TB_USERNAME=sahanrashmikaslk@gmail.com
REACT_APP_TB_PASSWORD=user1@demo
REACT_APP_DEVICE_ID=INC-001
REACT_APP_DEVICE_TOKEN=2ztut7be6ppooyiueorb
REACT_APP_PI_HOST=100.89.162.22
REACT_APP_CAMERA_PORT=8080
```

#### Admin Backend

- **Service Name**: `incubator-admin-backend`
- **Image**: Python Flask application
- **Port**: 5056
- **Database**: SQLite (persistent with Cloud Storage mount)
- **Authentication**: JWT tokens

**API Endpoints**:

```
POST /api/auth/login              - Admin login
POST /api/auth/verify-setup-token - Verify setup token
POST /api/auth/setup-password     - First-time password setup
GET  /api/auth/verify             - Verify current session

POST /api/admin/create            - Create new admin
GET  /api/admin/list              - List all admins
GET  /api/admin/:id               - Get admin details
PUT  /api/admin/:id               - Update admin
DELETE /api/admin/:id             - Delete admin
GET  /api/admin/me                - Get current admin info

GET  /api/admin/notifications     - List notifications
POST /api/admin/notifications     - Create notification
POST /api/admin/notifications/mark-read - Mark as read
```

#### Parent Backend

- **Service Name**: `incubator-parent-backend`
- **Port**: 5000
- **Database**: SQLite
- **Authentication**: OTP (One-Time Password)

**API Endpoints**:

```
POST /api/parent/login            - Parent OTP login
GET  /api/parent/baby             - Get baby information
GET  /api/parent/messages         - Get messages
POST /api/parent/messages         - Send message
PUT  /api/parent/messages/:id/read - Mark message as read
```

### 2. Tailscale Proxy VM (Compute Engine)

**VM Specifications**:

- **Name**: `tailscale-proxy-vm`
- **Zone**: `us-central1-a`
- **Machine Type**: `e2-medium` (2 vCPU, 4GB RAM)
- **OS**: Ubuntu 22.04 LTS
- **External IP**: `34.60.196.25` (static)
- **Tailscale IP**: `100.114.45.10`
- **Role**: Bridge between Cloud Run and Raspberry Pi

**Installed Software**:

```bash
# Tailscale VPN client
sudo tailscale up --advertise-routes=100.89.162.22/32

# nginx reverse proxy
sudo apt install nginx

# Configuration
/etc/nginx/sites-available/nginx-pi-proxy.conf
```

**nginx Configuration Highlights**:

```nginx
# Example route configuration
location /api/pi:9000/ {
    proxy_pass http://100.89.162.22:9000/;
    proxy_connect_timeout 30s;
    proxy_read_timeout 120s;
    proxy_send_timeout 120s;

    # WebSocket support for camera streams
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
}

# Camera stream with buffering disabled
location /api/pi/camera/ {
    proxy_pass http://100.89.162.22:8080/;
    proxy_buffering off;
    proxy_cache off;
}
```

### 3. Raspberry Pi Edge Device

**Hardware**:

- Raspberry Pi 4 Model B (4GB RAM)
- 2x USB cameras (infant + LCD display)
- Microphone for cry detection
- Network: WiFi/Ethernet

**Software Stack**:

```
OS: Raspberry Pi OS (Debian-based)
Python: 3.9+
Services: systemd managed

Installed Libraries:
- OpenCV (camera processing)
- Tesseract OCR (LCD reading)
- YOLO (object detection)
- ONNX Runtime (ML inference)
- PyAudio (audio capture)
- Flask (web servers)
- paho-mqtt (ThingsBoard client)
```

**Service Architecture**:

```
All services run as systemd units:
- health_monitor.service
- lcd_reading.service
- camera_server.service
- lcd_camera.service
- nte_server.service
- jaundice_detection.service
- cry_detector.service
- snapshot_dashboard.service
- thingsboard_client.service
```

### 4. ThingsBoard Cloud

**Configuration**:

- **Tenant**: Custom tenant
- **Device Profile**: Default
- **Device Type**: INC-001
- **Transport**: MQTT
- **Data Format**: JSON

**MQTT Client Code (on Pi)**:

```python
import paho.mqtt.client as mqtt

client = mqtt.Client()
client.username_pw_set('DEVICE_TOKEN')
client.connect('thingsboard.cloud', 1883)

# Publish telemetry
telemetry = {
    'heart_rate': 120,
    'spo2': 98,
    'temperature': 36.5
}
client.publish('v1/devices/me/telemetry', json.dumps(telemetry))
```

---

## Data Flow

### Live Camera Streaming

```
┌─────────────┐     HTTPS      ┌──────────────┐    Tailscale    ┌─────────────┐
│   Browser   │ ───────────────>│  Dashboard   │ ──────────────> │  Proxy VM   │
│             │                 │  (Cloud Run) │                 │ (nginx)     │
└─────────────┘                 └──────────────┘                 └─────────────┘
                                                                         │
                                                          Tailscale VPN  │
                                                          (encrypted)    │
                                                                         ▼
                                                                 ┌───────────────┐
                                                                 │  Raspberry Pi │
                                                                 │  Port 8080    │
                                                                 │  (MJPEG)      │
                                                                 └───────────────┘

Flow:
1. Browser requests: GET /api/pi/camera/?action=stream
2. Dashboard nginx proxies to: http://34.60.196.25/api/pi/camera/?action=stream
3. Proxy VM nginx proxies to: http://100.89.162.22:8080/?action=stream
4. Pi streams MJPEG frames continuously
5. Frames flow back through the chain to browser
```

### Control Commands (Admin Dashboard)

```
┌──────────────┐                ┌──────────────┐               ┌─────────────┐
│ Admin clicks │                │  Dashboard   │               │  Proxy VM   │
│  "Shutdown"  │ ──────────────>│  (Cloud Run) │ ────────────> │  (nginx)    │
└──────────────┘   POST /api/   └──────────────┘   Tailscale   └─────────────┘
                   pi:9000/                         VPN                │
                   shutdown                                            │
                                                                        ▼
                                                                ┌───────────────┐
                                                                │ Raspberry Pi  │
                                                                │ Health Server │
                                                                │ Port 9000     │
                                                                └───────────────┘
                                                                        │
                                                                        │ Execute
                                                                        ▼
                                                                  sudo shutdown

Flow:
1. Admin clicks shutdown button
2. React calls: POST /api/pi:9000/shutdown
3. Dashboard nginx → Proxy VM nginx → Pi health server
4. Pi executes: os.system('sudo shutdown -h now')
5. Response flows back: {"status": "shutting down"}
```

### ThingsBoard Data Sync

```
┌─────────────┐    Every 1s     ┌──────────────┐    MQTT/TLS    ┌──────────────┐
│ Pi Services │ ───────────────>│ ThingsBoard  │ ──────────────>│ ThingsBoard  │
│ (8 servers) │                 │ MQTT Client  │                │ Cloud        │
└─────────────┘                 │ (Python)     │                └──────────────┘
                                └──────────────┘                        │
                                                                        │
                                                      REST API          │
                                                      (JWT auth)        │
                                                                        │
┌──────────────┐    HTTPS       ┌──────────────┐                      │
│   Browser    │ ───────────────>│  Dashboard   │ ─────────────────────┘
│              │                 │ DataContext  │   GET /api/plugins/
└──────────────┘                 │ (React)      │   telemetry/DEVICE/
                                └──────────────┘   values/timeseries

Flow:
1. Pi collects data from all 8 services (heart rate, SpO2, temp, etc.)
2. ThingsBoard client publishes to: v1/devices/me/telemetry
3. ThingsBoard stores in time-series database
4. Dashboard polls ThingsBoard REST API every 1 second
5. Data displayed in real-time widgets (10-30x faster than direct Pi polling)
```

### Baby Registration (NTE Service)

```
┌──────────────┐    Fill form    ┌──────────────┐    POST        ┌─────────────┐
│   Clinician  │ ───────────────>│  Dashboard   │ ──────────────>│  Proxy VM   │
│              │                 │  Clinical    │                │  (nginx)    │
└──────────────┘                 │  Dashboard   │                └─────────────┘
                                └──────────────┘                        │
                                                          Tailscale     │
                                                          VPN           │
                                                                        ▼
                                                                ┌───────────────┐
                                                                │ Raspberry Pi  │
                                                                │ NTE Server    │
                                                                │ Port 8886     │
                                                                └───────────────┘
                                                                        │
                                                                        │ Calculate
                                                                        │ thermal zone
                                                                        ▼
                                                                 ┌──────────────┐
                                                                 │ Save baby.db │
                                                                 │ (SQLite)     │
                                                                 └──────────────┘
                                                                        │
                                                                        │ Publish
                                                                        ▼
                                                                ┌───────────────┐
                                                                │ ThingsBoard   │
                                                                │ (MQTT)        │
                                                                └───────────────┘

Flow:
1. Clinician enters: baby_id, age_hours, weight_g
2. POST /api/pi:8886/baby/register
3. NTE server calculates thermal zone based on WHO guidelines
4. Saves to local SQLite database
5. Publishes to ThingsBoard:
   - nte_baby_id
   - nte_age_hours
   - nte_weight_g
   - nte_range_min, nte_range_max
   - nte_recommendations
6. Dashboard shows recommendations in real-time
```

---

## Network Architecture

### Tailscale VPN Mesh

**Configuration**:

```
Network: 100.64.0.0/10 (CGNAT range)
Protocol: WireGuard
Encryption: ChaCha20-Poly1305

Devices in mesh:
1. Proxy VM:      100.114.45.10  (GCP us-central1-a)
2. Raspberry Pi:  100.89.162.22  (Private network, NAT)

Connection Type: Direct (not using DERP relay)
Latency: ~1000ms (GCP ↔ Pi)
Throughput: ~10-20 Mbps (sufficient for MJPEG streams)
```

**Tailscale Setup Commands**:

On Proxy VM:

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale and advertise routes
sudo tailscale up --advertise-routes=100.89.162.22/32 --accept-routes

# Verify connection
tailscale status
```

On Raspberry Pi:

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connect to network
sudo tailscale up

# Check status
tailscale status
```

### Firewall Rules

**GCP Firewall** (Proxy VM):

```
Allow ingress:
- Source: 0.0.0.0/0 (internet)
- Ports: 80, 443 (HTTP/HTTPS)
- Target: tailscale-proxy-vm

Allow egress:
- Destination: 100.64.0.0/10 (Tailscale network)
- All ports
```

**Pi Local Firewall** (iptables):

```bash
# Allow from Tailscale network only
sudo iptables -A INPUT -s 100.0.0.0/8 -j ACCEPT

# Allow established connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Drop all other incoming
sudo iptables -A INPUT -j DROP
```

### Port Mapping Reference

| Service        | Pi Port | Proxy VM Route        | Dashboard Route       | Purpose                        |
| -------------- | ------- | --------------------- | --------------------- | ------------------------------ |
| Health Monitor | 9000    | /api/pi:9000/\*       | /api/pi:9000/\*       | System health, shutdown/reboot |
| LCD Reading    | 9001    | /api/pi:9001/\*       | /api/pi/lcd/\*        | OCR vitals from display        |
| Infant Camera  | 8080    | /api/pi/camera/\*     | /api/pi/camera/\*     | MJPEG video stream             |
| LCD Camera     | 8081    | /api/pi/lcd-camera/\* | /api/pi/lcd-camera/\* | Display monitoring             |
| NTE Server     | 8886    | /api/pi:8886/\*       | /api/pi:8886/\*       | Thermal calculations           |
| Jaundice       | 8887    | /api/pi/jaundice/\*   | /api/pi/jaundice/\*   | ML detection                   |
| Cry Detection  | 8888    | /api/pi:8888/\*       | /api/pi:8888/\*       | Audio analysis                 |
| Test Dashboard | 8090    | /api/pi/snapshot/\*   | /api/pi/snapshot/\*   | Debug interface                |

---

## Authentication & Authorization

### Admin Authentication Flow

```
┌──────────────┐                                    ┌─────────────────┐
│    Admin     │                                    │  Admin Backend  │
│   Browser    │                                    │  (Cloud Run)    │
└──────────────┘                                    └─────────────────┘
       │                                                      │
       │  1. POST /api/auth/login                           │
       │     {email, password}                              │
       │ ───────────────────────────────────────────────────>│
       │                                                      │
       │                                      2. Verify      │
       │                                      credentials    │
       │                                      (SQLite)       │
       │                                                      │
       │  3. {token: "JWT...", user: {...}}                 │
       │ <───────────────────────────────────────────────────│
       │                                                      │
       │  4. Store in localStorage                          │
       │                                                      │
       │  5. All subsequent requests                        │
       │     Authorization: Bearer JWT...                   │
       │ ───────────────────────────────────────────────────>│
       │                                                      │
       │                                      6. Verify JWT  │
       │                                      and check exp  │
       │                                                      │
       │  7. Response data                                   │
       │ <───────────────────────────────────────────────────│
```

**JWT Token Structure**:

```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "admin_id": "uuid-here",
    "email": "admin@example.com",
    "exp": 1699564800,
    "iat": 1699478400
  }
}
```

### Parent Authentication (OTP)

```
┌──────────────┐                                    ┌─────────────────┐
│   Parent     │                                    │ Parent Backend  │
│   Mobile     │                                    │  (Cloud Run)    │
└──────────────┘                                    └─────────────────┘
       │                                                      │
       │  1. POST /api/parent/request-otp                   │
       │     {phone_number}                                 │
       │ ───────────────────────────────────────────────────>│
       │                                                      │
       │                                      2. Generate    │
       │                                      6-digit OTP    │
       │                                      Send SMS       │
       │                                                      │
       │  3. {message: "OTP sent"}                          │
       │ <───────────────────────────────────────────────────│
       │                                                      │
       │  4. POST /api/parent/verify-otp                    │
       │     {phone_number, otp}                            │
       │ ───────────────────────────────────────────────────>│
       │                                                      │
       │                                      5. Verify OTP  │
       │                                      (5min expiry)  │
       │                                                      │
       │  6. {session_token: "...", baby_info: {...}}      │
       │ <───────────────────────────────────────────────────│
```

### ThingsBoard Authentication

```
┌──────────────┐                                    ┌─────────────────┐
│   Dashboard  │                                    │  ThingsBoard    │
│  DataContext │                                    │     Cloud       │
└──────────────┘                                    └─────────────────┘
       │                                                      │
       │  1. POST /api/auth/login                           │
       │     {username, password}                           │
       │ ───────────────────────────────────────────────────>│
       │                                                      │
       │  2. {token: "JWT...", refreshToken: "..."}         │
       │ <───────────────────────────────────────────────────│
       │                                                      │
       │  3. Store token in state                           │
       │                                                      │
       │  4. GET /api/plugins/telemetry/DEVICE/values/...   │
       │     X-Authorization: Bearer JWT...                 │
       │ ───────────────────────────────────────────────────>│
       │                                                      │
       │  5. {heart_rate: 120, spo2: 98, ...}              │
       │ <───────────────────────────────────────────────────│
       │                                                      │
       │  6. Auto-refresh every 1 second                    │
```

---

## Deployment Architecture

### Cloud Run Deployment Process

```bash
# Build Docker image locally
cd react_dashboard
docker build -t gcr.io/neonatal-incubator-monitoring/incubator-dashboard:latest .

# Push to Google Container Registry
docker push gcr.io/neonatal-incubator-monitoring/incubator-dashboard:latest

# Deploy to Cloud Run
gcloud run deploy incubator-dashboard \
  --image gcr.io/neonatal-incubator-monitoring/incubator-dashboard:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated

# Result: New revision created (e.g., 00022-525)
# All traffic automatically migrated to new revision
```

**Revision History**:

```
00022-525 (current) - Fixed auth endpoint routing
00021-sm9          - Added Pi proxy routing
00020-9g2          - Fixed nginx backend URLs
00019-zr8          - Failed (nginx config error)
...
00016-c5k          - NTE range display fix
00014-skr          - NTE timestamp fix
00013-mrc          - ThingsBoard integration
```

### Infrastructure as Code

**Terraform Configuration** (example):

```hcl
# Cloud Run service
resource "google_cloud_run_service" "dashboard" {
  name     = "incubator-dashboard"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "gcr.io/neonatal-incubator-monitoring/incubator-dashboard:latest"

        ports {
          container_port = 80
        }

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Allow public access
resource "google_cloud_run_service_iam_member" "public" {
  service  = google_cloud_run_service.dashboard.name
  location = google_cloud_run_service.dashboard.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Compute Engine VM for Tailscale proxy
resource "google_compute_instance" "tailscale_proxy" {
  name         = "tailscale-proxy-vm"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.static.address
    }
  }
}
```

### Continuous Deployment

**GitHub Actions Workflow**:

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches: [main]
    paths:
      - "react_dashboard/**"

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
        with:
          service_account_key: ${{ secrets.GCP_SA_KEY }}
          project_id: neonatal-incubator-monitoring

      - name: Configure Docker
        run: gcloud auth configure-docker gcr.io

      - name: Build Docker image
        run: |
          cd react_dashboard
          docker build -t gcr.io/neonatal-incubator-monitoring/incubator-dashboard:$GITHUB_SHA .
          docker tag gcr.io/neonatal-incubator-monitoring/incubator-dashboard:$GITHUB_SHA \
                     gcr.io/neonatal-incubator-monitoring/incubator-dashboard:latest

      - name: Push to GCR
        run: |
          docker push gcr.io/neonatal-incubator-monitoring/incubator-dashboard:$GITHUB_SHA
          docker push gcr.io/neonatal-incubator-monitoring/incubator-dashboard:latest

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy incubator-dashboard \
            --image gcr.io/neonatal-incubator-monitoring/incubator-dashboard:latest \
            --platform managed \
            --region us-central1 \
            --allow-unauthenticated
```

---

## Edge Device Communication

### Pi Service Management

All services managed by systemd:

```bash
# Health monitor service
[Unit]
Description=Incubator Health Monitor
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/monitoring
ExecStart=/usr/bin/python3 health_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target

# Commands
sudo systemctl start health_monitor
sudo systemctl stop health_monitor
sudo systemctl status health_monitor
sudo journalctl -u health_monitor -f
```

### Service Dependencies

```
┌─────────────────────────────────────────────────┐
│           Pi Service Dependency Graph           │
└─────────────────────────────────────────────────┘

thingsboard_client (top-level)
    │
    ├─> health_monitor (9000)
    ├─> lcd_reading (9001) ──> lcd_camera (8081)
    ├─> camera_server (8080)
    ├─> nte_server (8886)
    ├─> jaundice_detection (8887)
    ├─> cry_detector (8888) ──> microphone
    └─> snapshot_dashboard (8090)

Boot order:
1. Hardware services (cameras, audio)
2. Individual servers (9000-8888)
3. ThingsBoard MQTT client (publishes data)
4. Snapshot dashboard (aggregates all data)
```

### Data Collection Cycle

```python
# ThingsBoard client main loop
while True:
    telemetry = {}

    # Collect from all services
    try:
        health = requests.get('http://localhost:9000/health', timeout=2).json()
        telemetry.update({
            'cpu_percent': health['cpu_percent'],
            'memory_percent': health['memory_percent'],
            'temperature': health['temperature']
        })
    except:
        pass

    try:
        lcd = requests.get('http://localhost:9001/readings', timeout=2).json()
        telemetry.update({
            'heart_rate': lcd['heart_rate'],
            'spo2': lcd['spo2'],
            'skin_temp': lcd['skin_temp']
        })
    except:
        pass

    try:
        nte = requests.get('http://localhost:8886/baby/current', timeout=2).json()
        telemetry.update({
            'nte_baby_id': nte['baby_id'],
            'nte_age_hours': nte['age_hours'],
            'nte_range_min': nte['range'][0],
            'nte_range_max': nte['range'][1]
        })
    except:
        pass

    # ... collect from other services

    # Publish to ThingsBoard
    mqtt_client.publish('v1/devices/me/telemetry', json.dumps(telemetry))

    # Wait 1 second before next cycle
    time.sleep(1)
```

---

## API Endpoints Reference

### Complete API Map

```
┌────────────────────────────────────────────────────────────────────┐
│                         DASHBOARD FRONTEND                          │
│      https://incubator-dashboard-571778410429.us-central1.run.app  │
└────────────────────────────────────────────────────────────────────┘

Frontend Routes (React Router):
  /login                  - Login page (admin/parent)
  /clinical               - Clinical dashboard (vitals, NTE, cameras)
  /admin                  - Admin panel (system health, notifications)
  /parent                 - Parent portal (baby info, messaging)

API Proxy Routes:

1. Pi Services (via Tailscale VM Proxy):

   /api/pi:9000/health          GET    - System health metrics
   /api/pi:9000/shutdown        POST   - Shutdown Pi
   /api/pi:9000/reboot          POST   - Reboot Pi

   /api/pi/lcd/readings         GET    - LCD OCR readings

   /api/pi/camera/?action=stream    GET    - Infant camera MJPEG
   /api/pi/lcd-camera/?action=stream GET   - LCD camera MJPEG

   /api/pi:8886/baby/register   POST   - Register new baby
   /api/pi:8886/baby/list       GET    - List all babies
   /api/pi:8886/baby/:id        GET    - Get baby details
   /api/pi:8886/baby/:id        DELETE - Remove baby
   /api/pi:8886/baby/current    GET    - Get active baby
   /api/pi:8886/recommendations POST   - Calculate NTE recommendations

   /api/pi/jaundice/detect      POST   - Detect jaundice
   /api/pi/jaundice/latest      GET    - Get latest result

   /api/pi:8888/cry/status      GET    - Cry detection status
   /api/pi:8888/cry/start       POST   - Start recording
   /api/pi:8888/cry/stop        POST   - Stop recording
   /api/pi:8888/cry/recordings  GET    - List recordings

   /api/pi/snapshot/            GET    - Test dashboard HTML

2. Admin Backend (Cloud Run):

   /api/auth/login              POST   - Admin login
   /api/auth/verify-setup-token POST   - Verify setup token
   /api/auth/setup-password     POST   - Set password
   /api/auth/verify             GET    - Verify session

   /api/admin/create            POST   - Create admin
   /api/admin/list              GET    - List admins
   /api/admin/:id               GET    - Get admin
   /api/admin/:id               PUT    - Update admin
   /api/admin/:id               DELETE - Delete admin
   /api/admin/me                GET    - Current admin info

   /api/admin/notifications     GET    - List notifications
   /api/admin/notifications     POST   - Create notification
   /api/admin/notifications/mark-read POST - Mark as read

3. Parent Backend (Cloud Run):

   /api/parent/login            POST   - Parent OTP login
   /api/parent/baby             GET    - Baby information
   /api/parent/messages         GET    - Get messages
   /api/parent/messages         POST   - Send message
   /api/parent/messages/:id/read PUT   - Mark message read

4. ThingsBoard (Direct from Browser):

   https://thingsboard.cloud/api/auth/login
   https://thingsboard.cloud/api/plugins/telemetry/DEVICE/values/timeseries
   https://thingsboard.cloud/api/plugins/telemetry/DEVICE/values/attributes
```

---

## Security & Access Control

### Network Security Layers

```
Layer 1: HTTPS/TLS
  ├─> All Cloud Run services use HTTPS
  ├─> Certificate auto-managed by Google
  └─> TLS 1.2+ enforced

Layer 2: Tailscale VPN
  ├─> WireGuard encryption
  ├─> Per-device authentication
  ├─> Access control lists (ACLs)
  └─> MagicDNS for easy discovery

Layer 3: Application Authentication
  ├─> Admin: JWT tokens
  ├─> Parent: OTP
  └─> ThingsBoard: Device tokens

Layer 4: Firewall Rules
  ├─> GCP: Only 80/443 from internet
  ├─> Pi: Only Tailscale network access
  └─> Services: localhost-only binding
```

### Access Control Matrix

| User Type     | Clinical Dashboard | Admin Panel    | Parent Portal         | Pi Direct Access | ThingsBoard  |
| ------------- | ------------------ | -------------- | --------------------- | ---------------- | ------------ |
| **Admin**     | ✅ Full access     | ✅ Full access | ❌ No access          | ✅ Via proxy     | ✅ Read-only |
| **Clinician** | ✅ Full access     | ❌ No access   | ❌ No access          | ✅ Via proxy     | ✅ Read-only |
| **Parent**    | ❌ No access       | ❌ No access   | ✅ Limited (own baby) | ❌ No access     | ❌ No access |
| **Public**    | ❌ No access       | ❌ No access   | ❌ No access          | ❌ No access     | ❌ No access |

### Data Privacy

**Personal Data Storage**:

- **Admin Backend SQLite**: Admin emails, hashed passwords
- **Parent Backend SQLite**: Phone numbers, OTP codes (short-lived)
- **Pi NTE Database**: Baby IDs (pseudonymized), age, weight
- **ThingsBoard**: Telemetry only (no PII)

**Data Encryption**:

- **At Rest**: Cloud Run uses Google-managed encryption
- **In Transit**: TLS for HTTPS, WireGuard for Tailscale
- **Backup**: Automated snapshots (encrypted)

**Compliance Considerations**:

- HIPAA: Not currently compliant (would need BAA with GCP)
- GDPR: Data minimization, right to erasure implemented
- Local regulations: Consult legal team

---

## Troubleshooting

### Common Issues

**1. Camera streams not loading**

```
Symptom: Black screen or "Failed to load stream"
Diagnosis:
  - Check Tailscale connection: tailscale status
  - Verify Pi cameras: ls /dev/video*
  - Test direct stream: curl http://100.89.162.22:8080/?action=stream
  - Check nginx logs: sudo journalctl -u nginx -f

Fix:
  - Restart camera services: sudo systemctl restart camera_server
  - Restart Tailscale: sudo systemctl restart tailscaled
```

**2. ThingsBoard data not updating**

```
Symptom: Stale data, "Last updated: 5 minutes ago"
Diagnosis:
  - Check MQTT client: sudo systemctl status thingsboard_client
  - Verify network: ping thingsboard.cloud
  - Check logs: sudo journalctl -u thingsboard_client -f

Fix:
  - Restart MQTT client: sudo systemctl restart thingsboard_client
  - Regenerate device token if expired
```

**3. Admin login fails with "Not valid JSON"**

```
Symptom: Error: "Unexpected token '<', "<html>..." is not valid JSON"
Diagnosis:
  - Check nginx routing: /api/auth/ should proxy to admin backend
  - Verify admin backend health: curl https://incubator-admin-backend-...us-central1.run.app/api/auth/login
  - Check browser network tab for actual URL

Fix:
  - Rebuild dashboard with correct nginx.conf
  - Verify proxy_pass URLs include full hostname
```

**4. High latency (>3s response)**

```
Symptom: Slow dashboard, spinning loaders
Diagnosis:
  - Check Tailscale latency: ping 100.89.162.22
  - Verify using ThingsBoard for NTE data (not direct Pi calls)
  - Check network tab for which APIs are slow

Fix:
  - Use ThingsBoard for real-time data (10-30x faster)
  - Optimize nginx proxy settings (buffering, timeouts)
  - Consider edge caching for static data
```

### Monitoring & Logs

**Cloud Run Logs**:

```bash
# Dashboard logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=incubator-dashboard" --limit=50 --format=json

# Admin backend logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=incubator-admin-backend" --limit=50 --format=json
```

**Proxy VM Logs**:

```bash
# SSH into VM
gcloud compute ssh tailscale-proxy-vm --zone=us-central1-a

# nginx access logs
sudo tail -f /var/log/nginx/access.log

# nginx error logs
sudo tail -f /var/log/nginx/error.log

# Tailscale logs
sudo journalctl -u tailscaled -f
```

**Pi Logs**:

```bash
# SSH into Pi via Tailscale
ssh pi@100.89.162.22

# All service logs
sudo journalctl -f

# Specific service
sudo journalctl -u nte_server -f

# ThingsBoard client
sudo journalctl -u thingsboard_client -f
```

---

## Performance Optimization

### Current Metrics

| Metric                | Current Value | Target | Notes                |
| --------------------- | ------------- | ------ | -------------------- |
| Dashboard Load Time   | ~2.5s         | <2s    | Initial bundle size  |
| Camera Stream Latency | ~200ms        | <500ms | MJPEG over Tailscale |
| ThingsBoard API       | 50-100ms      | <200ms | REST API calls       |
| Direct Pi API         | 1000-3000ms   | N/A    | Avoid if possible    |
| NTE Calculation       | ~500ms        | <1s    | Thermal zone calc    |

### Optimization Strategies

**1. Use ThingsBoard for Real-Time Data**

```javascript
// ❌ BAD: Direct Pi polling (1000ms+ latency)
const data = await fetch("/api/pi:8886/recommendations");

// ✅ GOOD: ThingsBoard telemetry (50-100ms latency)
const data = tbService.getTelemetryKeys(["nte_range_min", "nte_range_max"]);
```

**2. Implement Caching**

```nginx
# Cache static assets
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}

# Cache API responses (for non-real-time data)
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m;
location /api/pi/jaundice/latest {
    proxy_cache api_cache;
    proxy_cache_valid 200 5m;
}
```

**3. Optimize Bundle Size**

```bash
# Analyze bundle
npm run build
npx source-map-explorer 'build/static/js/*.js'

# Code splitting
import React, { lazy, Suspense } from 'react';
const AdminPanel = lazy(() => import('./components/Admin/AdminPanel'));
```

**4. Enable Gzip Compression**

```nginx
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css application/json application/javascript text/xml;
```

---

## Future Enhancements

### Planned Improvements

1. **Multi-Region Deployment**

   - Deploy to multiple GCP regions (us-east1, europe-west1)
   - Use Cloud Load Balancer for geo-routing
   - Reduce latency for global users

2. **Database Migration**

   - Move from SQLite to Cloud SQL (PostgreSQL)
   - Enable multi-instance backends
   - Better concurrency and scalability

3. **Observability**

   - Cloud Monitoring dashboards
   - Uptime checks and alerting
   - Distributed tracing (Cloud Trace)
   - Error reporting (Cloud Error Reporting)

4. **Security Enhancements**

   - Secret Manager for API keys
   - VPC Service Controls
   - Cloud Armor (DDoS protection)
   - Certificate pinning

5. **Edge Computing**

   - Move ML inference to cloud (Cloud Run GPU)
   - Real-time video analytics (Cloud Vision API)
   - Reduce Pi compute load

6. **Backup & Disaster Recovery**
   - Automated Cloud Storage backups
   - Multi-region replication
   - RTO: 15 minutes
   - RPO: 5 minutes

---

## Cost Breakdown

### Monthly GCP Costs (Estimated)

| Service                     | Usage     | Cost           |
| --------------------------- | --------- | -------------- |
| **Cloud Run**               |           |                |
| Dashboard (3 instances avg) | 720 hours | $15            |
| Admin Backend (1 instance)  | 240 hours | $5             |
| Parent Backend (1 instance) | 240 hours | $5             |
| **Compute Engine**          |           |                |
| Proxy VM (e2-medium)        | 730 hours | $25            |
| Static External IP          | 1 IP      | $3             |
| **Networking**              |           |                |
| Egress (5GB/month)          | 5GB       | $0.50          |
| **Container Registry**      |           |                |
| Storage (10GB)              | 10GB      | $0.25          |
| **Total**                   |           | **~$53/month** |

**ThingsBoard Cloud**: Free tier (1 device, 1000 msg/day)
**Tailscale**: Free tier (up to 20 devices)

### Cost Optimization Tips

1. Use Cloud Run min instances = 0 (scale to zero)
2. Use preemptible VM for proxy (60-91% discount)
3. Enable Cloud CDN for static assets
4. Set up budget alerts at $40/month

---

## Conclusion

This architecture provides:

- ✅ **Scalability**: Auto-scaling Cloud Run services
- ✅ **Security**: Multi-layer encryption and authentication
- ✅ **Reliability**: 99.9% uptime SLA from GCP
- ✅ **Performance**: <100ms for most operations via ThingsBoard
- ✅ **Cost-effective**: ~$50/month for full stack
- ✅ **Maintainability**: Clear separation of concerns

The Tailscale VPN bridge elegantly solves the challenge of accessing a private edge device from a public cloud, while ThingsBoard provides efficient real-time data synchronization without polling overhead.

---

**Document Version**: 1.0  
**Last Updated**: November 9, 2025  
**Maintained By**: Development Team
