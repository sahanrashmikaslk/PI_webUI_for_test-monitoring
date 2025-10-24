# React Dashboard - Jaundice Detection Integration Guide

## Overview

This guide shows how to integrate the Jaundice Detection system into your React dashboard. The system provides automatic detection every 10 minutes and manual detection on-demand, with all data published to ThingsBoard.

---

## 📊 Data Structure

### ThingsBoard Telemetry Keys

The Pi publishes the following telemetry data to ThingsBoard:

```json
{
  "jaundice_detected": false, // boolean: true if jaundice detected
  "jaundice_confidence": 92.18, // number: 0-100, detection confidence
  "jaundice_probability": 7.82, // number: 0-100, probability of jaundice
  "jaundice_brightness": 105.23, // number: 0-255, image brightness
  "jaundice_status": "Normal", // string: "Normal" or "Jaundice"
  "jaundice_reliability": 100.0, // number: 0-100, reliability score (low light affects this)
  "timestamp": 1729752562843, // unix timestamp in milliseconds
  "detection_type": "auto" // string: "auto" or "manual"
}
```

---

## 🎨 React Component Examples

### 1. Simple Status Component

```jsx
import React, { useEffect, useState } from "react";
import { Card, Badge, Progress } from "antd"; // or your UI library

const JaundiceStatus = ({ thingsBoardData }) => {
  const [status, setStatus] = useState(null);

  useEffect(() => {
    if (thingsBoardData) {
      setStatus({
        detected: thingsBoardData.jaundice_detected,
        confidence: thingsBoardData.jaundice_confidence,
        brightness: thingsBoardData.jaundice_brightness,
        status: thingsBoardData.jaundice_status,
        reliability: thingsBoardData.jaundice_reliability,
        timestamp: new Date(thingsBoardData.timestamp),
        type: thingsBoardData.detection_type,
      });
    }
  }, [thingsBoardData]);

  if (!status) {
    return <Card>Loading jaundice status...</Card>;
  }

  const getStatusColor = () => {
    return status.detected ? "#ff4d4f" : "#52c41a";
  };

  const getConfidenceColor = () => {
    if (status.confidence >= 80) return "#52c41a";
    if (status.confidence >= 60) return "#faad14";
    return "#ff4d4f";
  };

  const getTimeAgo = () => {
    const diffMs = Date.now() - status.timestamp.getTime();
    const diffMins = Math.floor(diffMs / 60000);

    if (diffMins < 1) return "just now";
    if (diffMins === 1) return "1 min ago";
    if (diffMins < 60) return `${diffMins} mins ago`;

    const diffHours = Math.floor(diffMins / 60);
    return diffHours === 1 ? "1 hour ago" : `${diffHours} hours ago`;
  };

  return (
    <Card
      title={
        <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
          <span>🩺 Jaundice Detection</span>
          <Badge
            status={status.detected ? "error" : "success"}
            text={status.status}
          />
        </div>
      }
      extra={
        <span style={{ fontSize: "12px", color: "#999" }}>
          {status.type === "auto" ? "🤖 Auto" : "👆 Manual"} • {getTimeAgo()}
        </span>
      }
    >
      <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        {/* Main Status */}
        <div
          style={{
            padding: "16px",
            borderRadius: "8px",
            backgroundColor: status.detected ? "#fff1f0" : "#f6ffed",
            border: `2px solid ${getStatusColor()}`,
            textAlign: "center",
          }}
        >
          <div
            style={{
              fontSize: "24px",
              fontWeight: "bold",
              color: getStatusColor(),
            }}
          >
            {status.detected ? "⚠️ Jaundice Detected" : "✅ Normal"}
          </div>
        </div>

        {/* Metrics */}
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 1fr",
            gap: "12px",
          }}
        >
          <div
            style={{
              textAlign: "center",
              padding: "12px",
              background: "#fafafa",
              borderRadius: "6px",
            }}
          >
            <div
              style={{ fontSize: "12px", color: "#999", marginBottom: "4px" }}
            >
              Confidence
            </div>
            <div
              style={{
                fontSize: "24px",
                fontWeight: "bold",
                color: getConfidenceColor(),
              }}
            >
              {Math.round(status.confidence)}%
            </div>
            <Progress
              percent={status.confidence}
              strokeColor={getConfidenceColor()}
              showInfo={false}
              size="small"
            />
          </div>

          <div
            style={{
              textAlign: "center",
              padding: "12px",
              background: "#fafafa",
              borderRadius: "6px",
            }}
          >
            <div
              style={{ fontSize: "12px", color: "#999", marginBottom: "4px" }}
            >
              Brightness
            </div>
            <div
              style={{ fontSize: "24px", fontWeight: "bold", color: "#1890ff" }}
            >
              {Math.round(status.brightness)}
            </div>
            <Progress
              percent={Math.min((status.brightness / 255) * 100, 100)}
              strokeColor="#1890ff"
              showInfo={false}
              size="small"
            />
          </div>
        </div>

        {/* Reliability Warning */}
        {status.reliability < 100 && (
          <div
            style={{
              padding: "8px 12px",
              background: "#fffbe6",
              border: "1px solid #ffe58f",
              borderRadius: "6px",
              fontSize: "12px",
              color: "#ad8b00",
            }}
          >
            ⚠️ Low light conditions - Reliability:{" "}
            {Math.round(status.reliability)}%
          </div>
        )}

        {/* Last Check Info */}
        <div
          style={{
            fontSize: "12px",
            color: "#999",
            textAlign: "center",
            padding: "8px",
            background: "#fafafa",
            borderRadius: "4px",
          }}
        >
          Last check: {status.timestamp.toLocaleTimeString()} ({getTimeAgo()})
          {" • "}
          {status.type === "auto" ? "🤖 Automatic" : "👆 Manual"} detection
        </div>
      </div>
    </Card>
  );
};

export default JaundiceStatus;
```

---

### 2. Compact Widget Component

```jsx
import React from "react";
import { Card, Statistic, Row, Col, Tag } from "antd";
import { CheckCircleOutlined, WarningOutlined } from "@ant-design/icons";

const JaundiceWidget = ({ data }) => {
  if (!data) return null;

  const isNormal = !data.jaundice_detected;
  const timestamp = new Date(data.timestamp);
  const diffMins = Math.floor((Date.now() - timestamp) / 60000);

  return (
    <Card
      size="small"
      title="🩺 Jaundice"
      extra={
        <Tag color={data.detection_type === "auto" ? "blue" : "orange"}>
          {data.detection_type === "auto" ? "🤖 Auto" : "👆 Manual"}
        </Tag>
      }
    >
      <Row gutter={16}>
        <Col span={12}>
          <Statistic
            title="Status"
            value={data.jaundice_status}
            valueStyle={{
              color: isNormal ? "#3f8600" : "#cf1322",
              fontSize: "18px",
            }}
            prefix={isNormal ? <CheckCircleOutlined /> : <WarningOutlined />}
          />
        </Col>
        <Col span={12}>
          <Statistic
            title="Confidence"
            value={Math.round(data.jaundice_confidence)}
            suffix="%"
            valueStyle={{ fontSize: "18px" }}
          />
        </Col>
      </Row>

      <div
        style={{
          marginTop: "12px",
          fontSize: "11px",
          color: "#999",
          textAlign: "center",
        }}
      >
        {diffMins < 1 ? "Just now" : `${diffMins} min ago`} • Brightness:{" "}
        {Math.round(data.jaundice_brightness)}
      </div>
    </Card>
  );
};

export default JaundiceWidget;
```

---

### 3. Detailed Dashboard Component with History

```jsx
import React, { useState, useEffect } from "react";
import { Card, Table, Badge, Space, Button, Tooltip } from "antd";
import {
  SyncOutlined,
  CheckCircleOutlined,
  WarningOutlined,
  InfoCircleOutlined,
} from "@ant-design/icons";

const JaundiceDashboard = ({ latestData, historicalData = [] }) => {
  const [refreshing, setRefreshing] = useState(false);

  const columns = [
    {
      title: "Time",
      dataIndex: "timestamp",
      key: "timestamp",
      render: (timestamp) => new Date(timestamp).toLocaleString(),
      width: 180,
    },
    {
      title: "Type",
      dataIndex: "detection_type",
      key: "type",
      render: (type) => (
        <Badge
          status={type === "auto" ? "processing" : "warning"}
          text={type === "auto" ? "🤖 Auto" : "👆 Manual"}
        />
      ),
      width: 120,
    },
    {
      title: "Status",
      dataIndex: "jaundice_status",
      key: "status",
      render: (status, record) => (
        <Space>
          {record.jaundice_detected ? (
            <WarningOutlined style={{ color: "#ff4d4f" }} />
          ) : (
            <CheckCircleOutlined style={{ color: "#52c41a" }} />
          )}
          <span
            style={{
              color: record.jaundice_detected ? "#ff4d4f" : "#52c41a",
              fontWeight: "bold",
            }}
          >
            {status}
          </span>
        </Space>
      ),
      width: 150,
    },
    {
      title: "Confidence",
      dataIndex: "jaundice_confidence",
      key: "confidence",
      render: (confidence) => (
        <span
          style={{
            color:
              confidence >= 80
                ? "#52c41a"
                : confidence >= 60
                ? "#faad14"
                : "#ff4d4f",
            fontWeight: "bold",
          }}
        >
          {Math.round(confidence)}%
        </span>
      ),
      width: 120,
      sorter: (a, b) => a.jaundice_confidence - b.jaundice_confidence,
    },
    {
      title: "Brightness",
      dataIndex: "jaundice_brightness",
      key: "brightness",
      render: (brightness) => Math.round(brightness),
      width: 100,
    },
    {
      title: "Reliability",
      dataIndex: "jaundice_reliability",
      key: "reliability",
      render: (reliability) => (
        <Tooltip
          title={reliability < 100 ? "Low light conditions" : "Good lighting"}
        >
          <span style={{ color: reliability >= 100 ? "#52c41a" : "#faad14" }}>
            {Math.round(reliability)}%{reliability < 100 && " ⚠️"}
          </span>
        </Tooltip>
      ),
      width: 120,
    },
  ];

  const handleRefresh = () => {
    setRefreshing(true);
    // Trigger your data refresh logic here
    setTimeout(() => setRefreshing(false), 1000);
  };

  return (
    <div style={{ padding: "24px" }}>
      {/* Current Status Card */}
      {latestData && (
        <Card
          style={{ marginBottom: "24px" }}
          title={
            <Space>
              <span style={{ fontSize: "18px" }}>
                🩺 Current Jaundice Status
              </span>
              <Tooltip title="Auto-detection runs every 10 minutes">
                <InfoCircleOutlined style={{ color: "#999" }} />
              </Tooltip>
            </Space>
          }
          extra={
            <Button
              icon={<SyncOutlined spin={refreshing} />}
              onClick={handleRefresh}
              size="small"
            >
              Refresh
            </Button>
          }
        >
          <Row gutter={24}>
            <Col span={6}>
              <Statistic
                title="Status"
                value={latestData.jaundice_status}
                valueStyle={{
                  color: latestData.jaundice_detected ? "#ff4d4f" : "#52c41a",
                  fontSize: "28px",
                }}
                prefix={
                  latestData.jaundice_detected ? (
                    <WarningOutlined />
                  ) : (
                    <CheckCircleOutlined />
                  )
                }
              />
            </Col>
            <Col span={6}>
              <Statistic
                title="Confidence"
                value={Math.round(latestData.jaundice_confidence)}
                suffix="%"
                valueStyle={{ fontSize: "28px" }}
              />
            </Col>
            <Col span={6}>
              <Statistic
                title="Brightness"
                value={Math.round(latestData.jaundice_brightness)}
                valueStyle={{ fontSize: "28px" }}
              />
            </Col>
            <Col span={6}>
              <Statistic
                title="Reliability"
                value={Math.round(latestData.jaundice_reliability)}
                suffix="%"
                valueStyle={{
                  fontSize: "28px",
                  color:
                    latestData.jaundice_reliability >= 100
                      ? "#52c41a"
                      : "#faad14",
                }}
              />
            </Col>
          </Row>

          <div
            style={{
              marginTop: "16px",
              padding: "12px",
              background: "#fafafa",
              borderRadius: "6px",
              textAlign: "center",
            }}
          >
            <Space size="large">
              <span>
                {latestData.detection_type === "auto"
                  ? "🤖 Automatic"
                  : "👆 Manual"}{" "}
                detection
              </span>
              <span>•</span>
              <span>{new Date(latestData.timestamp).toLocaleString()}</span>
              <span>•</span>
              <span style={{ color: "#999" }}>
                Next auto-check in ~
                {10 -
                  (Math.floor((Date.now() - latestData.timestamp) / 60000) %
                    10)}{" "}
                min
              </span>
            </Space>
          </div>
        </Card>
      )}

      {/* Historical Data Table */}
      <Card title="📊 Detection History">
        <Table
          columns={columns}
          dataSource={historicalData}
          rowKey="timestamp"
          pagination={{ pageSize: 10 }}
          size="small"
        />
      </Card>
    </div>
  );
};

export default JaundiceDashboard;
```

---

## 🔌 ThingsBoard Integration

### Subscribe to Telemetry Updates

```javascript
// Using ThingsBoard WebSocket API
const subscribeToJaundiceData = (deviceId) => {
  const ws = new WebSocket(
    "wss://your-thingsboard-instance/api/ws/plugins/telemetry"
  );

  ws.onopen = () => {
    // Authenticate
    const authCmd = {
      authCmd: {
        cmdId: 0,
        token: "YOUR_JWT_TOKEN",
      },
    };
    ws.send(JSON.stringify(authCmd));

    // Subscribe to latest telemetry
    const subscribeCmd = {
      tsSubCmds: [
        {
          entityType: "DEVICE",
          entityId: deviceId,
          scope: "LATEST_TELEMETRY",
          cmdId: 1,
        },
      ],
      historyCmds: [],
      attrSubCmds: [],
    };
    ws.send(JSON.stringify(subscribeCmd));
  };

  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    if (data.data) {
      // Extract jaundice telemetry
      const jaundiceData = {
        jaundice_detected: data.data.jaundice_detected?.[0]?.[1],
        jaundice_confidence: data.data.jaundice_confidence?.[0]?.[1],
        jaundice_probability: data.data.jaundice_probability?.[0]?.[1],
        jaundice_brightness: data.data.jaundice_brightness?.[0]?.[1],
        jaundice_status: data.data.jaundice_status?.[0]?.[1],
        jaundice_reliability: data.data.jaundice_reliability?.[0]?.[1],
        timestamp: data.data.timestamp?.[0]?.[0],
        detection_type: data.data.detection_type?.[0]?.[1],
      };

      // Update your React state
      updateJaundiceState(jaundiceData);
    }
  };

  return ws;
};
```

### Fetch Historical Data

```javascript
// Using ThingsBoard REST API
const fetchJaundiceHistory = async (deviceId, startTs, endTs) => {
  const keys = [
    "jaundice_detected",
    "jaundice_confidence",
    "jaundice_brightness",
    "jaundice_status",
    "jaundice_reliability",
    "detection_type",
  ].join(",");

  const url = `https://your-thingsboard-instance/api/plugins/telemetry/DEVICE/${deviceId}/values/timeseries?keys=${keys}&startTs=${startTs}&endTs=${endTs}`;

  const response = await fetch(url, {
    headers: {
      "X-Authorization": "Bearer YOUR_JWT_TOKEN",
    },
  });

  const data = await response.json();

  // Transform to usable format
  const history = [];
  const timestamps = new Set();

  Object.values(data).forEach((valueArray) => {
    valueArray.forEach((item) => timestamps.add(item.ts));
  });

  timestamps.forEach((ts) => {
    history.push({
      timestamp: ts,
      jaundice_detected: data.jaundice_detected?.find((d) => d.ts === ts)
        ?.value,
      jaundice_confidence: data.jaundice_confidence?.find((d) => d.ts === ts)
        ?.value,
      jaundice_brightness: data.jaundice_brightness?.find((d) => d.ts === ts)
        ?.value,
      jaundice_status: data.jaundice_status?.find((d) => d.ts === ts)?.value,
      jaundice_reliability: data.jaundice_reliability?.find((d) => d.ts === ts)
        ?.value,
      detection_type: data.detection_type?.find((d) => d.ts === ts)?.value,
    });
  });

  return history.sort((a, b) => b.timestamp - a.timestamp);
};
```

---

## 🎯 Key Features to Highlight in UI

1. **Detection Type Indicator**

   - 🤖 Auto: Scheduled detection (every 10 minutes)
   - 👆 Manual: User-triggered instant check

2. **Confidence Score with Color Coding**

   - Green (≥80%): High confidence
   - Yellow (60-79%): Medium confidence
   - Red (<60%): Low confidence

3. **Brightness Level**

   - Good Light (≥70): Optimal conditions
   - Low Light (40-69): Suboptimal conditions
   - Very Dark (<40): Poor conditions

4. **Reliability Score**

   - 100%: Normal lighting
   - <100%: Low light affects accuracy

5. **Time Information**
   - Timestamp of detection
   - Time since last detection
   - Next auto-detection countdown

---

## 📱 Mobile-Responsive Design Tips

```jsx
// Use responsive breakpoints
import { useMediaQuery } from "react-responsive";

const JaundiceResponsive = () => {
  const isMobile = useMediaQuery({ maxWidth: 768 });

  return (
    <Card>
      {isMobile ? (
        // Stacked layout for mobile
        <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
          {/* Mobile layout */}
        </div>
      ) : (
        // Grid layout for desktop
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 1fr",
            gap: "16px",
          }}
        >
          {/* Desktop layout */}
        </div>
      )}
    </Card>
  );
};
```

---

## 🔔 Alert/Notification Integration

```jsx
import { notification } from "antd";

// Show notification when jaundice detected
useEffect(() => {
  if (data?.jaundice_detected) {
    notification.warning({
      message: "⚠️ Jaundice Detected",
      description: `Confidence: ${Math.round(data.jaundice_confidence)}% • ${
        data.detection_type === "auto" ? "Automatic" : "Manual"
      } detection`,
      duration: 0, // Don't auto-close
      placement: "topRight",
    });
  }
}, [data]);
```

---

## 📊 Chart Integration (Optional)

```jsx
import { Line } from "@ant-design/charts";

const JaundiceChart = ({ historicalData }) => {
  const chartData = historicalData.map((d) => ({
    time: new Date(d.timestamp).toLocaleTimeString(),
    confidence: d.jaundice_confidence,
    brightness: d.jaundice_brightness / 2.55, // Scale to 0-100
    type: d.detection_type,
  }));

  const config = {
    data: chartData,
    xField: "time",
    yField: "confidence",
    seriesField: "type",
    smooth: true,
    legend: { position: "top" },
    color: ["#1890ff", "#faad14"],
  };

  return <Line {...config} />;
};
```

---

## ✅ Best Practices

1. **Real-time Updates**: Use WebSocket subscriptions for instant updates
2. **Error Handling**: Handle connection failures gracefully
3. **Loading States**: Show loading indicators during data fetch
4. **Empty States**: Handle "no detection yet" scenarios
5. **Accessibility**: Use proper ARIA labels and semantic HTML
6. **Performance**: Memoize components and use React.memo where appropriate
7. **Responsive Design**: Ensure UI works on all screen sizes
8. **User Feedback**: Show success/error notifications for user actions

---

## 🚀 Quick Start Checklist

- [ ] Connect to ThingsBoard WebSocket API
- [ ] Subscribe to jaundice telemetry keys
- [ ] Create basic status display component
- [ ] Add confidence and brightness indicators
- [ ] Implement detection type badges (Auto/Manual)
- [ ] Add last check timestamp display
- [ ] Create historical data table/chart
- [ ] Add alert notifications for jaundice detection
- [ ] Test responsive design on mobile devices
- [ ] Add error handling and loading states

---

## 📞 API Endpoints (Optional Direct Access)

If you want to access the Pi directly (not via ThingsBoard):

```javascript
// Latest detection result
GET http://100.89.162.22:8887/latest

// Manual detection
GET http://100.89.162.22:8887/detect

// Service health
GET http://100.89.162.22:8887/health

// API info
GET http://100.89.162.22:8887/
```

---

## 🎨 Color Palette Reference

```css
/* Status Colors */
--jaundice-normal: #52c41a; /* Green */
--jaundice-detected: #ff4d4f; /* Red */
--jaundice-warning: #faad14; /* Yellow/Orange */

/* Confidence Colors */
--confidence-high: #52c41a; /* ≥80% */
--confidence-medium: #faad14; /* 60-79% */
--confidence-low: #ff4d4f; /* <60% */

/* Detection Type */
--auto-detection: #1890ff; /* Blue */
--manual-detection: #faad14; /* Orange */
```

---

For more details, see the main documentation: `JAUNDICE_AUTO_DETECTION.md`
