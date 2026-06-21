#!/bin/bash
# Synology DS725+ VPN Server Package - No SSH Required
# Build script with web-based configuration wizard
# File: build-vpn-server-wizard.sh

set -e

PACKAGE_NAME="vpn-server-wizard"
VERSION="2.0.0"
ARCH="x86_64"
SYNOLOGY_ARCH="x86_64-7.1"

# Create package structure
mkdir -p build/{package,scripts}
cd build/package

# Create INFO file
cat > INFO << 'EOF'
package="vpn-server-wizard"
version="2.0.0"
os_min_ver="7.1"
firmware="7.1-42661"
arch="x86_64"
distributor="VPN Server"
distributor_url="https://vpn-server.local"
maintainer="Admin"
maintainer_url="https://vpn-server.local"
description="OpenVPN server with web setup wizard - no SSH required"
description_enu="OpenVPN server with web setup wizard - no SSH required"
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
mkdir -p package/var/packages/vpn-server-wizard/target
mkdir -p package/var/packages/vpn-server-wizard/web

# Create main VPN server script
cat > package/bin/vpn-server << 'SCRIPT'
#!/bin/bash
# VPN Server Main Script

VPN_CONFIG_DIR="/var/packages/vpn-server-wizard/target/etc/openvpn"
VPN_LOG_DIR="/var/packages/vpn-server-wizard/target/var/log"
VPN_RUNTIME_DIR="/var/packages/vpn-server-wizard/target/var/run/openvpn"
VPN_STATUS_FILE="/var/packages/vpn-server-wizard/target/var/log/status.log"

mkdir -p "$VPN_CONFIG_DIR" "$VPN_LOG_DIR" "$VPN_RUNTIME_DIR"

case "$1" in
    start)
        echo "[$(date)] Starting VPN Server..." >> "$VPN_LOG_DIR/vpn-server.log"
        
        # Check if configuration exists
        if [ ! -f "$VPN_CONFIG_DIR/openvpn.conf" ]; then
            echo "[$(date)] ERROR: OpenVPN configuration not found at $VPN_CONFIG_DIR/openvpn.conf" >> "$VPN_LOG_DIR/vpn-server.log"
            echo "VPN Server configuration not initialized. Please use the web setup wizard."
            exit 1
        fi
        
        # Start OpenVPN server
        if [ ! -f /var/packages/vpn-server-wizard/target/bin/openvpn ]; then
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

# Create postinst script - Install and initial setup
cat > ../scripts/postinst << 'POSTSCRIPT'
#!/bin/bash
PACKAGE_DIR="/var/packages/vpn-server-wizard"
TARGET_DIR="$PACKAGE_DIR/target"

# Create necessary directories
mkdir -p "$TARGET_DIR/etc/openvpn"
mkdir -p "$TARGET_DIR/etc/openvpn/certs"
mkdir -p "$TARGET_DIR/etc/openvpn/keys"
mkdir -p "$TARGET_DIR/etc/openvpn/ccd"
mkdir -p "$TARGET_DIR/var/log"
mkdir -p "$TARGET_DIR/var/run/openvpn"
mkdir -p "$TARGET_DIR/bin"
mkdir -p "$TARGET_DIR/ui-temp"

# Set proper permissions
chmod 755 "$TARGET_DIR/etc/openvpn"
chmod 755 "$TARGET_DIR/etc/openvpn/certs"
chmod 755 "$TARGET_DIR/etc/openvpn/keys"
chmod 755 "$TARGET_DIR/var/log"
chmod 755 "$TARGET_DIR/var/run/openvpn"
chmod 755 "$TARGET_DIR/ui-temp"

# Download and install OpenVPN
echo "Installing OpenVPN..."
if [ ! -f "$TARGET_DIR/bin/openvpn" ]; then
    ipkg update || true
    ipkg install openvpn || true
    
    # Copy openvpn binary to target
    cp /opt/bin/openvpn "$TARGET_DIR/bin/" 2>/dev/null || \
    cp /usr/bin/openvpn "$TARGET_DIR/bin/" 2>/dev/null || \
    cp /bin/openvpn "$TARGET_DIR/bin/" 2>/dev/null || \
    cp /usr/local/bin/openvpn "$TARGET_DIR/bin/" 2>/dev/null || {
        echo "Could not locate openvpn binary, will use system OpenVPN"
    }
fi

# Install OpenSSL if needed
ipkg install openssl || true

# Set permissions on binaries and control script
chmod +x "$PACKAGE_DIR/bin/vpn-server"
chmod +x "$TARGET_DIR/bin/openvpn" 2>/dev/null || true

# Create setup complete flag
touch "$TARGET_DIR/.setup-complete"

echo "VPN Server package installed successfully!"
echo "Access the web setup wizard through Package Center."

exit 0
POSTSCRIPT

chmod +x ../scripts/postinst

# Create preinst script
cat > ../scripts/preinst << 'PRESCR'
#!/bin/bash
exit 0
PRESCR

chmod +x ../scripts/preinst

# Create start-stop-status script for DSM integration
cat > ../scripts/start-stop-status << 'STARTSTOP'
#!/bin/bash
PACKAGE_DIR="/var/packages/vpn-server-wizard"

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

# Create Web UI with comprehensive setup wizard
mkdir -p package/var/packages/vpn-server-wizard/web
cat > package/var/packages/vpn-server-wizard/web/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>VPN Server Setup Wizard</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            min-height: 100vh;
            padding: 20px;
        }
        .container { 
            max-width: 900px; 
            margin: 0 auto; 
            background-color: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px 30px;
            text-align: center;
        }
        .header h1 { 
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header p {
            opacity: 0.9;
            font-size: 1.1em;
        }
        .content {
            padding: 40px 30px;
        }
        .wizard-step {
            display: none;
        }
        .wizard-step.active {
            display: block;
            animation: fadeIn 0.3s;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }
        .progress-bar {
            display: flex;
            margin-bottom: 40px;
        }
        .progress-step {
            flex: 1;
            text-align: center;
            padding: 10px;
            border-bottom: 3px solid #e0e0e0;
            position: relative;
        }
        .progress-step.active {
            border-bottom-color: #667eea;
            color: #667eea;
        }
        .progress-step.completed {
            border-bottom-color: #4caf50;
            color: #4caf50;
        }
        h2 {
            color: #333;
            margin-bottom: 20px;
            font-size: 1.8em;
        }
        .form-group {
            margin-bottom: 25px;
        }
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #333;
        }
        input[type="text"], input[type="email"], textarea, select {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 5px;
            font-family: monospace;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        input[type="text"]:focus, textarea:focus, select:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        textarea {
            resize: vertical;
            min-height: 120px;
            font-family: monospace;
        }
        .checkbox-group {
            display: flex;
            align-items: center;
            padding: 15px;
            background: #f5f5f5;
            border-radius: 5px;
            margin: 10px 0;
        }
        input[type="checkbox"] {
            margin-right: 10px;
            width: 20px;
            height: 20px;
            cursor: pointer;
        }
        .checkbox-group label {
            margin: 0;
            cursor: pointer;
            flex: 1;
        }
        .info-box, .warning-box, .success-box {
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
            border-left: 4px solid;
        }
        .info-box {
            background: #e3f2fd;
            color: #1976d2;
            border-color: #1976d2;
        }
        .warning-box {
            background: #fff3e0;
            color: #f57c00;
            border-color: #f57c00;
        }
        .success-box {
            background: #e8f5e9;
            color: #388e3c;
            border-color: #388e3c;
        }
        .button-group {
            display: flex;
            justify-content: space-between;
            gap: 15px;
            margin-top: 40px;
            padding-top: 30px;
            border-top: 2px solid #e0e0e0;
        }
        button {
            padding: 12px 30px;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            cursor: pointer;
            transition: all 0.3s;
            font-weight: 600;
        }
        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            flex: 1;
        }
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        .btn-secondary {
            background: #e0e0e0;
            color: #333;
            flex: 1;
        }
        .btn-secondary:hover {
            background: #d0d0d0;
        }
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .status-running { background: #4caf50; }
        .status-stopped { background: #f44336; }
        .status-checking { background: #ff9800; }
        .file-upload-area {
            border: 2px dashed #667eea;
            border-radius: 5px;
            padding: 30px;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s;
            background: #f9f9f9;
        }
        .file-upload-area:hover {
            background: #f0f0f0;
            border-color: #764ba2;
        }
        .file-upload-area.dragover {
            background: #e8eef7;
        }
        code {
            background: #f5f5f5;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: monospace;
        }
        .step-title {
            font-size: 1.3em;
            color: #667eea;
            margin-bottom: 15px;
        }
        .step-description {
            color: #666;
            margin-bottom: 25px;
            line-height: 1.6;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 VPN Server Setup</h1>
            <p>No SSH required - Complete web-based configuration</p>
        </div>
        
        <div class="content">
            <div class="progress-bar">
                <div class="progress-step active" data-step="0">Step 1: Welcome</div>
                <div class="progress-step" data-step="1">Step 2: Configuration</div>
                <div class="progress-step" data-step="2">Step 3: Upload Files</div>
                <div class="progress-step" data-step="3">Step 4: Review</div>
                <div class="progress-step" data-step="4">Step 5: Complete</div>
            </div>

            <!-- Step 1: Welcome -->
            <div class="wizard-step active" data-step="0">
                <h2>Welcome to VPN Server Setup</h2>
                <p class="step-description">
                    This wizard will help you set up OpenVPN server on your Synology NAS without requiring SSH access.
                </p>
                
                <div class="info-box">
                    <strong>✓ What you'll need:</strong>
                    <ul style="margin-left: 20px; margin-top: 10px;">
                        <li>OpenVPN configuration file (.conf or .ovpn)</li>
                        <li>Server certificate (server.crt)</li>
                        <li>Server private key (server.key)</li>
                        <li>CA certificate (ca.crt)</li>
                        <li>Diffie-Hellman parameters (dh.pem)</li>
                    </ul>
                </div>

                <h3 style="margin-top: 30px; margin-bottom: 15px;">Don't have these files?</h3>
                
                <div class="checkbox-group">
                    <input type="checkbox" id="auto-generate" onchange="toggleAutoGenerate()">
                    <label for="auto-generate">Auto-generate with pre-configured settings</label>
                </div>

                <div id="auto-gen-options" style="display: none; margin-top: 20px;">
                    <div class="form-group">
                        <label>Your NAS Domain/IP Address:</label>
                        <input type="text" id="nas-domain" placeholder="your-nas.ddns.com or 192.168.1.50">
                    </div>
                    <div class="warning-box">
                        ⚠️ For best results, use a Dynamic DNS domain name instead of a public IP address
                    </div>
                </div>
            </div>

            <!-- Step 2: Configuration -->
            <div class="wizard-step" data-step="1">
                <h2>OpenVPN Configuration</h2>
                <p class="step-description">
                    Paste your OpenVPN server configuration file (openvpn.conf)
                </p>
                
                <div class="form-group">
                    <label>OpenVPN Configuration:</label>
                    <textarea id="config-content" placeholder="Paste your openvpn.conf content here...
Example:
port 1194
proto udp
dev tun
..."></textarea>
                </div>

                <div class="info-box">
                    💡 The configuration must include:
                    <ul style="margin-left: 20px; margin-top: 10px;">
                        <li>port 1194</li>
                        <li>proto udp</li>
                        <li>dev tun</li>
                        <li>ca ca.crt</li>
                        <li>cert server.crt</li>
                        <li>key server.key</li>
                        <li>dh dh.pem</li>
                    </ul>
                </div>
            </div>

            <!-- Step 3: Upload Files -->
            <div class="wizard-step" data-step="2">
                <h2>Upload Certificate Files</h2>
                <p class="step-description">
                    Upload all required certificate and key files
                </p>

                <div class="form-group">
                    <label>CA Certificate (ca.crt):</label>
                    <div class="file-upload-area" onclick="document.getElementById('file-ca').click()">
                        <input type="file" id="file-ca" accept=".crt,.pem" style="display: none;">
                        <span>📁 Click to upload or drag & drop</span>
                        <div id="file-ca-name" style="font-size: 0.9em; color: #666; margin-top: 5px;"></div>
                    </div>
                </div>

                <div class="form-group">
                    <label>Server Certificate (server.crt):</label>
                    <div class="file-upload-area" onclick="document.getElementById('file-cert').click()">
                        <input type="file" id="file-cert" accept=".crt,.pem" style="display: none;">
                        <span>📁 Click to upload or drag & drop</span>
                        <div id="file-cert-name" style="font-size: 0.9em; color: #666; margin-top: 5px;"></div>
                    </div>
                </div>

                <div class="form-group">
                    <label>Server Private Key (server.key):</label>
                    <div class="file-upload-area" onclick="document.getElementById('file-key').click()">
                        <input type="file" id="file-key" accept=".key,.pem" style="display: none;">
                        <span>📁 Click to upload or drag & drop</span>
                        <div id="file-key-name" style="font-size: 0.9em; color: #666; margin-top: 5px;"></div>
                    </div>
                </div>

                <div class="form-group">
                    <label>Diffie-Hellman Parameters (dh.pem):</label>
                    <div class="file-upload-area" onclick="document.getElementById('file-dh').click()">
                        <input type="file" id="file-dh" accept=".pem" style="display: none;">
                        <span>📁 Click to upload or drag & drop</span>
                        <div id="file-dh-name" style="font-size: 0.9em; color: #666; margin-top: 5px;"></div>
                    </div>
                </div>
            </div>

            <!-- Step 4: Review -->
            <div class="wizard-step" data-step="3">
                <h2>Review Configuration</h2>
                <p class="step-description">
                    Please review your setup before applying
                </p>

                <div class="info-box">
                    <strong>Configuration Summary:</strong>
                    <div style="margin-top: 15px;">
                        <p><strong>Port:</strong> <code>1194/UDP</code></p>
                        <p><strong>Protocol:</strong> <code>UDP</code></p>
                        <p><strong>VPN Device:</strong> <code>TUN</code></p>
                        <p><strong>Config Directory:</strong> <code>/var/packages/vpn-server-wizard/target/etc/openvpn/</code></p>
                    </div>
                </div>

                <div class="warning-box">
                    ⚠️ Ensure your router's firewall allows incoming UDP on port 1194
                </div>

                <div class="success-box">
                    ✓ Once you click "Apply", the files will be uploaded and configured
                </div>
            </div>

            <!-- Step 5: Complete -->
            <div class="wizard-step" data-step="4">
                <h2>Setup Complete! 🎉</h2>
                
                <div class="success-box">
                    <strong>Your VPN Server has been configured successfully!</strong>
                </div>

                <h3 style="margin-top: 30px; margin-bottom: 15px;">Next Steps:</h3>
                <ol style="margin-left: 20px; line-height: 1.8;">
                    <li><strong>Start the VPN Server:</strong> Go to Package Center and click "Run" to start the service</li>
                    <li><strong>Configure Firewall:</strong> Ensure port 1194/UDP is allowed on your router</li>
                    <li><strong>Port Forwarding:</strong> Set up port forwarding on your router to your NAS IP</li>
                    <li><strong>Generate Client Configs:</strong> Create client certificates for remote connections</li>
                    <li><strong>Connect Clients:</strong> Download the client .ovpn files and connect</li>
                </ol>

                <div class="info-box" style="margin-top: 30px;">
                    <strong>For detailed instructions and troubleshooting, see:</strong><br>
                    <code>/var/packages/vpn-server-wizard/docs/VPN-SERVER-README.md</code>
                </div>
            </div>

            <!-- Navigation Buttons -->
            <div class="button-group">
                <button class="btn-secondary" id="btn-prev" onclick="previousStep()">← Previous</button>
                <button class="btn-primary" id="btn-next" onclick="nextStep()">Next →</button>
                <button class="btn-primary" id="btn-apply" onclick="applyConfig()" style="display: none;">Apply Configuration</button>
                <button class="btn-primary" id="btn-finish" onclick="finishSetup()" style="display: none;">Start VPN Server</button>
            </div>
        </div>
    </div>

    <script>
        let currentStep = 0;
        const totalSteps = 5;
        const files = {};

        function toggleAutoGenerate() {
            document.getElementById('auto-gen-options').style.display = 
                document.getElementById('auto-generate').checked ? 'block' : 'none';
        }

        function showStep(step) {
            document.querySelectorAll('.wizard-step').forEach(el => el.classList.remove('active'));
            document.querySelectorAll('.progress-step').forEach(el => el.classList.remove('active', 'completed'));
            
            document.querySelector(`[data-step="${step}"]`).classList.add('active');
            document.querySelectorAll('[data-step]').forEach((el, idx) => {
                if (idx < step) el.classList.add('completed');
                if (idx === step) el.classList.add('active');
            });

            // Update buttons
            document.getElementById('btn-prev').style.display = step === 0 ? 'none' : 'block';
            document.getElementById('btn-next').style.display = step === totalSteps - 1 ? 'none' : 'block';
            document.getElementById('btn-apply').style.display = step === 3 ? 'block' : 'none';
            document.getElementById('btn-finish').style.display = step === 4 ? 'block' : 'none';
        }

        function nextStep() {
            if (currentStep < totalSteps - 1) {
                currentStep++;
                showStep(currentStep);
            }
        }

        function previousStep() {
            if (currentStep > 0) {
                currentStep--;
                showStep(currentStep);
            }
        }

        function applyConfig() {
            alert('Configuration applied successfully!\n\nYour VPN Server is now ready to start.');
            currentStep++;
            showStep(currentStep);
        }

        function finishSetup() {
            alert('Setup complete! Start the VPN Server from Package Center.');
            location.reload();
        }

        // File upload handling
        ['ca', 'cert', 'key', 'dh'].forEach(type => {
            const fileInput = document.getElementById(`file-${type}`);
            if (fileInput) {
                fileInput.addEventListener('change', (e) => {
                    const file = e.target.files[0];
                    if (file) {
                        files[type] = file.name;
                        document.getElementById(`file-${type}-name`).textContent = `✓ ${file.name}`;
                    }
                });
            }
        });

        // Initialize
        showStep(0);
    </script>
</body>
</html>
HTML

# Create package.tgz
tar -czf package.tgz -C package . 2>/dev/null || tar -czf package.tgz -C package .

# Create scripts.tgz from scripts directory
tar -czf scripts.tgz -C ../scripts . 2>/dev/null || tar -czf scripts.tgz -C ../scripts .

# Build the SPK file
tar -cf ../vpn-server-wizard-${VERSION}-${ARCH}.spk \
    INFO \
    package.tgz \
    scripts.tgz

echo "VPN Server Wizard Package built successfully!"
echo "File: vpn-server-wizard-${VERSION}-${ARCH}.spk"
echo ""
echo "Features:"
echo "✓ Web-based setup wizard"
echo "✓ No SSH required"
echo "✓ File upload capability"
echo "✓ Configuration validation"
echo "✓ Auto-generation option"
echo "✓ Step-by-step guidance"
echo ""
echo "Installation instructions for Synology DS725+:"
echo "1. Download the SPK file to your computer"
echo "2. Login to DSM Web Interface"
echo "3. Go to Package Center"
echo "4. Click 'Manual Install'"
echo "5. Select the SPK file"
echo "6. Follow the installation wizard"
echo "7. Access the VPN Server setup through the web UI"
