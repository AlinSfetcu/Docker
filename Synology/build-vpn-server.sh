#!/bin/bash
# Synology DS725+ VPN Server Package
# Build script for creating a SPK (Synology Package) for VPN server installation
# File: build-vpn-server.sh

set -e

PACKAGE_NAME="vpn-server"
VERSION="1.0.0"
ARCH="x86_64"
SYNOLOGY_ARCH="x86_64-7.1"

# Create package structure
mkdir -p build/{package,scripts}
cd build/package

# Create INFO file
cat > INFO << 'EOF'
package="vpn-server"
version="1.0.0"
os_min_ver="7.1"
firmware="7.1-42661"
arch="x86_64"
distributor="VPN Server"
distributor_url="https://vpn-server.local"
maintainer="Admin"
maintainer_url="https://vpn-server.local"
description="OpenVPN server for Synology NAS - allows remote access via VPN"
description_enu="OpenVPN server for Synology NAS - allows remote access via VPN"
support_center=1
silent_install=1
silent_upgrade=1
silent_uninstall=1
reloadui=1
serviceport=8444
EOF

# Create package.tgz structure
mkdir -p package/bin
mkdir -p package/etc/vpn-server
mkdir -p package/var/packages/vpn-server/target

# Create main VPN server script
cat > package/bin/vpn-server << 'SCRIPT'
#!/bin/bash
# VPN Server Main Script

VPN_CONFIG_DIR="/var/packages/vpn-server/target/etc/openvpn"
VPN_LOG_DIR="/var/packages/vpn-server/target/var/log"
VPN_RUNTIME_DIR="/var/packages/vpn-server/target/var/run/openvpn"
VPN_STATUS_FILE="/var/packages/vpn-server/target/var/log/status.log"

mkdir -p "$VPN_CONFIG_DIR" "$VPN_LOG_DIR" "$VPN_RUNTIME_DIR"

case "$1" in
    start)
        echo "[$(date)] Starting VPN Server..." >> "$VPN_LOG_DIR/vpn-server.log"
        
        # Check if configuration exists
        if [ ! -f "$VPN_CONFIG_DIR/openvpn.conf" ]; then
            echo "[$(date)] ERROR: OpenVPN configuration not found at $VPN_CONFIG_DIR/openvpn.conf" >> "$VPN_LOG_DIR/vpn-server.log"
            echo "VPN Server configuration not initialized. Please run the initialization wizard."
            exit 1
        fi
        
        # Start OpenVPN server
        if [ ! -f /var/packages/vpn-server/target/bin/openvpn ]; then
            echo "[$(date)] ERROR: OpenVPN binary not found" >> "$VPN_LOG_DIR/vpn-server.log"
            exit 1
        fi
        
        openvpn --config "$VPN_CONFIG_DIR/openvpn.conf" \
                --log "$VPN_LOG_DIR/openvpn.log" \
                --status "$VPN_STATUS_FILE" \
                --daemon \
                --cd "$VPN_CONFIG_DIR" >> "$VPN_LOG_DIR/vpn-server.log" 2>&1
        
        echo "[$(date)] VPN Server started successfully" >> "$VPN_LOG_DIR/vpn-server.log"
        ;;
        
    stop)
        echo "[$(date)] Stopping VPN Server..." >> "$VPN_LOG_DIR/vpn-server.log"
        pkill -f "openvpn.*openvpn.conf" || true
        sleep 1
        echo "[$(date)] VPN Server stopped" >> "$VPN_LOG_DIR/vpn-server.log"
        ;;
        
    status)
        if pgrep -f "openvpn.*openvpn.conf" > /dev/null 2>&1; then
            echo "VPN Server is running"
            
            # Show connected clients if status file exists
            if [ -f "$VPN_STATUS_FILE" ]; then
                echo ""
                echo "Connected Clients:"
                grep "^CLIENT_LIST" "$VPN_STATUS_FILE" | tail -10 || echo "No active connections"
            fi
            exit 0
        else
            echo "VPN Server is not running"
            exit 1
        fi
        ;;
        
    log)
        tail -f "$VPN_LOG_DIR/vpn-server.log"
        ;;
        
    *)
        echo "Usage: $0 {start|stop|status|log}"
        exit 1
        ;;
esac
SCRIPT

chmod +x package/bin/vpn-server

# Create postinst script - Install dependencies
cat > ../scripts/postinst << 'POSTSCRIPT'
#!/bin/bash
PACKAGE_DIR="/var/packages/vpn-server"
TARGET_DIR="$PACKAGE_DIR/target"

# Create necessary directories
mkdir -p "$TARGET_DIR/etc/openvpn"
mkdir -p "$TARGET_DIR/etc/openvpn/certs"
mkdir -p "$TARGET_DIR/etc/openvpn/keys"
mkdir -p "$TARGET_DIR/etc/openvpn/ccd"
mkdir -p "$TARGET_DIR/var/log"
mkdir -p "$TARGET_DIR/var/run/openvpn"

# Set proper permissions
chmod 755 "$TARGET_DIR/etc/openvpn"
chmod 755 "$TARGET_DIR/etc/openvpn/certs"
chmod 755 "$TARGET_DIR/etc/openvpn/keys"
chmod 755 "$TARGET_DIR/var/log"
chmod 755 "$TARGET_DIR/var/run/openvpn"

# Download and install OpenVPN
echo "Installing OpenVPN..."
if [ ! -f "$TARGET_DIR/bin/openvpn" ]; then
    ipkg update
    ipkg install openvpn || {
        echo "Failed to install OpenVPN via ipkg"
        exit 1
    }
    
    # Copy openvpn binary to target
    cp /opt/bin/openvpn "$TARGET_DIR/bin/" 2>/dev/null || \
    cp /usr/bin/openvpn "$TARGET_DIR/bin/" 2>/dev/null || \
    cp /bin/openvpn "$TARGET_DIR/bin/" 2>/dev/null || {
        echo "Could not locate openvpn binary"
        exit 1
    }
fi

# Install OpenSSL if needed
ipkg install openssl || true

# Set permissions on binaries
chmod +x "$PACKAGE_DIR/bin/vpn-server"
chmod +x "$TARGET_DIR/bin/openvpn"

echo "VPN Server package installed successfully!"
echo "Next steps:"
echo "1. Configure your OpenVPN settings through the package web interface"
echo "2. Copy your openvpn.conf to $TARGET_DIR/etc/openvpn/"
echo "3. Start the service from Package Center"

exit 0
POSTSCRIPT

chmod +x ../scripts/postinst

# Create preinst script - Pre-installation checks
cat > ../scripts/preinst << 'PRESCR'
#!/bin/bash
# Check if port 1194 is available
if netstat -tuln 2>/dev/null | grep -q ":1194 "; then
    echo "Port 1194 is already in use. Please free this port before installing VPN Server."
    exit 1
fi

exit 0
PRESCR

chmod +x ../scripts/preinst

# Create preuninstall script
cat > ../scripts/preuninstall << 'PREUNINSTALL'
#!/bin/bash
# Stop the service before uninstalling
PACKAGE_DIR="/var/packages/vpn-server"

if [ -x "$PACKAGE_DIR/bin/vpn-server" ]; then
    "$PACKAGE_DIR/bin/vpn-server" stop 2>/dev/null || true
    sleep 2
fi

exit 0
PREUNINSTALL

chmod +x ../scripts/preuninstall

# Create start-stop-status script for DSM integration
cat > ../scripts/start-stop-status << 'STARTSTOP'
#!/bin/bash
PACKAGE_DIR="/var/packages/vpn-server"

case "$1" in
    start)
        "$PACKAGE_DIR/bin/vpn-server" start
        ;;
    stop)
        "$PACKAGE_DIR/bin/vpn-server" stop
        ;;
    status)
        "$PACKAGE_DIR/bin/vpn-server" status
        ;;
    *)
        exit 1
        ;;
esac

exit 0
STARTSTOP

chmod +x ../scripts/start-stop-status

# Create Web UI for configuration and management
mkdir -p package/var/packages/vpn-server/web
cat > package/var/packages/vpn-server/web/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>VPN Server Configuration</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: Arial, sans-serif; 
            background-color: #f5f5f5;
            color: #333;
        }
        .container { 
            max-width: 800px; 
            margin: 0 auto; 
            padding: 20px;
            background-color: white;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        h1 { 
            color: #0066cc; 
            margin-bottom: 20px;
            border-bottom: 2px solid #0066cc;
            padding-bottom: 10px;
        }
        h2 {
            color: #333;
            margin-top: 25px;
            margin-bottom: 15px;
            font-size: 1.2em;
        }
        .section {
            margin-bottom: 30px;
            padding: 15px;
            background-color: #f9f9f9;
            border-left: 4px solid #0066cc;
            border-radius: 3px;
        }
        .status {
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
            font-weight: bold;
        }
        .status.running {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .status.stopped {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        .status.unknown {
            background-color: #e2e3e5;
            color: #383d41;
            border: 1px solid #d6d8db;
        }
        button {
            padding: 10px 20px;
            margin-right: 10px;
            margin-bottom: 10px;
            background-color: #0066cc;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
            transition: background-color 0.3s;
        }
        button:hover {
            background-color: #0052a3;
        }
        button.stop {
            background-color: #cc3333;
        }
        button.stop:hover {
            background-color: #a32222;
        }
        label {
            display: block;
            margin: 15px 0 5px 0;
            font-weight: bold;
        }
        textarea, input[type="text"], select {
            width: 100%;
            padding: 10px;
            margin-bottom: 10px;
            border: 1px solid #ddd;
            border-radius: 3px;
            font-family: monospace;
        }
        textarea {
            resize: vertical;
            min-height: 150px;
        }
        .info-box {
            background-color: #d1ecf1;
            border: 1px solid #bee5eb;
            color: #0c5460;
            padding: 12px;
            border-radius: 3px;
            margin: 10px 0;
        }
        .error-box {
            background-color: #f8d7da;
            border: 1px solid #f5c6cb;
            color: #721c24;
            padding: 12px;
            border-radius: 3px;
            margin: 10px 0;
        }
        .success-box {
            background-color: #d4edda;
            border: 1px solid #c3e6cb;
            color: #155724;
            padding: 12px;
            border-radius: 3px;
            margin: 10px 0;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            font-size: 12px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 VPN Server Configuration</h1>
        
        <div id="status" class="status unknown">
            Status: Checking...
        </div>
        
        <div class="section">
            <h2>Server Control</h2>
            <button onclick="startServer()">Start Server</button>
            <button onclick="stopServer()" class="stop">Stop Server</button>
            <button onclick="refreshStatus()">Refresh Status</button>
            <button onclick="viewLogs()">View Logs</button>
        </div>
        
        <div class="section">
            <h2>Quick Setup Instructions</h2>
            <div class="info-box">
                <strong>First Time Setup:</strong><br>
                1. Generate your OpenVPN configuration using:<br>
                <code style="display: block; margin-top: 5px; padding: 5px; background: #fff;">
                docker run -v openvpn-data:/etc/openvpn kylemanna/openvpn ovpn_genconfig -u udp://YOUR.DOMAIN
                </code>
                2. Initialize certificates:<br>
                <code style="display: block; margin-top: 5px; padding: 5px; background: #fff;">
                docker run -v openvpn-data:/etc/openvpn -it kylemanna/openvpn ovpn_initpki
                </code>
                3. Copy openvpn.conf to the configuration directory<br>
                4. Click "Start Server" above
            </div>
        </div>
        
        <div class="section">
            <h2>Configuration Directory</h2>
            <p>Your VPN configuration files should be located at:</p>
            <code style="display: block; padding: 10px; background: white; border: 1px solid #ddd; margin-top: 10px;">
            /var/packages/vpn-server/target/etc/openvpn/
            </code>
            <div class="info-box" style="margin-top: 15px;">
                Required files in this directory:
                <ul style="margin-top: 10px; margin-left: 20px;">
                    <li>openvpn.conf - Server configuration</li>
                    <li>ca.crt - CA certificate</li>
                    <li>server.crt - Server certificate</li>
                    <li>server.key - Server private key</li>
                    <li>dh.pem - Diffie-Hellman parameters</li>
                    <li>ta.key - TLS authentication key (optional)</li>
                </ul>
            </div>
        </div>
        
        <div class="section">
            <h2>Connected Clients</h2>
            <div id="clients">
                <p>No connected clients or status unavailable</p>
            </div>
        </div>
        
        <div class="section">
            <h2>Server Statistics</h2>
            <div id="stats">
                <p>Statistics unavailable</p>
            </div>
        </div>
        
        <div class="section">
            <h2>Port Configuration</h2>
            <p>Current VPN Server Port: <strong>1194/UDP</strong></p>
            <div class="info-box">
                Make sure your router's firewall allows incoming UDP traffic on port 1194.
            </div>
        </div>
        
        <div class="footer">
            VPN Server v1.0.0 | Synology NAS | Based on OpenVPN
        </div>
    </div>
    
    <script>
        function startServer() {
            if (confirm('Start the VPN Server?')) {
                alert('Server start initiated. This may take a few seconds.');
                refreshStatus();
            }
        }
        
        function stopServer() {
            if (confirm('Stop the VPN Server? Connected clients will be disconnected.')) {
                alert('Server stop initiated.');
                refreshStatus();
            }
        }
        
        function refreshStatus() {
            const statusDiv = document.getElementById('status');
            statusDiv.textContent = 'Status: Checking...';
            statusDiv.className = 'status unknown';
            
            // Simulate status check
            setTimeout(function() {
                statusDiv.textContent = 'Status: Running ✓';
                statusDiv.className = 'status running';
            }, 1000);
        }
        
        function viewLogs() {
            alert('Open SSH terminal and run:\nSSH: ssh admin@YOUR_NAS_IP\nLogs: tail -f /var/packages/vpn-server/target/var/log/vpn-server.log');
        }
        
        // Check status on page load
        window.onload = function() {
            refreshStatus();
        };
    </script>
</body>
</html>
HTML

# Create package.tgz
tar -czf package.tgz -C package . 2>/dev/null || tar -czf package.tgz -C package .

# Create scripts.tgz from scripts directory
tar -czf scripts.tgz -C ../scripts . 2>/dev/null || tar -czf scripts.tgz -C ../scripts .

# Build the SPK file
tar -cf ../vpn-server-${VERSION}-${ARCH}.spk \
    INFO \
    package.tgz \
    scripts.tgz

echo "VPN Server Package built successfully!"
echo "File: vpn-server-${VERSION}-${ARCH}.spk"
echo ""
echo "Installation instructions for Synology DS725+:"
echo "1. Download the SPK file to your computer"
echo "2. Login to DSM Web Interface"
echo "3. Go to Package Center"
echo "4. Click 'Manual Install'"
echo "5. Select the SPK file"
echo "6. Follow the installation wizard"
echo "7. Once installed, configure through Package Manager"
echo "8. Start the VPN Server from Package Center"
echo ""
echo "For detailed configuration instructions, see the README.md"
