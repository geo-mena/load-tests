#!/bin/bash

# Passive Liveness Load Test using wrk (high-performance HTTP benchmarking tool)
# Usage: ./wrk-load-test.sh [TPS] [DURATION] [HOST] [PORT]
# Note: Requires wrk to be installed (https://github.com/wg/wrk)

# Default parameters
TPS=${1:-5}
DURATION=${2:-300}
HOST=${3:-localhost}
PORT=${4:-8080}
ENDPOINT="/api/v1/selphid/passive-liveness/evaluate/token"
TEST_IMAGE_PATH="../test-data/sample-face.jpg"
RESULTS_DIR="../results"

echo "=== Passive Liveness Load Test with wrk ==="
echo "TPS: $TPS"
echo "Duration: ${DURATION}s"
echo "Target: http://$HOST:$PORT$ENDPOINT"
echo "========================================"

# Check if wrk is installed
if ! command -v wrk &> /dev/null; then
    echo "Error: wrk is not installed"
    echo "Install wrk from: https://github.com/wg/wrk"
    echo "Ubuntu/Debian: sudo apt-get install wrk"
    echo "macOS: brew install wrk"
    exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

# Generate Lua script for wrk
LUA_SCRIPT="/tmp/passive-liveness-wrk.lua"

# Check if test image exists
if [ ! -f "$TEST_IMAGE_PATH" ]; then
    echo "Warning: Test image not found at $TEST_IMAGE_PATH"
    echo "Using placeholder base64 data"
    IMAGE_B64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
else
    IMAGE_B64=$(base64 -i "$TEST_IMAGE_PATH" | tr -d '\n')
fi

cat > "$LUA_SCRIPT" << EOF
-- wrk Lua script for Passive Liveness Load Test

wrk.method = "POST"
wrk.headers["Content-Type"] = "application/json"
wrk.headers["Accept"] = "application/json"

local counter = 0

request = function()
    counter = counter + 1
    local body = string.format([[{
        "tokenImage": "$IMAGE_B64",
        "extraData": "wrk-loadtest-${TPS}tps-req-%d-time-%d"
    }]], counter, os.time())
    
    wrk.body = body
    return wrk.format(nil, nil, nil, body)
end

response = function(status, headers, body)
    if status ~= 200 then
        print("Error response: " .. status)
    end
end

done = function(summary, latency, requests)
    print("========================================")
    print("wrk Load Test Results Summary")
    print("========================================")
    print(string.format("Requests/sec: %.2f", summary.requests / (summary.duration / 1000000)))
    print(string.format("Transfer/sec: %.2f KB", (summary.bytes / 1024) / (summary.duration / 1000000)))
    print(string.format("Total Requests: %d", summary.requests))
    print(string.format("Total Errors: %d", summary.errors.connect + summary.errors.read + summary.errors.write + summary.errors.status + summary.errors.timeout))
    print(string.format("Duration: %.2fs", summary.duration / 1000000))
    print("Latency Distribution:")
    print(string.format("  50th percentile: %.2fms", latency:percentile(50)))
    print(string.format("  75th percentile: %.2fms", latency:percentile(75)))
    print(string.format("  90th percentile: %.2fms", latency:percentile(90)))
    print(string.format("  99th percentile: %.2fms", latency:percentile(99)))
    print(string.format("  Max latency: %.2fms", latency.max / 1000))
end
EOF

# Calculate threads and connections for target TPS
# wrk uses threads and connections to generate load
# For moderate TPS, use fewer threads but more connections per thread
THREADS=$(( (TPS + 9) / 10 ))  # 1 thread per 10 TPS, minimum 1
if [ $THREADS -lt 1 ]; then
    THREADS=1
fi
if [ $THREADS -gt 12 ]; then
    THREADS=12  # Limit threads to reasonable number
fi

CONNECTIONS=$TPS

echo "Using $THREADS threads and $CONNECTIONS connections"

# Result file with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULT_FILE="$RESULTS_DIR/wrk-loadtest-${TPS}tps-${TIMESTAMP}.txt"

echo "Starting wrk load test..."
echo "Results will be saved to: $RESULT_FILE"

# Run wrk and capture output
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s \
    --rate $TPS \
    --latency \
    -s "$LUA_SCRIPT" \
    "http://$HOST:$PORT$ENDPOINT" 2>&1 | tee "$RESULT_FILE"

# Clean up temporary Lua script
rm -f "$LUA_SCRIPT"

echo ""
echo "=== Test Completed ==="
echo "Results saved to: $RESULT_FILE"