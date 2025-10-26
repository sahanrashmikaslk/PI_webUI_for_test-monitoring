#!/bin/bash
# Comprehensive service health checker

check_service() {
    local service_name=$1
    local port=$2
    local endpoint=$3
    
    # Check if service is running
    if ! systemctl is-active --quiet $service_name 2>/dev/null; then
        echo "\"$service_name\": {\"status\": \"stopped\", \"port\": $port, \"message\": \"Service not running\"}"
        return 1
    fi
    
    # Check if port is listening
    if ! netstat -tln | grep -q ":$port "; then
        echo "\"$service_name\": {\"status\": \"error\", \"port\": $port, \"message\": \"Port not listening\"}"
        return 1
    fi
    
    # Check HTTP endpoint if provided
    if [ -n "$endpoint" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 $endpoint 2>/dev/null)
        if [ "$response" = "200" ]; then
            echo "\"$service_name\": {\"status\": \"running\", \"port\": $port, \"message\": \"OK\"}"
            return 0
        else
            echo "\"$service_name\": {\"status\": \"error\", \"port\": $port, \"message\": \"HTTP $response\"}"
            return 1
        fi
    else
        echo "\"$service_name\": {\"status\": \"running\", \"port\": $port, \"message\": \"OK\"}"
        return 0
    fi
}

echo "{"
echo "  \"timestamp\": \"$(date -Iseconds)\","
echo "  \"services\": {"

# Check NTE Server (8886)
check_service "nte-server" 8886 "http://localhost:8886/health"
echo ","

# Check Camera Server (8889)
check_service "camera-server" 8889 ""
echo ","

# Check Camera Stream 1 (8080)
if netstat -tln | grep -q ":8080 "; then
    echo "    \"camera-stream-1\": {\"status\": \"running\", \"port\": 8080, \"message\": \"OK\"}"
else
    echo "    \"camera-stream-1\": {\"status\": \"error\", \"port\": 8080, \"message\": \"Not streaming\"}"
fi
echo ","

# Check Camera Stream 2 - LCD (8081)
if netstat -tln | grep -q ":8081 "; then
    echo "    \"camera-stream-2-lcd\": {\"status\": \"running\", \"port\": 8081, \"message\": \"OK\"}"
else
    echo "    \"camera-stream-2-lcd\": {\"status\": \"error\", \"port\": 8081, \"message\": \"Not streaming\"}"
fi
echo ","

# Check Cry Detector (8888)
check_service "cry-detector" 8888 ""
echo ","

# Check Jaundice Server (streamlit on 8501)
if pgrep -f 'streamlit.*jaundice' > /dev/null; then
    echo "    \"jaundice-detector\": {\"status\": \"running\", \"port\": 8501, \"message\": \"OK\"}"
else
    echo "    \"jaundice-detector\": {\"status\": \"stopped\", \"port\": 8501, \"message\": \"Not running\"}"
fi

echo ""
echo "  }"
echo "}"
