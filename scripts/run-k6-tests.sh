#!/bin/bash

# K6 Load Testing Script for Passive Liveness API
# Usage: ./run-k6-tests.sh [TPS] [DURATION] [HOST] [PORT]

set -e

# Default values
DEFAULT_TPS=4
DEFAULT_DURATION="5m"
DEFAULT_HOST="localhost"
DEFAULT_PORT="8080"
DEFAULT_PAYLOAD_FILE="../data/payload.json"

# Parse arguments
TPS=${1:-$DEFAULT_TPS}
DURATION=${2:-$DEFAULT_DURATION}
HOST=${3:-$DEFAULT_HOST}
PORT=${4:-$DEFAULT_PORT}

# Ensure results directory exists
mkdir -p ../results

# Check if K6 is installed
if ! command -v k6 &> /dev/null; then
    echo "❌ K6 is not installed. Please install it first:"
    echo "   macOS: brew install k6"
    echo "   Linux: sudo apt-get install k6"
    echo "   Or visit: https://k6.io/docs/getting-started/installation/"
    exit 1
fi

# Check if server is running
echo "🔍 Checking server connectivity..."
if ! curl -s -f "http://${HOST}:${PORT}/api/v1/selphid/health" > /dev/null; then
    echo "⚠️  Warning: Cannot connect to server at http://${HOST}:${PORT}"
    echo "   Make sure the SelphId server is running"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Load payload data
if [[ -f "$DEFAULT_PAYLOAD_FILE" ]]; then
    TOKEN_IMAGE=$(jq -r '.tokenImage' "$DEFAULT_PAYLOAD_FILE")
    EXTRA_DATA=$(jq -r '.extraData' "$DEFAULT_PAYLOAD_FILE")
    echo "📄 Loaded payload from $DEFAULT_PAYLOAD_FILE"
else
    echo "⚠️  Payload file not found: $DEFAULT_PAYLOAD_FILE"
    TOKEN_IMAGE="BASE64_ENCODED_IMAGE_HERE"
    EXTRA_DATA="k6-load-test-default"
fi

# Display test configuration
echo ""
echo "🚀 Starting K6 Load Test"
echo "=========================="
echo "Target TPS: $TPS"
echo "Duration: $DURATION"
echo "Server: http://${HOST}:${PORT}"
echo "Payload: $(echo $EXTRA_DATA | cut -c1-30)..."
echo ""

# Run K6 test
echo "🔥 Executing load test..."
k6 run \
    --env SERVER_HOST="$HOST" \
    --env SERVER_PORT="$PORT" \
    --env TPS="$TPS" \
    --env DURATION="$DURATION" \
    --env TOKEN_IMAGE="$TOKEN_IMAGE" \
    --env EXTRA_DATA="$EXTRA_DATA" \
    ../k6/passive-liveness-load-test.js

echo ""
echo "✅ Load test completed!"
echo "📊 Results saved to results/ directory"
echo ""

# Show latest results
echo "📈 Latest test results:"
echo "======================"
LATEST_RESULT=$(ls -t ../results/k6-*summary.json 2>/dev/null | head -n1)
if [[ -f "$LATEST_RESULT" ]]; then
    echo "Results file: $LATEST_RESULT"
    
    # Extract key metrics using jq
    if command -v jq &> /dev/null; then
        echo ""
        echo "Key Metrics:"
        echo "------------"
        TOTAL_REQUESTS=$(jq -r '.metrics.http_reqs.values.count' "$LATEST_RESULT")
        REQUEST_RATE=$(jq -r '.metrics.http_reqs.values.rate' "$LATEST_RESULT")
        AVG_DURATION=$(jq -r '.metrics.http_req_duration.values.avg' "$LATEST_RESULT")
        P95_DURATION=$(jq -r '.metrics.http_req_duration.values["p(95)"]' "$LATEST_RESULT")
        ERROR_RATE=$(jq -r '.metrics.http_req_failed.values.rate' "$LATEST_RESULT")
        
        echo "Total Requests: $TOTAL_REQUESTS"
        echo "Request Rate: $(printf "%.2f" $REQUEST_RATE) req/s"
        echo "Avg Response Time: $(printf "%.2f" $AVG_DURATION) ms"
        echo "P95 Response Time: $(printf "%.2f" $P95_DURATION) ms"
        echo "Error Rate: $(printf "%.4f" $ERROR_RATE) ($(echo "$ERROR_RATE * 100" | bc -l | cut -c1-5)%)"
    fi
fi

echo ""
echo "💡 Tip: Open the HTML report in your browser for detailed visualization:"
LATEST_HTML=$(ls -t ../results/k6-*summary.html 2>/dev/null | head -n1)
if [[ -f "$LATEST_HTML" ]]; then
    echo "   $LATEST_HTML"
fi