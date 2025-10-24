# Jaundice Detection Data Flow

## Critical Understanding: Two Different Data Sources

### 1. Test Dashboard (index.html)

**Source:** Pi Server REST API (`http://pi-host:8887/latest`)  
**Use Case:** Direct monitoring from Pi for testing  
**Field Format:** Plain names without prefix

### 2. React Dashboard (Clinical + Parent Portal)

**Source:** ThingsBoard Cloud Telemetry API  
**Use Case:** Production monitoring through ThingsBoard  
**Field Format:** Names with `jaundice_` prefix

---

## Data Flow Architecture

```
┌─────────────┐
│  Pi Camera  │
│   + Model   │
└──────┬──────┘
       │
       │ Detects Jaundice
       ▼
┌─────────────────┐
│ jaundice_server │  (Port 8887)
│   (Pi Device)   │
└────┬───────┬────┘
     │       │
     │       └────────────────┐
     │                        │
     │ REST API              │ MQTT Publish
     ▼                        ▼
┌────────────┐        ┌──────────────┐
│    Test    │        │ ThingsBoard  │
│  Dashboard │        │    Cloud     │
│ (Direct)   │        └──────┬───────┘
└────────────┘               │
                             │ Telemetry API
                             ▼
                      ┌──────────────┐
                      │    React     │
                      │  Dashboard   │
                      └──────────────┘
```

---

## Issue Found

The REST API (`/latest` and `/detect` endpoints) returns field names **without** the `jaundice_` prefix, but ThingsBoard telemetry uses field names **with** the prefix.

## Field Name Differences

### REST API Response (Direct from Pi Server)

**Used by:** Test Dashboard (index.html)

```json
{
  "status": "success",
  "jaundice_detected": true,
  "predicted_class": "Jaundice",
  "confidence": 0.8534, // 0-1 scale
  "probability": 0.8534, // 0-1 scale
  "brightness": 78.52, // 0-255 scale
  "reliability": 0.85, // 0-1 scale
  "timestamp": "2025-10-24T10:15:30.123456",
  "detection_type": "auto",
  "message": "Jaundice detected"
}
```

### ThingsBoard Telemetry (After Processing)

**Used by:** React Dashboard (Clinical Dashboard + Parent Portal)

```json
{
  "jaundice_detected": [{ "ts": 1729767330123, "value": true }],
  "jaundice_confidence": [{ "ts": 1729767330123, "value": 85.34 }], // Percentage (0-100)
  "jaundice_probability": [{ "ts": 1729767330123, "value": 85.34 }], // Percentage (0-100)
  "jaundice_brightness": [{ "ts": 1729767330123, "value": 78.52 }],
  "jaundice_status": [{ "ts": 1729767330123, "value": "Jaundice" }],
  "jaundice_reliability": [{ "ts": 1729767330123, "value": 85.0 }] // Percentage (0-100)
}
```

**Note:** ThingsBoard stores telemetry as arrays of `{ts, value}` objects

````

## What Was Fixed

### 1. Test Dashboard (index.html)
**Before:**
```javascript
const confidence = data.jaundice_confidence || 0;  // ❌ Wrong field name
````

**After:**

```javascript
const confidence = Math.round((data.confidence || 0) * 100); // ✅ Correct + convert to %
const probability = Math.round((data.probability || 0) * 100); // ✅ Added
```

### 2. React Dashboard (JaundiceWidget.js)

**Before:**

```javascript
const confidence = data.jaundice_confidence || 0; // ❌ Wrong - expecting ThingsBoard format but fetching from Pi API
const reliability = data.jaundice_reliability || 100;
```

**After:**

```javascript
// Helper to extract from ThingsBoard format [{ts, value}]
const extractValue = (field, defaultValue = 0) => {
  if (!field) return defaultValue;
  if (Array.isArray(field) && field.length > 0) {
    return field[0].value;
  }
  return defaultValue;
};

const confidence = extractValue(data.jaundice_confidence, 0); // ✅ Correct ThingsBoard format
const probability = extractValue(data.jaundice_probability, 0); // Already percentage (0-100)
const reliability = extractValue(data.jaundice_reliability, 100);
```

### 3. React Dashboard (DataContext.js)

**Before:**

```javascript
// ❌ Fetching from Pi server directly
const response = await fetch(`http://${piHost}:8887/latest`);
const data = await response.json();
setJaundiceData(data);
```

**After:**

```javascript
// ✅ Fetching from ThingsBoard telemetry
const jaundiceKeys = [
  "jaundice_detected",
  "jaundice_confidence",
  "jaundice_probability",
  "jaundice_brightness",
  "jaundice_reliability",
  "jaundice_status",
];

const data = await tbService.getLatestTelemetry(deviceId, jaundiceKeys);
setJaundiceData(data); // Returns ThingsBoard format with jaundice_ prefix
```

## Key Differences to Remember

| Aspect           | Test Dashboard          | React Dashboard                             |
| ---------------- | ----------------------- | ------------------------------------------- |
| **Data Source**  | Pi Server REST API      | ThingsBoard Telemetry API                   |
| **Endpoint**     | `http://pi:8887/latest` | `tbService.getLatestTelemetry()`            |
| **Field Prefix** | None                    | `jaundice_`                                 |
| **Data Format**  | Direct values           | Array of `{ts, value}` objects              |
| **Confidence**   | `confidence` (0-1)      | `jaundice_confidence` [{ts, value: 0-100}]  |
| **Probability**  | `probability` (0-1)     | `jaundice_probability` [{ts, value: 0-100}] |
| **Reliability**  | `reliability` (0-1)     | `jaundice_reliability` [{ts, value: 0-100}] |
| **Brightness**   | `brightness` (0-255)    | `jaundice_brightness` [{ts, value: 0-255}]  |
| **Status**       | `predicted_class`       | `jaundice_status`                           |
| **Timestamp**    | ISO 8601 string         | Unix milliseconds in telemetry              |

## Why This Happened

The system has **two different data paths**:

1. **Test Dashboard Path:**

   - Pi Server → REST API → Test Dashboard (index.html)
   - Direct connection for testing
   - Uses raw API response format

2. **React Dashboard Path:**
   - Pi Server → MQTT → ThingsBoard → Telemetry API → React Dashboard
   - Production path through cloud
   - Uses ThingsBoard telemetry format with prefixes and array structure

**The mistake:** React Dashboard was trying to fetch from Pi Server REST API instead of ThingsBoard, causing:

- Wrong data source (bypassing ThingsBoard)
- Wrong field names (no `jaundice_` prefix)
- Wrong data structure (direct values vs array of objects)
- Missing timestamp handling (ISO string vs Unix milliseconds)

## Resolution

### Test Dashboard (index.html)

✅ Fetches from **Pi Server REST API**  
✅ Uses field names **without** `jaundice_` prefix  
✅ Converts decimal to percentage (multiply by 100)  
✅ Handles ISO 8601 timestamp format

### React Dashboard (Clinical + Parent Portal)

✅ Fetches from **ThingsBoard Telemetry API**  
✅ Uses field names **with** `jaundice_` prefix  
✅ Values already in percentage (0-100)  
✅ Extracts values from `[{ts, value}]` array format  
✅ Handles Unix millisecond timestamps

---

**Date:** October 24, 2025  
**Status:** ✅ Fixed
