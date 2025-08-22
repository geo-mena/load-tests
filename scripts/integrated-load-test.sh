#!/bin/bash

# Integrated Load Testing Script with K6 + Netdata
# This script orchestrates the complete load testing workflow
# Usage: ./integrated-load-test.sh [TPS] [DURATION] [HOST] [PORT]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Utility functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check K6
    if ! command -v k6 &> /dev/null; then
        log_error "K6 is not installed. Please install it first:"
        echo "   macOS: brew install k6"
        echo "   Linux: sudo apt-get install k6"
        exit 1
    fi
    
    # Check Netdata
    if ! curl -s http://localhost:19999/api/v1/info > /dev/null 2>&1; then
        log_warning "Netdata is not running. Starting setup..."
        ./setup-netdata.sh
    else
        log_success "Netdata is running"
    fi
    
    # Check jq for JSON processing
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed. Some features may be limited."
        echo "   Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    fi
    
    # Check server connectivity
    log_info "Checking server connectivity..."
    if ! curl -s -f "http://${HOST}:${PORT}/api/v1/selphid/health" > /dev/null; then
        log_warning "Cannot connect to server at http://${HOST}:${PORT}"
        echo "   Make sure the SelphId server is running"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "Server is accessible"
    fi
}

# Prepare test environment
prepare_environment() {
    log_info "Preparing test environment..."
    
    # Create results directory
    mkdir -p ../results
    
    # Prepare payload file
    PAYLOAD_FILE_ABSOLUTE=$(realpath "$DEFAULT_PAYLOAD_FILE" 2>/dev/null || echo "$DEFAULT_PAYLOAD_FILE")
    
    if [[ -f "$DEFAULT_PAYLOAD_FILE" ]]; then
        if jq . "$DEFAULT_PAYLOAD_FILE" > /dev/null 2>&1; then
            EXTRA_DATA=$(jq -r '.extraData' "$DEFAULT_PAYLOAD_FILE" 2>/dev/null || echo "k6-integrated-test")
            log_success "Loaded payload from $DEFAULT_PAYLOAD_FILE"
        else
            log_error "Invalid JSON in payload file: $DEFAULT_PAYLOAD_FILE"
            exit 1
        fi
    else
        log_warning "Payload file not found: $DEFAULT_PAYLOAD_FILE"
        log_info "Creating default payload file..."
        
        mkdir -p "$(dirname "$DEFAULT_PAYLOAD_FILE")"
        cat > "$DEFAULT_PAYLOAD_FILE" << EOF
{
  "tokenImage": "BASE64_ENCODED_IMAGE_HERE",
  "extraData": "k6-integrated-test-default"
}
EOF
        EXTRA_DATA="k6-integrated-test-default"
        PAYLOAD_FILE_ABSOLUTE=$(realpath "$DEFAULT_PAYLOAD_FILE")
        log_success "Created default payload file"
    fi
    
    # Generate test session ID
    TEST_SESSION_ID="test_$(date +%Y%m%d_%H%M%S)_${TPS}tps"
    
    log_success "Test session: $TEST_SESSION_ID"
}

# Start monitoring
start_monitoring() {
    log_info "Starting enhanced monitoring..."
    
    # Create monitoring log directory
    MONITOR_DIR="../results/${TEST_SESSION_ID}_monitoring"
    mkdir -p "$MONITOR_DIR"
    
    # Start system resource monitoring
    (
        echo "timestamp,cpu_percent,memory_percent,disk_io_read,disk_io_write,network_rx,network_tx" > "$MONITOR_DIR/system_metrics.csv"
        while true; do
            TIMESTAMP=$(date -Iseconds)
            CPU_PERCENT=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' 2>/dev/null || echo "0")
            MEMORY_PERCENT=$(vm_stat | awk '/^Pages active/ {active=$3} /^Pages free/ {free=$3} /^Pages wired/ {wired=$3} END {total=active+free+wired; if(total>0) print (active+wired)*100/total; else print 0}' 2>/dev/null || echo "0")
            
            echo "$TIMESTAMP,$CPU_PERCENT,$MEMORY_PERCENT,0,0,0,0" >> "$MONITOR_DIR/system_metrics.csv"
            sleep 5
        done
    ) &
    MONITOR_PID=$!
    
    log_success "System monitoring started (PID: $MONITOR_PID)"
    echo $MONITOR_PID > "$MONITOR_DIR/monitor.pid"
}

# Stop monitoring
stop_monitoring() {
    log_info "Stopping monitoring..."
    
    if [[ -f "$MONITOR_DIR/monitor.pid" ]]; then
        MONITOR_PID=$(cat "$MONITOR_DIR/monitor.pid")
        if kill $MONITOR_PID 2>/dev/null; then
            log_success "Monitoring stopped"
        fi
        rm -f "$MONITOR_DIR/monitor.pid"
    fi
}

# Run K6 load test
run_load_test() {
    log_info "Starting K6 load test..."
    
    # Display test configuration
    echo ""
    echo "🚀 Load Test Configuration"
    echo "=========================="
    echo "Target TPS: $TPS"
    echo "Duration: $DURATION"
    echo "Server: http://${HOST}:${PORT}"
    echo "Test Session: $TEST_SESSION_ID"
    echo "Monitor Directory: $MONITOR_DIR"
    echo ""
    
    # Run K6 test with enhanced output
    k6 run \
        --env SERVER_HOST="$HOST" \
        --env SERVER_PORT="$PORT" \
        --env TPS="$TPS" \
        --env DURATION="$DURATION" \
        --env PAYLOAD_FILE="$PAYLOAD_FILE_ABSOLUTE" \
        --env EXTRA_DATA="$EXTRA_DATA" \
        --out json="../results/${TEST_SESSION_ID}_k6_metrics.json" \
        ../k6/passive-liveness-load-test.js
    
    log_success "Load test completed"
}

# Generate comprehensive report
generate_report() {
    log_info "Generating comprehensive test report..."
    
    REPORT_FILE="../results/${TEST_SESSION_ID}_report.html"
    
    cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Load Test Report - $TEST_SESSION_ID</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }
        .metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric-card { background: #f8f9fa; border: 1px solid #e9ecef; border-radius: 8px; padding: 20px; }
        .metric-title { font-size: 14px; color: #6c757d; margin-bottom: 5px; }
        .metric-value { font-size: 24px; font-weight: bold; color: #2c3e50; }
        .metric-unit { font-size: 14px; color: #6c757d; }
        .section { margin: 30px 0; }
        .section-title { font-size: 20px; font-weight: bold; margin-bottom: 15px; color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 5px; }
        .status-good { color: #27ae60; }
        .status-warning { color: #f39c12; }
        .status-error { color: #e74c3c; }
        .links { background: #e8f4f8; padding: 20px; border-radius: 8px; }
        .links a { color: #2980b9; text-decoration: none; margin-right: 20px; }
        .links a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Load Test Report</h1>
            <p><strong>Session ID:</strong> $TEST_SESSION_ID</p>
            <p><strong>Generated:</strong> $(date)</p>
            <p><strong>Configuration:</strong> $TPS TPS for $DURATION on http://${HOST}:${PORT}</p>
        </div>
        
        <div class="section">
            <div class="section-title">📊 Performance Metrics</div>
            <div class="metric-grid">
                <div class="metric-card">
                    <div class="metric-title">Target TPS</div>
                    <div class="metric-value">$TPS <span class="metric-unit">req/s</span></div>
                </div>
                <div class="metric-card">
                    <div class="metric-title">Test Duration</div>
                    <div class="metric-value">$DURATION</div>
                </div>
                <div class="metric-card">
                    <div class="metric-title">Server</div>
                    <div class="metric-value">$HOST:$PORT</div>
                </div>
                <div class="metric-card">
                    <div class="metric-title">Test Status</div>
                    <div class="metric-value status-good">✅ Completed</div>
                </div>
            </div>
        </div>
        
        <div class="section">
            <div class="section-title">📁 Generated Files</div>
            <ul>
                <li>K6 Metrics: ${TEST_SESSION_ID}_k6_metrics.json</li>
                <li>System Monitoring: ${TEST_SESSION_ID}_monitoring/</li>
                <li>HTML Reports: Check results/ directory for K6 HTML reports</li>
                <li>This Report: ${TEST_SESSION_ID}_report.html</li>
            </ul>
        </div>
        
        <div class="section">
            <div class="section-title">🔗 Quick Links</div>
            <div class="links">
                <a href="http://localhost:19999" target="_blank">📊 Netdata Dashboard</a>
                <a href="file://$(pwd)/../monitoring/dashboards/load-test-overview.html" target="_blank">📈 Load Test Dashboard</a>
                <a href="file://$(pwd)/../results" target="_blank">📁 All Results</a>
            </div>
        </div>
        
        <div class="section">
            <div class="section-title">💡 Next Steps</div>
            <ul>
                <li>Review K6 HTML reports for detailed performance analysis</li>
                <li>Check Netdata dashboard for system resource analysis</li>
                <li>Compare results with previous test sessions</li>
                <li>Adjust TPS or duration for follow-up tests</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF

    log_success "Report generated: $REPORT_FILE"
}

# Open results in browser
open_results() {
    log_info "Opening results..."
    
    # Try to find and open the latest K6 HTML report
    LATEST_K6_HTML=$(ls -t ../results/k6-*summary.html 2>/dev/null | head -n1)
    if [[ -f "$LATEST_K6_HTML" ]]; then
        if command -v open &> /dev/null; then
            open "$LATEST_K6_HTML"
        elif command -v xdg-open &> /dev/null; then
            xdg-open "$LATEST_K6_HTML"
        fi
    fi
    
    # Open the comprehensive report
    if [[ -f "$REPORT_FILE" ]]; then
        if command -v open &> /dev/null; then
            open "$REPORT_FILE"
        elif command -v xdg-open &> /dev/null; then
            xdg-open "$REPORT_FILE"
        fi
    fi
    
    log_success "Results opened in browser"
}

# Cleanup function
cleanup() {
    log_info "Performing cleanup..."
    stop_monitoring
}

# Trap cleanup on exit
trap cleanup EXIT

# Main execution flow
main() {
    echo ""
    echo "🎯 Integrated K6 + Netdata Load Testing"
    echo "========================================"
    echo ""
    
    check_prerequisites
    prepare_environment
    start_monitoring
    
    # Small delay to ensure monitoring is ready
    sleep 2
    
    run_load_test
    generate_report
    
    echo ""
    log_success "Load testing session completed!"
    echo ""
    echo "📊 Results Summary:"
    echo "   Session ID: $TEST_SESSION_ID"
    echo "   Report: $REPORT_FILE"
    echo "   Monitoring Data: $MONITOR_DIR"
    echo ""
    
    # Ask if user wants to open results
    read -p "Open results in browser? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        open_results
    fi
    
    echo ""
    log_success "Integration completed successfully! 🎉"
}

# Run main function
main "$@"