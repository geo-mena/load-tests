#!/bin/bash

# Resource Monitoring Script for Load Tests
# Monitors RAM, CPU, Disk I/O during load testing
# Usage: ./monitor-resources.sh [DURATION] [INTERVAL] [OUTPUT_PREFIX]

DURATION=${1:-300}  # Test duration in seconds
INTERVAL=${2:-5}    # Monitoring interval in seconds
OUTPUT_PREFIX=${3:-"resource-monitor"}
RESULTS_DIR="../results"

echo "=== Resource Monitoring Setup ==="
echo "Duration: ${DURATION}s"
echo "Interval: ${INTERVAL}s"
echo "Output prefix: $OUTPUT_PREFIX"
echo "================================"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Generate timestamp for unique filenames
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BASE_NAME="${OUTPUT_PREFIX}-${TIMESTAMP}"

# Output files
CPU_FILE="$RESULTS_DIR/${BASE_NAME}-cpu.log"
MEMORY_FILE="$RESULTS_DIR/${BASE_NAME}-memory.log"
DISK_FILE="$RESULTS_DIR/${BASE_NAME}-disk.log"
NETWORK_FILE="$RESULTS_DIR/${BASE_NAME}-network.log"
PROCESS_FILE="$RESULTS_DIR/${BASE_NAME}-processes.log"
SUMMARY_FILE="$RESULTS_DIR/${BASE_NAME}-summary.txt"

# Initialize log files with headers
echo "timestamp,cpu_user,cpu_system,cpu_idle,cpu_iowait,load_1m,load_5m,load_15m" > "$CPU_FILE"
echo "timestamp,mem_total_mb,mem_used_mb,mem_free_mb,mem_available_mb,mem_usage_percent,swap_total_mb,swap_used_mb,swap_free_mb" > "$MEMORY_FILE"
echo "timestamp,disk_read_kb_s,disk_write_kb_s,disk_read_ops_s,disk_write_ops_s,disk_util_percent" > "$DISK_FILE"
echo "timestamp,network_rx_kb_s,network_tx_kb_s,network_rx_packets_s,network_tx_packets_s" > "$NETWORK_FILE"
echo "timestamp,java_processes,java_cpu_percent,java_memory_mb" > "$PROCESS_FILE"

echo "Monitoring started. Files:"
echo "  CPU: $CPU_FILE"
echo "  Memory: $MEMORY_FILE"
echo "  Disk: $DISK_FILE"
echo "  Network: $NETWORK_FILE"
echo "  Processes: $PROCESS_FILE"
echo ""
echo "Press Ctrl+C to stop monitoring early"

# Function to monitor CPU
monitor_cpu() {
    while [ $SECONDS -lt $DURATION ]; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Get CPU stats from /proc/stat
        local cpu_stats=$(awk '/^cpu / {print $2,$3,$4,$5}' /proc/stat)
        local load_stats=$(uptime | awk '{print $(NF-2),$(NF-1),$NF}' | tr ',' ' ')
        
        # Calculate CPU percentages (simplified)
        local cpu_line=$(sar 1 1 | grep "Average" | grep -v "CPU")
        if [ -n "$cpu_line" ]; then
            local cpu_user=$(echo "$cpu_line" | awk '{print $3}')
            local cpu_system=$(echo "$cpu_line" | awk '{print $5}')
            local cpu_idle=$(echo "$cpu_line" | awk '{print $8}')
            local cpu_iowait=$(echo "$cpu_line" | awk '{print $6}')
        else
            # Fallback if sar is not available
            cpu_user="0"
            cpu_system="0" 
            cpu_idle="100"
            cpu_iowait="0"
        fi
        
        echo "$timestamp,$cpu_user,$cpu_system,$cpu_idle,$cpu_iowait,$load_stats" >> "$CPU_FILE"
        sleep $INTERVAL
    done
}

# Function to monitor memory
monitor_memory() {
    while [ $SECONDS -lt $DURATION ]; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Parse /proc/meminfo
        local mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
        local mem_free=$(awk '/MemFree/ {print int($2/1024)}' /proc/meminfo)
        local mem_available=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
        local mem_used=$((mem_total - mem_available))
        local mem_usage_percent=$(echo "scale=2; $mem_used * 100 / $mem_total" | bc -l)
        
        local swap_total=$(awk '/SwapTotal/ {print int($2/1024)}' /proc/meminfo)
        local swap_free=$(awk '/SwapFree/ {print int($2/1024)}' /proc/meminfo)
        local swap_used=$((swap_total - swap_free))
        
        echo "$timestamp,$mem_total,$mem_used,$mem_free,$mem_available,$mem_usage_percent,$swap_total,$swap_used,$swap_free" >> "$MEMORY_FILE"
        sleep $INTERVAL
    done
}

# Function to monitor disk I/O
monitor_disk() {
    local prev_stats=""
    while [ $SECONDS -lt $DURATION ]; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Get disk stats using iostat if available
        if command -v iostat &> /dev/null; then
            local disk_stats=$(iostat -dx 1 1 | grep -E "sd[a-z]|nvme|xvd" | head -1)
            if [ -n "$disk_stats" ]; then
                local read_kb_s=$(echo "$disk_stats" | awk '{print $6}')
                local write_kb_s=$(echo "$disk_stats" | awk '{print $7}')
                local read_ops_s=$(echo "$disk_stats" | awk '{print $4}')
                local write_ops_s=$(echo "$disk_stats" | awk '{print $5}')
                local util_percent=$(echo "$disk_stats" | awk '{print $10}')
            else
                read_kb_s="0"; write_kb_s="0"; read_ops_s="0"; write_ops_s="0"; util_percent="0"
            fi
        else
            # Fallback if iostat not available
            read_kb_s="N/A"; write_kb_s="N/A"; read_ops_s="N/A"; write_ops_s="N/A"; util_percent="N/A"
        fi
        
        echo "$timestamp,$read_kb_s,$write_kb_s,$read_ops_s,$write_ops_s,$util_percent" >> "$DISK_FILE"
        sleep $INTERVAL
    done
}

# Function to monitor network
monitor_network() {
    while [ $SECONDS -lt $DURATION ]; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Get network stats from /proc/net/dev
        local net_stats=$(awk '/eth0|ens|enp|wlan/ {print $2,$3,$10,$11}' /proc/net/dev | head -1)
        if [ -n "$net_stats" ]; then
            # This is cumulative, would need calculation for per-second rates
            local rx_bytes=$(echo "$net_stats" | awk '{print $1}')
            local rx_packets=$(echo "$net_stats" | awk '{print $2}')
            local tx_bytes=$(echo "$net_stats" | awk '{print $3}')
            local tx_packets=$(echo "$net_stats" | awk '{print $4}')
            
            # Convert to KB/s (simplified, not calculating actual rate)
            local rx_kb_s=$(echo "scale=2; $rx_bytes / 1024" | bc -l)
            local tx_kb_s=$(echo "scale=2; $tx_bytes / 1024" | bc -l)
        else
            rx_kb_s="0"; tx_kb_s="0"; rx_packets="0"; tx_packets="0"
        fi
        
        echo "$timestamp,$rx_kb_s,$tx_kb_s,$rx_packets,$tx_packets" >> "$NETWORK_FILE"
        sleep $INTERVAL
    done
}

# Function to monitor Java processes
monitor_processes() {
    while [ $SECONDS -lt $DURATION ]; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Count Java processes and get their resource usage
        local java_count=$(pgrep -c java || echo "0")
        
        if [ $java_count -gt 0 ]; then
            # Get CPU and memory usage of Java processes
            local java_stats=$(ps -eo pid,pcpu,pmem,comm | grep java | head -1)
            if [ -n "$java_stats" ]; then
                local java_cpu=$(echo "$java_stats" | awk '{sum+=$2} END {print sum}')
                local java_mem_percent=$(echo "$java_stats" | awk '{sum+=$3} END {print sum}')
                # Convert memory percentage to MB (approximate)
                local total_mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
                local java_mem_mb=$(echo "scale=0; $total_mem_mb * $java_mem_percent / 100" | bc -l)
            else
                java_cpu="0"; java_mem_mb="0"
            fi
        else
            java_cpu="0"; java_mem_mb="0"
        fi
        
        echo "$timestamp,$java_count,$java_cpu,$java_mem_mb" >> "$PROCESS_FILE"
        sleep $INTERVAL
    done
}

# Start monitoring functions in background
SECONDS=0
monitor_cpu &
CPU_PID=$!

monitor_memory &
MEMORY_PID=$!

monitor_disk &
DISK_PID=$!

monitor_network &
NETWORK_PID=$!

monitor_processes &
PROCESS_PID=$!

# Wait for monitoring to complete or handle Ctrl+C
trap 'kill $CPU_PID $MEMORY_PID $DISK_PID $NETWORK_PID $PROCESS_PID 2>/dev/null; echo "Monitoring stopped"; exit 0' INT

echo "Monitoring in progress... (${DURATION}s remaining)"
sleep $DURATION

# Kill monitoring processes
kill $CPU_PID $MEMORY_PID $DISK_PID $NETWORK_PID $PROCESS_PID 2>/dev/null

# Generate summary report
echo "=== Resource Monitoring Summary ===" > "$SUMMARY_FILE"
echo "Test Duration: ${DURATION}s" >> "$SUMMARY_FILE"
echo "Monitoring Interval: ${INTERVAL}s" >> "$SUMMARY_FILE"
echo "Timestamp: $TIMESTAMP" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# Calculate basic statistics if possible
if command -v awk &> /dev/null; then
    echo "Memory Statistics:" >> "$SUMMARY_FILE"
    local max_mem=$(tail -n +2 "$MEMORY_FILE" | awk -F',' 'BEGIN{max=0} {if($3>max) max=$3} END {print max}')
    local avg_mem=$(tail -n +2 "$MEMORY_FILE" | awk -F',' '{sum+=$3; count++} END {if(count>0) print sum/count; else print 0}')
    echo "  Max Memory Used: ${max_mem} MB" >> "$SUMMARY_FILE"
    echo "  Avg Memory Used: ${avg_mem} MB" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"
    
    echo "Java Process Statistics:" >> "$SUMMARY_FILE"
    local max_java_mem=$(tail -n +2 "$PROCESS_FILE" | awk -F',' 'BEGIN{max=0} {if($4>max) max=$4} END {print max}')
    local avg_java_cpu=$(tail -n +2 "$PROCESS_FILE" | awk -F',' '{sum+=$3; count++} END {if(count>0) print sum/count; else print 0}')
    echo "  Max Java Memory: ${max_java_mem} MB" >> "$SUMMARY_FILE"
    echo "  Avg Java CPU: ${avg_java_cpu}%" >> "$SUMMARY_FILE"
fi

echo "" >> "$SUMMARY_FILE"
echo "Generated Files:" >> "$SUMMARY_FILE"
echo "  CPU: $(basename "$CPU_FILE")" >> "$SUMMARY_FILE"
echo "  Memory: $(basename "$MEMORY_FILE")" >> "$SUMMARY_FILE"
echo "  Disk: $(basename "$DISK_FILE")" >> "$SUMMARY_FILE"
echo "  Network: $(basename "$NETWORK_FILE")" >> "$SUMMARY_FILE"
echo "  Processes: $(basename "$PROCESS_FILE")" >> "$SUMMARY_FILE"

echo ""
echo "=== Monitoring Complete ==="
echo "Summary saved to: $SUMMARY_FILE"
echo ""
echo "To analyze results:"
echo "  - Use spreadsheet software to open CSV files"
echo "  - Plot graphs using the timestamp column"
echo "  - Focus on memory usage during peak load periods"