#!/bin/bash

# Passive Liveness Load Test Script using curl
# Usage: ./curl-load-test.sh [TPS] [DURATION] [HOST] [PORT]

# Default parameters
TPS=${1:-5}
DURATION=${2:-300}
HOST=${3:-localhost}
PORT=${4:-8080}
ENDPOINT="/api/v1/selphid/passive-liveness/evaluate/token"
TEST_IMAGE_PATH="../test-data/sample-face.jpg"
RESULTS_DIR="../results"

echo "=== Passive Liveness Load Test ==="
echo "TPS: $TPS"
echo "Duration: ${DURATION}s"
echo "Target: http://$HOST:$PORT$ENDPOINT"
echo "================================"

# Create results directory if it doesn't exist
mkdir -p "$RESULTS_DIR"

# Result file name with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULT_FILE="$RESULTS_DIR/curl-loadtest-${TPS}tps-${TIMESTAMP}.log"
CSV_FILE="$RESULTS_DIR/curl-loadtest-${TPS}tps-${TIMESTAMP}.csv"

# Initialize CSV file
echo "timestamp,thread_id,response_code,response_time_ms,total_time_ms,size_bytes" > "$CSV_FILE"

# Check if test image exists
if [ ! -f "$TEST_IMAGE_PATH" ]; then
    echo "Warning: Test image not found at $TEST_IMAGE_PATH"
    echo "Using placeholder base64 data"
    IMAGE_B64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
else
    IMAGE_B64=$(base64 -i "$TEST_IMAGE_PATH" | tr -d '\n')
fi

# Function to make HTTP request
make_request() {
    local thread_id=$1
    local start_time=$(date +%s)
    local end_time=$((start_time + DURATION))
    local request_count=0
    
    echo "Thread $thread_id started" >> "$RESULT_FILE"
    
    while [ $(date +%s) -lt $end_time ]; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local req_start=$(date +%s%N)
        
        # Create JSON payload
        local json_payload=$(cat <<EOF
{
  "tokenImage": "$IMAGE_B64",
  "extraData": "curl-loadtest-${TPS}tps-thread-${thread_id}-$(date +%s)"
}
EOF
)
        
        # Make curl request and capture metrics
        local response=$(curl -s -w "%{http_code},%{time_total},%{size_download}" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d "$json_payload" \
            "http://$HOST:$PORT$ENDPOINT" 2>/dev/null)
        
        local req_end=$(date +%s%N)
        local response_time=$((($req_end - $req_start) / 1000000)) # Convert to milliseconds
        
        # Parse curl output
        local http_code=$(echo "$response" | tail -c 20 | cut -d',' -f1)
        local total_time=$(echo "$response" | tail -c 20 | cut -d',' -f2)
        local size_bytes=$(echo "$response" | tail -c 20 | cut -d',' -f3)
        
        # Convert total_time from seconds to milliseconds
        local total_time_ms=$(echo "$total_time * 1000" | bc -l | cut -d'.' -f1)
        
        # Log to CSV
        echo "$timestamp,$thread_id,$http_code,$response_time,$total_time_ms,$size_bytes" >> "$CSV_FILE"
        
        # Log summary to main log
        echo "[$timestamp] Thread:$thread_id Request:$((++request_count)) Code:$http_code Time:${total_time_ms}ms Size:${size_bytes}b" >> "$RESULT_FILE"
        
        # Wait 1 second to maintain 1 TPS per thread
        sleep 1
    done
    
    echo "Thread $thread_id completed $request_count requests" >> "$RESULT_FILE"
}

# Start background processes for each thread
echo "Starting $TPS concurrent threads..."
pids=()

for i in $(seq 1 $TPS); do
    make_request $i &
    pids+=($!)
    echo "Started thread $i (PID: $!)"
done

echo "All threads started. Test will run for ${DURATION} seconds..."
echo "Results will be saved to:"
echo "  - Log: $RESULT_FILE"
echo "  - CSV: $CSV_FILE"
echo ""
echo "Press Ctrl+C to stop the test early"

# Wait for all background processes to complete
for pid in "${pids[@]}"; do
    wait $pid
done

echo ""
echo "=== Test Completed ==="
echo "Generating summary report..."

# Generate summary report
SUMMARY_FILE="$RESULTS_DIR/curl-loadtest-${TPS}tps-${TIMESTAMP}-summary.txt"

cat > "$SUMMARY_FILE" << EOF
=== Load Test Summary ===
Test Configuration:
- TPS: $TPS
- Duration: ${DURATION}s
- Target: http://$HOST:$PORT$ENDPOINT
- Timestamp: $TIMESTAMP

Results Analysis:
EOF

# Count total requests, successful requests, failed requests
total_requests=$(tail -n +2 "$CSV_FILE" | wc -l)
successful_requests=$(tail -n +2 "$CSV_FILE" | awk -F',' '$3 == 200' | wc -l)
failed_requests=$((total_requests - successful_requests))

# Calculate response time statistics
if command -v awk &> /dev/null; then
    avg_response_time=$(tail -n +2 "$CSV_FILE" | awk -F',' '{sum+=$4; count++} END {if(count>0) print sum/count; else print 0}')
    min_response_time=$(tail -n +2 "$CSV_FILE" | awk -F',' 'BEGIN{min=999999} {if($4<min) min=$4} END {print min}')
    max_response_time=$(tail -n +2 "$CSV_FILE" | awk -F',' 'BEGIN{max=0} {if($4>max) max=$4} END {print max}')
else
    avg_response_time="N/A"
    min_response_time="N/A"
    max_response_time="N/A"
fi

cat >> "$SUMMARY_FILE" << EOF
- Total Requests: $total_requests
- Successful Requests (200 OK): $successful_requests
- Failed Requests: $failed_requests
- Success Rate: $(echo "scale=2; $successful_requests * 100 / $total_requests" | bc -l)%
- Average Response Time: ${avg_response_time} ms
- Min Response Time: ${min_response_time} ms
- Max Response Time: ${max_response_time} ms
- Actual TPS: $(echo "scale=2; $total_requests / $DURATION" | bc -l)

Files Generated:
- Detailed Log: $(basename "$RESULT_FILE")
- CSV Data: $(basename "$CSV_FILE")
- Summary: $(basename "$SUMMARY_FILE")

EOF

echo "Summary saved to: $SUMMARY_FILE"
echo ""
cat "$SUMMARY_FILE"