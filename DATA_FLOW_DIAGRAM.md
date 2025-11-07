# 📊 Hybrid Cry Detection - Data Flow & Telemetry Schema

## 🔄 Complete Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          HYBRID CRY DETECTION FLOW                           │
└─────────────────────────────────────────────────────────────────────────────┘

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 1️⃣  AUDIO CAPTURE (Continuous)                                             ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    🎤 Microphone (USB/Built-in)
         │
         │ PyAudio Stream
         │ ├─ Format: Float32
         │ ├─ Channels: 1 (Mono)
         │ ├─ Sample Rate: 16000 Hz
         │ └─ Chunk Size: 1024 samples
         ▼
    ┌─────────────────────┐
    │  Audio Callback     │ ─────► Rolling Buffer (5 sec)
    │  (Real-time)        │        └─ deque(maxlen=80000)
    └──────────┬──────────┘
               │
               │ Queue
               ▼
    ┌─────────────────────┐
    │  Processing Thread  │
    │  - Calculate RMS    │
    │  - FFT Analysis     │
    │  - Frequency Check  │
    └──────────┬──────────┘
               │
               ▼

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 2️⃣  STAGE 1: SIMPLE CRY DETECTION (< 100ms latency)                        ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    ┌─────────────────────────────────────┐
    │  FFT-Based Detection                │
    ├─────────────────────────────────────┤
    │  1. RMS Amplitude > 0.1             │
    │  2. Frequency range: 300-2000 Hz    │
    │  3. Cry frequency ratio > 0.3       │
    │  4. Loudness > sensitivity * 0.1    │
    └──────────┬──────────────────────────┘
               │
               ├─── NO CRY ──► Continue monitoring
               │
               └─── CRY DETECTED ──►
                    │
                    ├─ Set cry_detected = True
                    ├─ Increment total_detections
                    ├─ Record last_cry_time
                    │
                    ▼

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 3️⃣  AUDIO RECORDING (5 seconds)                                            ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    ┌─────────────────────────────────────┐
    │  AudioRecorder.save_recording()     │
    ├─────────────────────────────────────┤
    │  1. Get 5-sec buffer from deque     │
    │  2. Convert Float32 → Int16         │
    │  3. Save to temp WAV file           │
    │     └─ /tmp/tmpXXXXXX.wav          │
    └──────────┬──────────────────────────┘
               │
               ▼

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 4️⃣  HTTP REQUEST TO CLASSIFICATION SERVICE                                 ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    ┌─────────────────────────────────────┐
    │  POST http://localhost:8890/classify│
    ├─────────────────────────────────────┤
    │  Content-Type: multipart/form-data  │
    │  file: @/tmp/tmpXXXXXX.wav          │
    └──────────┬──────────────────────────┘
               │
               │ HTTP Request (timeout: 10s)
               ▼

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 5️⃣  STAGE 2: YAMNET VERIFICATION (Port 8890)                               ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    ┌─────────────────────────────────────────────────┐
    │  YAMNet Detection Pipeline                      │
    ├─────────────────────────────────────────────────┤
    │  1. Load WAV file (librosa)                     │
    │     └─ 16kHz, mono, float32                     │
    │                                                  │
    │  2. Extract YAMNet embeddings (TF Hub)          │
    │     ├─ Input: audio waveform tensor             │
    │     ├─ Output: embeddings (N frames × 1024)     │
    │     └─ Aggregate: mean(1024) + std(1024)        │
    │        = 2048 features                           │
    │                                                  │
    │  3. Scale features (StandardScaler)             │
    │     └─ Normalize to zero mean, unit variance    │
    │                                                  │
    │  4. Apply PCA (dimension reduction)             │
    │     └─ 2048 → reduced dimensions                │
    │                                                  │
    │  5. Logistic Regression classification          │
    │     ├─ Trained threshold: 0.212                 │
    │     ├─ Output: cry_probability (0-1)            │
    │     └─ is_cry = (probability >= 0.212)          │
    └──────────┬──────────────────────────────────────┘
               │
               ├─── is_cry = FALSE ──► Response: Not a cry
               │                        └─ Increment false_positives
               │
               └─── is_cry = TRUE ──► Continue to Stage 3
                                       └─ Cry verified!

                    ▼

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 6️⃣  STAGE 3: ENSEMBLE CLASSIFICATION                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    ┌──────────────────────────────────────────────────────────┐
    │  Feature Extraction (librosa)                            │
    ├──────────────────────────────────────────────────────────┤
    │  1. MFCC (40 coefficients)         ────► 40 features     │
    │  2. Chroma STFT (12 bins)          ────► 12 features     │
    │  3. Mel Spectrogram (40 bands)     ────► 40 features     │
    │  4. Spectral Contrast (7 bands)    ────► 7 features      │
    │  5. Tonnetz (6 features)           ────► 6 features      │
    │  6. Spectral Centroid              ────► 1 feature       │
    │  7. Spectral Rolloff               ────► 1 feature       │
    │                                                           │
    │  Total: 107 features                                     │
    └──────────┬───────────────────────────────────────────────┘
               │
               ▼
    ┌──────────────────────────────────────────────────────────┐
    │  Classification Pipeline                                 │
    ├──────────────────────────────────────────────────────────┤
    │  1. Scale features (StandardScaler)                      │
    │     └─ Normalize feature values                          │
    │                                                           │
    │  2. Feature Selection (SelectKBest)                      │
    │     └─ Select most informative features                  │
    │                                                           │
    │  3. Ensemble Classifier (VotingClassifier)               │
    │     ├─ Multiple base classifiers voting                  │
    │     ├─ Output: class probabilities                       │
    │     └─ Predicted class: argmax(probabilities)            │
    │                                                           │
    │  4. Label Encoding (inverse_transform)                   │
    │     └─ Convert class index → label string                │
    │        (e.g., 0 → "hungry")                              │
    └──────────┬───────────────────────────────────────────────┘
               │
               ├─── confidence < 0.6 ──► Classification rejected
               │                          └─ Return cry verified only
               │
               └─── confidence >= 0.6 ──► Classification accepted
                                           └─ Return label + probabilities
                    ▼

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 7️⃣  JSON RESPONSE                                                          ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    {
      "success": true,
      "is_cry": true,
      "cry_confidence": 0.9234,
      "classification": "hungry",
      "classification_confidence": 0.8512,
      "probabilities": {
        "hungry": 0.8512,
        "discomfort": 0.0823,
        "belly_pain": 0.0421,
        "tired": 0.0244
      },
      "message": "Cry detected: hungry (confidence: 85.12%)",
      "timestamp": 1736794567.123
    }

               │
               ▼

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 8️⃣  UPDATE CRY DETECTOR STATE                                              ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    ┌─────────────────────────────────────────┐
    │  State Variables Updated                │
    ├─────────────────────────────────────────┤
    │  cry_verified = true                    │
    │  verification_confidence = 0.9234       │
    │  current_classification = "hungry"      │
    │  current_classification_confidence =... │
    │  current_classification_probs = {...}   │
    │  verified_cries += 1                    │
    │  last_classification_time = now()       │
    └──────────┬──────────────────────────────┘
               │
               ▼

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 9️⃣  THINGSBOARD MQTT PUBLISH                                               ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    ┌─────────────────────────────────────────────────────────┐
    │  MQTT Client (paho-mqtt)                                │
    ├─────────────────────────────────────────────────────────┤
    │  Host: thingsboard.cloud                                │
    │  Port: 1883                                             │
    │  Topic: v1/devices/me/telemetry                         │
    │  QoS: 1 (At least once delivery)                        │
    └──────────┬──────────────────────────────────────────────┘
               │
               │ Telemetry Payload (JSON):
               ▼
    {
      // Basic detection data
      "cry_detected": true,
      "cry_audio_level": 0.125,
      "cry_sensitivity": 0.6,
      "cry_total_detections": 17,
      "cry_monitoring": true,
      "cry_last_detected": 1736794567.123,

      // NEW: Classification data
      "cry_classification": "hungry",
      "cry_classification_confidence": 0.8512,
      "cry_classification_top1": "hungry: 85.12%",
      "cry_classification_top2": "discomfort: 8.23%",
      "cry_classification_top3": "belly_pain: 4.21%",

      // NEW: Verification data
      "cry_verified": true,
      "cry_verification_confidence": 0.9234,

      // NEW: Statistics
      "verified_cries": 15,
      "false_positives": 2,

      "timestamp": 1736794567123
    }

               │
               ▼

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 🔟  THINGSBOARD PROCESSING                                                 ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    ┌─────────────────────────────────────────────────────────┐
    │  ThingsBoard Device: INC-001                            │
    ├─────────────────────────────────────────────────────────┤
    │  1. Store telemetry in time-series database             │
    │  2. Trigger rules (if configured):                      │
    │     ├─ Alert on cry_detected = true                     │
    │     ├─ Notify on specific classifications               │
    │     └─ Track false_positives rate                       │
    │  3. Update device attributes                            │
    │  4. Send to dashboard widgets                           │
    └──────────┬──────────────────────────────────────────────┘
               │
               │ WebSocket / REST API
               ▼

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 1️⃣1️⃣  REACT DASHBOARD (DataContext)                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    ┌─────────────────────────────────────────────────────────┐
    │  DataContext.js (Auto-polling every 15s)                │
    ├─────────────────────────────────────────────────────────┤
    │  1. Fetch telemetry from ThingsBoard REST API           │
    │     GET /api/plugins/telemetry/DEVICE/INC-001/values/...│
    │                                                          │
    │  2. Extract latest values for each key                  │
    │                                                          │
    │  3. Update React state:                                 │
    │     ├─ cryData.cry_detected                             │
    │     ├─ cryData.cry_classification                       │
    │     ├─ cryData.cry_classification_confidence            │
    │     ├─ cryData.cry_classification_top1/2/3              │
    │     ├─ cryData.verified_cries                           │
    │     └─ cryData.false_positives                          │
    │                                                          │
    │  4. Trigger re-render of CryWidget                      │
    └──────────┬──────────────────────────────────────────────┘
               │
               ▼

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 1️⃣2️⃣  CRYWIDGET DISPLAY                                                   ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    ┌──────────────────────────────────────────────────────────────┐
    │  ╔════════════════════════════════════════════════════════╗  │
    │  ║ 🎧 Cry Detection                                       ║  │
    │  ║    Voice analytics module                              ║  │
    │  ╠════════════════════════════════════════════════════════╣  │
    │  ║                                                         ║  │
    │  ║  ⚠️  Cry detected: hungry                              ║  │
    │  ║      Classified with 85% confidence.                   ║  │
    │  ║                                                         ║  │
    │  ╠════════════════════════════════════════════════════════╣  │
    │  ║                                                         ║  │
    │  ║  📊 Audio Level      0.125  [████████░░░░] 12.5%       ║  │
    │  ║  🎚️  Sensitivity     0.6    [●] Medium                 ║  │
    │  ║  📈 Detections       17     15 verified • 2 false pos  ║  │
    │  ║                                                         ║  │
    │  ╠════════════════════════════════════════════════════════╣  │
    │  ║                                                         ║  │
    │  ║  ⚠️  Attention required                                ║  │
    │  ║      Baby is crying: hungry (85% confidence)           ║  │
    │  ║                                                         ║  │
    │  ║      Classification breakdown:                         ║  │
    │  ║      • hungry: 85.12%                                  ║  │
    │  ║      • discomfort: 8.23%                               ║  │
    │  ║      • belly_pain: 4.21%                               ║  │
    │  ║                                                         ║  │
    │  ╠════════════════════════════════════════════════════════╣  │
    │  ║  Last update: 14:32:47 • 2 mins ago                    ║  │
    │  ║  ℹ️  Auto polling every 15 seconds                      ║  │
    │  ╚════════════════════════════════════════════════════════╝  │
    └──────────────────────────────────────────────────────────────┘
```

## 📊 Telemetry Schema Reference

### Complete Telemetry Keys

| Key                             | Type    | Description                       | Example               | Source   |
| ------------------------------- | ------- | --------------------------------- | --------------------- | -------- |
| `cry_detected`                  | Boolean | Whether cry is currently detected | `true`                | Existing |
| `cry_audio_level`               | Float   | Current audio amplitude (0-1)     | `0.125`               | Existing |
| `cry_sensitivity`               | Float   | Detection sensitivity threshold   | `0.6`                 | Existing |
| `cry_total_detections`          | Integer | Total cries detected this session | `17`                  | Existing |
| `cry_monitoring`                | Boolean | Whether monitoring is active      | `true`                | Existing |
| `cry_last_detected`             | Float   | Unix timestamp of last detection  | `1736794567.123`      | Existing |
| `cry_classification`            | String  | Cry type label                    | `"hungry"`            | **NEW**  |
| `cry_classification_confidence` | Float   | Classification confidence (0-1)   | `0.8512`              | **NEW**  |
| `cry_classification_top1`       | String  | Top probability formatted         | `"hungry: 85.12%"`    | **NEW**  |
| `cry_classification_top2`       | String  | 2nd probability formatted         | `"discomfort: 8.23%"` | **NEW**  |
| `cry_classification_top3`       | String  | 3rd probability formatted         | `"belly_pain: 4.21%"` | **NEW**  |
| `cry_verified`                  | Boolean | YAMNet verification result        | `true`                | **NEW**  |
| `cry_verification_confidence`   | Float   | YAMNet confidence (0-1)           | `0.9234`              | **NEW**  |
| `verified_cries`                | Integer | Verified cries this session       | `15`                  | **NEW**  |
| `false_positives`               | Integer | False positives this session      | `2`                   | **NEW**  |
| `timestamp`                     | Integer | Unix timestamp in milliseconds    | `1736794567123`       | Existing |

### Sample Telemetry Payload (Full)

```json
{
  "cry_detected": true,
  "cry_audio_level": 0.125,
  "cry_sensitivity": 0.6,
  "cry_total_detections": 17,
  "cry_monitoring": true,
  "cry_last_detected": 1736794567.123,
  "cry_classification": "hungry",
  "cry_classification_confidence": 0.8512,
  "cry_classification_top1": "hungry: 85.12%",
  "cry_classification_top2": "discomfort: 8.23%",
  "cry_classification_top3": "belly_pain: 4.21%",
  "cry_verified": true,
  "cry_verification_confidence": 0.9234,
  "verified_cries": 15,
  "false_positives": 2,
  "timestamp": 1736794567123
}
```

### Classification Labels (Example)

Depends on training data. Common labels:

- `"hungry"` - Hungry cry pattern
- `"discomfort"` - General discomfort
- `"belly_pain"` - Digestive issues
- `"tired"` - Sleepy/fatigue
- `"wet_diaper"` - Needs changing
- `"cold"` - Temperature discomfort
- `"hot"` - Too warm
- `"lonely"` - Attention seeking

**Note:** Check actual labels with:

```bash
curl http://localhost:8890/model-info | jq '.classification.classes'
```

## ⏱️ Timing Breakdown

| Stage                   | Time               | Cumulative | Notes                         |
| ----------------------- | ------------------ | ---------- | ----------------------------- |
| Audio capture           | Continuous         | -          | Real-time streaming           |
| Simple detection        | <100ms             | <100ms     | FFT-based analysis            |
| Recording buffer        | 5000ms             | ~5100ms    | Fixed duration                |
| HTTP request            | 100-500ms          | ~5500ms    | Network + file I/O            |
| YAMNet embeddings       | 500-1000ms         | ~6500ms    | TensorFlow inference          |
| YAMNet classification   | 200-400ms          | ~6900ms    | Linear model                  |
| Feature extraction      | 500-1000ms         | ~7500ms    | Librosa processing            |
| Ensemble classification | 100-300ms          | ~7800ms    | Voting classifier             |
| HTTP response           | 100-200ms          | ~8000ms    | JSON serialization            |
| ThingsBoard publish     | 200-500ms          | ~8500ms    | MQTT QoS 1                    |
| Dashboard polling       | 0-15000ms          | variable   | 15s interval                  |
| **Total (worst case)**  | **~8.5 seconds**   | -          | From cry start to ThingsBoard |
| **User perception**     | **~10-20 seconds** | -          | Including dashboard update    |

## 🔄 State Transitions

```
IDLE (Monitoring Active)
  │
  ├─ Audio level > threshold ─────────────────────────┐
  │                                                     │
  ▼                                                     ▼
CRY DETECTED (Stage 1)                      ELEVATED SOUND
  │                                            (No cry pattern)
  ├─ Start 5-sec recording                             │
  ├─ Increment total_detections                        │
  ├─ Publish to ThingsBoard                            │
  │                                                     │
  ▼                                                     │
RECORDING (5 seconds)                                  │
  │                                                     │
  ├─ Save to temp WAV                                  │
  ├─ POST to classification service                    │
  │                                                     │
  ▼                                                     │
CLASSIFICATION IN PROGRESS                             │
  │                                                     │
  ├─ YAMNet verification                               │
  │   ├─ is_cry = false ──► Increment false_positives─┤
  │   └─ is_cry = true ──► Continue                    │
  │                                                     │
  ├─ Ensemble classification                           │
  │   ├─ confidence < 0.6 ──► Cry verified only        │
  │   └─ confidence >= 0.6 ──► Full classification     │
  │                                                     │
  ▼                                                     │
CLASSIFIED CRY                                         │
  │                                                     │
  ├─ Set classification variables                      │
  ├─ Increment verified_cries                          │
  ├─ Publish full telemetry to ThingsBoard             │
  │                                                     │
  ▼                                                     │
COOLDOWN (10 seconds)                                  │
  │                                                     │
  ├─ No new classifications                            │
  ├─ Continue monitoring                               │
  │                                                     │
  ▼                                                     │
CRY CONTINUES                                          │
  │                                                     │
  ├─ If audio drops for 3 seconds ──► Clear state      │
  │                                                     │
  ▼                                                     │
IDLE (Back to monitoring)  ◄───────────────────────────┘
```

## 📈 Performance Metrics

### Success Criteria:

- ✅ Detection latency: <100ms
- ✅ End-to-end latency: <10 seconds
- ✅ Classification accuracy: >85% (YAMNet)
- ✅ False positive rate: <10% (with verification)
- ✅ CPU usage: <50% during classification
- ✅ Memory usage: <1.5GB total
- ✅ Service uptime: >99%

### Monitoring Points:

1. **Real-time detector:** Log every detection with timestamp
2. **Classification service:** Log request time, processing time, result
3. **ThingsBoard publish:** Log success/failure, latency
4. **Dashboard polling:** Log fetch errors, data staleness
5. **System resources:** Monitor CPU, RAM, disk I/O

---

**Last Updated:** January 2025  
**Diagram Version:** 1.0  
**Architecture:** Hybrid (Real-time + ML)
