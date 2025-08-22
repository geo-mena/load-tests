#!/bin/bash

# Netdata Setup Script for Load Testing - Linux Only
# This script installs and configures Netdata for optimal load testing monitoring on Linux systems

set -e

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "❌ This script is designed for Linux only."
    echo "   Current OS: $OSTYPE"
    echo "   For other operating systems, please install Netdata manually."
    exit 1
fi

echo "🔧 Setting up Netdata for Load Testing Monitoring (Linux)"
echo "========================================================="

# Check Linux distribution and prerequisites
check_system() {
    echo "ℹ️  Checking Linux system..."
    
    # Detect Linux distribution
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        echo "   Distribution: $PRETTY_NAME"
    else
        echo "⚠️  Cannot detect Linux distribution"
        DISTRO="unknown"
    fi
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo "ℹ️  Running as root - will install system-wide"
        INSTALL_TYPE="system"
    else
        echo "ℹ️  Running as user - may need sudo for installation"
        INSTALL_TYPE="user"
    fi
    
    # Check required tools
    local missing_tools=()
    for tool in curl wget; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "❌ Missing required tools: ${missing_tools[*]}"
        echo "   Please install them first:"
        case $DISTRO in
            ubuntu|debian)
                echo "   sudo apt-get update && sudo apt-get install -y ${missing_tools[*]}"
                ;;
            centos|rhel|fedora)
                echo "   sudo yum install -y ${missing_tools[*]}"  # or dnf for newer versions
                ;;
            *)
                echo "   Install using your distribution's package manager"
                ;;
        esac
        exit 1
    fi
}

# Install Netdata on Linux
install_netdata() {
    echo ""
    echo "📦 Installing Netdata on Linux..."
    
    if command -v netdata &> /dev/null; then
        echo "✅ Netdata is already installed"
        NETDATA_VERSION=$(netdata -V 2>&1 | head -n1 || echo "unknown")
        echo "   Version: $NETDATA_VERSION"
        return 0
    fi
    
    # Try package manager first for better integration
    case $DISTRO in
        ubuntu|debian)
            echo "🐧 Attempting installation via apt..."
            if install_via_apt; then
                return 0
            else
                echo "⚠️  Package manager installation failed, trying official installer..."
            fi
            ;;
        centos|rhel|fedora)
            echo "🐧 Attempting installation via yum/dnf..."
            if install_via_yum; then
                return 0
            else
                echo "⚠️  Package manager installation failed, trying official installer..."
            fi
            ;;
        *)
            echo "🐧 Unknown distribution, using official installer..."
            ;;
    esac
    
    # Fallback to official Netdata installer
    echo "🌐 Installing via official Netdata installer..."
    if ! bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait --disable-telemetry --claim-token "" --claim-rooms "" --claim-url "https://app.netdata.cloud"; then
        echo "❌ Netdata installation failed"
        exit 1
    fi
    
    echo "✅ Netdata installed successfully"
}

# Install via apt (Ubuntu/Debian)
install_via_apt() {
    if sudo apt-get update && sudo apt-get install -y netdata; then
        return 0
    fi
    return 1
}

# Install via yum/dnf (CentOS/RHEL/Fedora)
install_via_yum() {
    # Try dnf first (newer systems), then yum
    if command -v dnf &> /dev/null; then
        if sudo dnf install -y netdata; then
            return 0
        fi
    elif command -v yum &> /dev/null; then
        if sudo yum install -y netdata; then
            return 0
        fi
    fi
    return 1
}

# Configure Netdata for load testing
configure_netdata() {
    echo ""
    echo "⚙️  Configuring Netdata for load testing..."
    
    # Standard Linux paths
    NETDATA_CONFIG_DIR="/etc/netdata"
    NETDATA_LIB_DIR="/var/lib/netdata"
    NETDATA_LOG_DIR="/var/log/netdata"
    
    # Create config directory if it doesn't exist
    if [[ ! -d "$NETDATA_CONFIG_DIR" ]]; then
        echo "📁 Creating Netdata config directory..."
        sudo mkdir -p "$NETDATA_CONFIG_DIR"
    fi
    
    # Backup original config if it exists
    if [[ -f "$NETDATA_CONFIG_DIR/netdata.conf" ]]; then
        echo "📄 Backing up original netdata.conf..."
        sudo cp "$NETDATA_CONFIG_DIR/netdata.conf" "$NETDATA_CONFIG_DIR/netdata.conf.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Copy our optimized configuration
    echo "📋 Installing optimized configuration..."
    if [[ ! -f "../monitoring/netdata.conf" ]]; then
        echo "❌ Configuration file not found: ../monitoring/netdata.conf"
        exit 1
    fi
    
    sudo cp "../monitoring/netdata.conf" "$NETDATA_CONFIG_DIR/netdata.conf"
    
    # Set proper permissions
    sudo chown netdata:netdata "$NETDATA_CONFIG_DIR/netdata.conf" 2>/dev/null || {
        echo "⚠️  Warning: Could not set netdata user ownership (user may not exist yet)"
        sudo chown root:root "$NETDATA_CONFIG_DIR/netdata.conf"
    }
    sudo chmod 644 "$NETDATA_CONFIG_DIR/netdata.conf"
    
    # Ensure log directory exists and has proper permissions
    if [[ ! -d "$NETDATA_LOG_DIR" ]]; then
        sudo mkdir -p "$NETDATA_LOG_DIR"
        sudo chown netdata:netdata "$NETDATA_LOG_DIR" 2>/dev/null || sudo chown root:root "$NETDATA_LOG_DIR"
    fi
    
    echo "✅ Netdata configuration installed"
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

# Start/restart Netdata service on Linux
start_netdata() {
    echo ""
    echo "🚀 Managing Netdata service..."
    
    # Check if systemd is available
    if command -v systemctl &> /dev/null; then
        # Modern Linux with systemd
        echo "🔧 Using systemctl to manage Netdata service..."
        
        # Enable the service to start on boot
        if sudo systemctl enable netdata 2>/dev/null; then
            echo "✅ Netdata service enabled for startup"
        else
            echo "⚠️  Could not enable Netdata service (may already be enabled)"
        fi
        
        # Start or restart the service
        if systemctl is-active --quiet netdata; then
            echo "🔄 Restarting Netdata service..."
            sudo systemctl restart netdata
        else
            echo "▶️  Starting Netdata service..."
            sudo systemctl start netdata
        fi
        
        # Check service status
        if systemctl is-active --quiet netdata; then
            echo "✅ Netdata service is active"
        else
            echo "❌ Netdata service failed to start"
            echo "   Checking service status..."
            sudo systemctl status netdata --no-pager -l
            exit 1
        fi
        
    elif command -v service &> /dev/null; then
        # Older Linux with service command
        echo "🔧 Using service command to manage Netdata..."
        sudo service netdata restart
        
    else
        # Try direct binary execution
        echo "🔧 Attempting to start Netdata directly..."
        if command -v netdata &> /dev/null; then
            sudo netdata -D
        else
            echo "❌ Cannot find method to start Netdata service"
            exit 1
        fi
    fi
    
    # Wait for service to start and verify
    echo "⏳ Waiting for Netdata to start..."
    for i in {1..45}; do
        if curl -s http://localhost:19999/api/v1/info > /dev/null 2>&1; then
            echo "✅ Netdata is running and accessible!"
            
            # Get some basic info
            NETDATA_VERSION=$(curl -s http://localhost:19999/api/v1/info 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
            echo "   Version: $NETDATA_VERSION"
            echo "   Dashboard: http://localhost:19999"
            break
        fi
        
        if [[ $((i % 10)) -eq 0 ]]; then
            echo "   Still waiting... ($i/45)"
        fi
        
        sleep 1
        
        if [[ $i -eq 45 ]]; then
            echo "❌ Timeout waiting for Netdata to start"
            echo "   Checking if service is running..."
            if command -v systemctl &> /dev/null; then
                sudo systemctl status netdata --no-pager
            fi
            echo "   Checking if port 19999 is in use..."
            sudo netstat -tlnp | grep :19999 || echo "   Port 19999 is not in use"
            exit 1
        fi
    done
}

# Main execution
main() {
    check_system
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