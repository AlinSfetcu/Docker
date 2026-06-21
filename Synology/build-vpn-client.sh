#!/bin/bash
# Synology DS725+ VPN Client Package
# Build script for creating a SPK (Synology Package) for VPN client installation
# File: build-vpn-client.sh

set -e

PACKAGE_NAME="vpn-client"
VERSION="1.0.0"
ARCH="x86_64"
SYNOLOGY_ARCH="x86_64-7.1"

# Create package structure
mkdir -p build/{package,scripts}
cd build/package

# Create INFO file
cat > INFO << 'EOF'
package="vpn-client"
version="1.0.0"
os_min_ver="7.1"
firmware="7.1-42661"
arch="x86_64"
distributor="VPN Client"
distributor_url="https://vpn-client.local"
maintainer="Admin"
maintainer_url="https://vpn-client.local"
description="OpenVPN and WireGuard client for Synology NAS"
description_enu="OpenVPN and WireGuard client for Synology NAS"
support_center=1
silent_install=1
silent_upgrade=1
silent_uninstall=1
reloadui=1
serviceport=8443
EOF

# Create package.tgz structure
mkdir -p package/bin
mkdir -p package/etc/vpn-client
mkdir -p package/var/packages/vpn-client/target

# Create main VPN client script
cat > package/bin/vpn-client << 'SCRIPT'
#!/bin/bash
# VPN Client Main Script

VPN_CONFIG_DIR="/var/packages/vpn-client/target/etc"
VPN_LOG_DIR="/var/packages/vpn-client/target/var/log"
VPN_RUNTIME_DIR="/var/packages/vpn-client/target/var/run"

mkdir -p "$VPN_CONFIG_DIR" "$VPN_LOG_DIR" "$VPN_RUNTIME_DIR"

case "$1" in
    start)
        echo "[$(date)] Starting VPN Client..." >> "$VPN_LOG_DIR/vpn-client.log"
        # Start OpenVPN or WireGuard based on config
        if [ -f "$VPN_CONFIG_DIR/wireguard.conf" ]; then
            wg-quick up wg0 2>> "$VPN_LOG_DIR/vpn-client.log"
        elif [ -f "$VPN_CONFIG_DIR/openvpn.conf" ]; then
            openvpn --config "$VPN_CONFIG_DIR/openvpn.conf" --log "$VPN_LOG_DIR/openvpn.log" --daemon
        fi
        ;;
    stop)
        echo "[$(date)] Stopping VPN Client..." >> "$VPN_LOG_DIR/vpn-client.log"
        pkill -f "openvpn" || true
        wg-quick down wg0 2>/dev/null || true
        ;;
    status)
        if pgrep -f "openvpn" > /dev/null; then
            echo "OpenVPN is running"
        elif wg show wg0 > /dev/null 2>&1; then
            echo "WireGuard is running"
        else
            echo "VPN Client is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
SCRIPT

chmod +x package/bin/vpn-client

# Create postinst script
cat > ../scripts/postinst << 'POSTSCRIPT'
#!/bin/bash
PACKAGE_DIR="/var/packages/vpn-client"
TARGET_DIR="$PACKAGE_DIR/target"

mkdir -p "$TARGET_DIR/etc"
mkdir -p "$TARGET_DIR/var/log"
mkdir -p "$TARGET_DIR/var/run"

# Download and install OpenVPN
if [ ! -f "$TARGET_DIR/bin/openvpn" ]; then
    ipkg update
    ipkg install openvpn
fi

# Download and install WireGuard
if [ ! -f "$TARGET_DIR/bin/wg" ]; then
    ipkg install wireguard-tools
fi

# Set permissions
chmod +x "$PACKAGE_DIR/bin/vpn-client"

exit 0
POSTSCRIPT

chmod +x ../scripts/postinst

# Create preinst script
cat > ../scripts/preinst << 'PRESCR'
#!/bin/bash
exit 0
PRESCR

chmod +x ../scripts/preinst

# Create start-stop-status script
cat > ../scripts/start-stop-status << 'STARTSTOP'
#!/bin/bash
PACKAGE_DIR="/var/packages/vpn-client"

case "$1" in
    start)
        "$PACKAGE_DIR/bin/vpn-client" start
        ;;
    stop)
        "$PACKAGE_DIR/bin/vpn-client" stop
        ;;
    status)
        "$PACKAGE_DIR/bin/vpn-client" status
        ;;
esac

exit 0
STARTSTOP

chmod +x ../scripts/start-stop-status

# Create Web UI configuration (optional)
mkdir -p package/var/packages/vpn-client/web
cat > package/var/packages/vpn-client/web/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>VPN Client Configuration</title>
    <style>
        body { font-family: Arial; margin: 20px; }
        .container { max-width: 600px; margin: 0 auto; }
        input, textarea { width: 100%; padding: 8px; margin: 5px 0; }
        button { padding: 10px 20px; background-color: #0066cc; color: white; border: none; cursor: pointer; }
    </style>
</head>
<body>
    <div class="container">
        <h1>VPN Client Configuration</h1>
        <form>
            <label>VPN Type:</label>
            <select>
                <option>OpenVPN</option>
                <option>WireGuard</option>
            </select>
            
            <label>Configuration File:</label>
            <textarea rows="10" placeholder="Paste your VPN config here"></textarea>
            
            <button type="submit">Save Configuration</button>
            <button type="button">Connect</button>
            <button type="button">Disconnect</button>
        </form>
    </div>
</body>
</html>
HTML

# Create package.tgz
tar -czf package.tgz -C package . 2>/dev/null || tar -czf package.tgz -C package .

# Create SynoPkg icon (minimal PNG placeholder)
mkdir -p syno_icon_tmp
cd syno_icon_tmp

# Create scripts.tgz from scripts directory
tar -czf ../scripts.tgz -C ../scripts . 2>/dev/null || tar -czf ../scripts.tgz -C ../scripts .

cd ..

# Build the SPK file
tar -cf ../vpn-client-${VERSION}-${ARCH}.spk \
    INFO \
    package.tgz \
    scripts.tgz

echo "VPN Client Package built successfully!"
echo "File: vpn-client-${VERSION}-${ARCH}.spk"
echo ""
echo "Installation instructions for Synology DS725+:"
echo "1. Login to DSM Web Interface"
echo "2. Go to Package Center"
echo "3. Click 'Manual Install'"
echo "4. Select the SPK file"
echo "5. Follow the installation wizard"
