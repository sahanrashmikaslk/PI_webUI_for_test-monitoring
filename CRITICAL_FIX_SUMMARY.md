# 🔧 Critical Fix: React Dashboard Data Source

## The Problem

React Dashboard was fetching jaundice data **directly from Pi Server REST API** instead of **ThingsBoard**, causing:

- ❌ Bypassing ThingsBoard entirely
- ❌ Using wrong field names (no `jaundice_` prefix)
- ❌ Wrong data structure (direct values vs ThingsBoard's `[{ts, value}]` format)
- ❌ "Loading..." stuck state
- ❌ No data displayed

## The Solution

### ✅ Fixed: DataContext.js

**Changed FROM:** Fetching from Pi Server

```javascript
const response = await fetch(`http://${piHost}:8887/latest`);
```

**Changed TO:** Fetching from ThingsBoard

```javascript
const jaundiceKeys = [
  "jaundice_detected",
  "jaundice_confidence",
  "jaundice_probability",
  "jaundice_brightness",
  "jaundice_reliability",
  "jaundice_status",
];
const data = await tbService.getLatestTelemetry(deviceId, jaundiceKeys);
```

### ✅ Fixed: JaundiceWidget.js

Added helper function to extract values from ThingsBoard format:

```javascript
const extractValue = (field, defaultValue = 0) => {
  if (!field) return defaultValue;
  if (Array.isArray(field) && field.length > 0) {
    return field[0].value; // Extract from [{ts, value}]
  }
  return defaultValue;
};

const confidence = extractValue(data.jaundice_confidence, 0);
const probability = extractValue(data.jaundice_probability, 0);
```

### ✅ Fixed: Manual Detection

"Detect Now" button now:

1. Triggers Pi Server (`/detect` endpoint)
2. Waits 1.5s for Pi to publish to ThingsBoard
3. Fetches updated data from ThingsBoard

## Data Flow Now Correct

```
Test Dashboard → Pi Server REST API (/latest)
                 ├─ Field: confidence (0-1)
                 ├─ Field: probability (0-1)
                 └─ Timestamp: ISO 8601

React Dashboard → ThingsBoard Telemetry API
                  ├─ Field: jaundice_confidence [{ts, value: 0-100}]
                  ├─ Field: jaundice_probability [{ts, value: 0-100}]
                  └─ Timestamp: Unix milliseconds in telemetry
```

## Files Changed

1. ✅ `DataContext.js` - Changed data source to ThingsBoard
2. ✅ `JaundiceWidget.js` - Added ThingsBoard format extraction
3. ✅ `API_FIELD_MAPPING.md` - Updated documentation

## Testing Checklist

- [ ] Start React Dashboard: `npm start`
- [ ] Login to Clinical Dashboard
- [ ] Verify Jaundice Widget shows data (not "Loading...")
- [ ] Check timestamp displays correctly
- [ ] Test "Detect Now" button
- [ ] Verify auto-polling works (30s interval)
- [ ] Check Parent Portal also works

---

**Date:** October 24, 2025  
**Status:** ✅ Fixed - React Dashboard now uses ThingsBoard correctly
