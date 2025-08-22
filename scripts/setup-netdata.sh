#!/bin/bash

# Netdata Setup Script for Load Testing
# This script installs and configures Netdata for optimal load testing monitoring

set -e

echo "🔧 Setting up Netdata for Load Testing Monitoring"
echo "=================================================="

# Check if running as root for system installation
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        echo "ℹ️  Running as root - will install system-wide"
        INSTALL_TYPE="system"
    else
        echo "ℹ️  Running as user - will install in home directory"
        INSTALL_TYPE="user"
    fi
}

# Install Netdata
install_netdata() {
    echo ""
    echo "📦 Installing Netdata..."
    
    if command -v netdata &> /dev/null; then
        echo "✅ Netdata is already installed"
        return 0
    fi
    
    # Detect OS and install accordingly
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS installation
        if command -v brew &> /dev/null; then
            echo "🍺 Installing via Homebrew..."
            brew install netdata
        else
            echo "❌ Homebrew not found. Please install Homebrew first:"
            echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux installation
        echo "🐧 Installing via Netdata installer..."
        bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait --disable-telemetry
    else
        echo "❌ Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

# Configure Netdata for load testing
configure_netdata() {
    echo ""
    echo "⚙️  Configuring Netdata for load testing..."
    
    # Find Netdata config directory
    if [[ "$OSTYPE" == "darwin"* ]]; then
        NETDATA_CONFIG_DIR="/usr/local/etc/netdata"
        NETDATA_LIB_DIR="/usr/local/var/lib/netdata"
    else
        NETDATA_CONFIG_DIR="/etc/netdata"
        NETDATA_LIB_DIR="/var/lib/netdata"
    fi
    
    # Backup original config if it exists
    if [[ -f "$NETDATA_CONFIG_DIR/netdata.conf" ]]; then
        echo "📄 Backing up original netdata.conf..."
        sudo cp "$NETDATA_CONFIG_DIR/netdata.conf" "$NETDATA_CONFIG_DIR/netdata.conf.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Copy our optimized configuration
    echo "📋 Installing optimized configuration..."
    sudo cp ../monitoring/netdata.conf "$NETDATA_CONFIG_DIR/netdata.conf"
    
    # Set proper permissions
    sudo chown netdata:netdata "$NETDATA_CONFIG_DIR/netdata.conf" 2>/dev/null || true
    sudo chmod 644 "$NETDATA_CONFIG_DIR/netdata.conf"
}

# Create Netdata dashboards for load testing
create_dashboards() {
    echo ""
    echo "📊 Creating load testing dashboards..."
    
    # Create custom dashboard directory
    DASHBOARD_DIR="../monitoring/dashboards"
    mkdir -p "$DASHBOARD_DIR"
    
    # Create load testing overview dashboard
    cat > "$DASHBOARD_DIR/load-test-overview.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Load Testing Dashboard</title>
    <script src="http://localhost:19999/dashboard.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #1e1e1e; color: white; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 20px; }
        .chart-container { background: #2a2a2a; padding: 15px; border-radius: 8px; }
        .chart-title { font-size: 16px; font-weight: bold; margin-bottom: 10px; color: #4CAF50; }
        h1 { text-align: center; color: #2196F3; margin-bottom: 30px; }
    </style>
</head>
<body>
    <h1>🚀 K6 Load Testing - Real-time Monitoring Dashboard</h1>
    
    <div class="grid">
        <!-- System Load -->
        <div class="chart-container">
            <div class="chart-title">System Load Average</div>
            <div data-netdata="system.load" data-height="200px" data-chart-library="dygraph"></div>
        </div>
        
        <!-- CPU Usage -->
        <div class="chart-container">
            <div class="chart-title">CPU Usage</div>
            <div data-netdata="system.cpu" data-height="200px" data-chart-library="dygraph"></div>
        </div>
        
        <!-- Memory Usage -->
        <div class="chart-container">
            <div class="chart-title">Memory Usage</div>
            <div data-netdata="system.ram" data-height="200px" data-chart-library="dygraph"></div>
        </div>
        
        <!-- Network Traffic -->
        <div class="chart-container">
            <div class="chart-title">Network Traffic</div>
            <div data-netdata="system.net" data-height="200px" data-chart-library="dygraph"></div>
        </div>
        
        <!-- Disk I/O -->
        <div class="chart-container">
            <div class="chart-title">Disk I/O</div>
            <div data-netdata="system.io" data-height="200px" data-chart-library="dygraph"></div>
        </div>
        
        <!-- TCP Connections -->
        <div class="chart-container">
            <div class="chart-title">TCP Connections</div>
            <div data-netdata="netstat.tcpsock" data-height="200px" data-chart-library="dygraph"></div>
        </div>
        
        <!-- Process CPU -->
        <div class="chart-container">
            <div class="chart-title">Top Processes (CPU)</div>
            <div data-netdata="apps.cpu" data-height="200px" data-chart-library="dygraph"></div>
        </div>
        
        <!-- Process Memory -->
        <div class="chart-container">
            <div class="chart-title">Top Processes (Memory)</div>
            <div data-netdata="apps.mem" data-height="200px" data-chart-library="dygraph"></div>
        </div>
    </div>
    
    <script>
        // Auto-refresh every 5 seconds
        setInterval(function() {
            NETDATA.updatedAll();
        }, 5000);
    </script>
</body>
</html>
EOF

    echo "✅ Dashboard created: $DASHBOARD_DIR/load-test-overview.html"
}

# Start/restart Netdata service
start_netdata() {
    echo ""
    echo "🚀 Starting Netdata service..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - using brew services
        if brew services list | grep -q "netdata.*started"; then
            echo "🔄 Restarting Netdata service..."
            brew services restart netdata
        else
            echo "▶️  Starting Netdata service..."
            brew services start netdata
        fi
    else
        # Linux - using systemctl
        if systemctl is-active --quiet netdata; then
            echo "🔄 Restarting Netdata service..."
            sudo systemctl restart netdata
        else
            echo "▶️  Starting Netdata service..."
            sudo systemctl start netdata
            sudo systemctl enable netdata
        fi
    fi
    
    # Wait for service to start
    echo "⏳ Waiting for Netdata to start..."
    for i in {1..30}; do
        if curl -s http://localhost:19999/api/v1/info > /dev/null 2>&1; then
            echo "✅ Netdata is running!"
            break
        fi
        sleep 1
        if [[ $i -eq 30 ]]; then
            echo "❌ Timeout waiting for Netdata to start"
            exit 1
        fi
    done
}

# Main execution
main() {
    check_permissions
    install_netdata
    configure_netdata
    create_dashboards
    start_netdata
    
    echo ""
    echo "🎉 Netdata setup completed successfully!"
    echo "========================================"
    echo ""
    echo "📊 Access points:"
    echo "   Main Dashboard: http://localhost:19999"
    echo "   Load Test Dashboard: file://$(pwd)/../monitoring/dashboards/load-test-overview.html"
    echo ""
    echo "💡 Usage tips:"
    echo "   1. Open the load test dashboard in your browser before starting tests"
    echo "   2. Run your K6 tests with: ./run-k6-tests.sh [TPS] [DURATION]"
    echo "   3. Monitor real-time metrics during test execution"
    echo "   4. Analyze post-test data for performance insights"
    echo ""
    echo "🔧 Configuration file: $NETDATA_CONFIG_DIR/netdata.conf"
    echo "📁 Dashboard files: $(pwd)/../monitoring/dashboards/"
}

# Run main function
main "$@"