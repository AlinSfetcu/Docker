# Synology VPN Client Package (DS725+)

This project provides a build script to create a Synology Package (SPK) for installing OpenVPN and WireGuard VPN clients on Synology NAS systems, specifically tested on DS725+ running DSM 7.1+.

## Overview

The `build-vpn-client.sh` script automates the creation of a Synology-compatible SPK package that allows you to:
- Run OpenVPN or WireGuard VPN clients on your Synology NAS
- Connect your NAS to a VPN network
- Route traffic through the VPN tunnel
- Manage VPN connections through the DSM Package Center

## Prerequisites

### On Build Machine (where you run the script)
- Linux/macOS/WSL environment (bash shell)
- `tar` command-line utility
- Sufficient disk space (~50MB temporary)
- Synology toolkit or compatible environment

### On Synology DS725+
- DSM 7.1 or later
- Administrator access to Package Center
- Enough storage space for package installation
- Optional: SSH access for advanced management

## Installation

### Step 1: Clone or Download the Repository

```bash
cd ~/projects
git clone https://github.com/AlinSfetcu/Docker.git
cd Docker/Synology
```

Or download just the script:
```bash
wget https://raw.githubusercontent.com/AlinSfetcu/Docker/main/Synology/build-vpn-client.sh
chmod +x build-vpn-client.sh
```

### Step 2: Run the Build Script

```bash
./build-vpn-client.sh
```

The script will:
1. Create a `build/` directory with package structure
2. Generate the INFO file with package metadata
3. Create the main VPN client script
4. Create installation scripts (postinst, preinst, start-stop-status)
5. Bundle everything into an SPK package file

**Output:**
```
VPN Client Package built successfully!
File: vpn-client-1.0.0-x86_64.spk
```

### Step 3: Transfer SPK to Synology NAS

Using SCP:
```bash
scp vpn-client-1.0.0-x86_64.spk admin@YOUR_NAS_IP:/home/admin/
```

Or via web browser:
1. Connect to your NAS via SSH or File Station
2. Upload the SPK file to the NAS

### Step 4: Install on Synology NAS

**Method A: Via DSM Web Interface**
1. Open DSM and login as Administrator
2. Navigate to **Package Center**
3. Click **Manual Install** (top-right corner)
4. Select the `vpn-client-1.0.0-x86_64.spk` file
5. Follow the installation wizard
6. Accept permissions and complete installation

**Method B: Via SSH/Command Line**
```bash
ssh admin@YOUR_NAS_IP
sudo ipkg install /home/admin/vpn-client-1.0.0-x86_64.spk
```

## Usage

### Via DSM Package Center

Once installed, you can manage the VPN client from Package Center:
- **Start**: Click "Run" button in Package Center
- **Stop**: Click "Stop" button
- **View Logs**: Check the package logs in Package Center

### Via SSH/Command Line

Connect via SSH to your NAS:
```bash
ssh admin@YOUR_NAS_IP
```

**Start VPN Client:**
```bash
/var/packages/vpn-client/bin/vpn-client start
```

**Stop VPN Client:**
```bash
/var/packages/vpn-client/bin/vpn-client stop
```

**Check VPN Client Status:**
```bash
/var/packages/vpn-client/bin/vpn-client status
```

**View Logs:**
```bash
tail -f /var/packages/vpn-client/target/var/log/vpn-client.log
```

## Configuration

### OpenVPN Configuration

1. Prepare your OpenVPN configuration file (`.ovpn` or `.conf`)
2. Copy to NAS via SSH or File Station:
   ```bash
   scp your-config.ovpn admin@YOUR_NAS_IP:/var/packages/vpn-client/target/etc/openvpn.conf
   ```
3. Set permissions:
   ```bash
   ssh admin@YOUR_NAS_IP
   sudo chmod 600 /var/packages/vpn-client/target/etc/openvpn.conf
   ```
4. Start the VPN client

### WireGuard Configuration

1. Prepare your WireGuard configuration file (`.conf`)
2. Copy to NAS:
   ```bash
   scp your-wireguard.conf admin@YOUR_NAS_IP:/var/packages/vpn-client/target/etc/wireguard.conf
   ```
3. Set permissions:
   ```bash
   ssh admin@YOUR_NAS_IP
   sudo chmod 600 /var/packages/vpn-client/target/etc/wireguard.conf
   ```
4. Start the VPN client

### Web UI Configuration (Optional)

The package includes a basic web UI accessible at:
```
https://YOUR_NAS_IP:8443/vpn-client
```

(Note: Port 8443 is configured in the INFO file and may vary based on your DSM settings)

## Package Structure

The generated SPK contains:

```
vpn-client-1.0.0-x86_64.spk
├── INFO                    # Package metadata
├── package.tgz            # Package binaries and files
│   ├── bin/
│   │   └── vpn-client     # Main control script
│   ├── etc/vpn-client/    # Configuration directory
│   └── var/packages/vpn-client/
│       ├── web/           # Web UI files
│       └── target/        # Runtime directories
└── scripts.tgz            # Installation scripts
    ├── postinst           # Post-installation hook
    ├── preinst            # Pre-installation hook
    └── start-stop-status  # Service management
```

## Customization

### Modifying Package Information

Edit the `INFO` section in `build-vpn-client.sh`:

```bash
cat > INFO << 'EOF'
package="vpn-client"
version="1.0.0"           # Update version here
os_min_ver="7.1"          # Minimum DSM version
arch="x86_64"             # Target architecture
description="Your custom description"
EOF
```

### Changing Package Version and Architecture

Before running the script:
```bash
PACKAGE_NAME="vpn-client"
VERSION="1.1.0"           # Update to new version
ARCH="aarch64"            # Change for different CPU architecture
SYNOLOGY_ARCH="aarch64-7.1"
```

### Adding Custom Binaries

Modify the `postinst` script to install additional packages:

```bash
# Add this line in the postinst section
ipkg install custom-package-name
```

## Supported Architectures

The script can be modified to build for different Synology models:

| Architecture | Synology Models | Variable |
|-------------|-----------------|----------|
| x86_64 | DS3615xs, DS3617xs, RS3617xs, DS918+, DS920+, DS725+ | x86_64 |
| aarch64 | DS220+, DS420+, DS920+, DS1821+ | aarch64 |
| armv7 | DS213, DS213j, DS216, DS216j | armv7 |
| armv8 | DS418play, DS918play | armv8 |

Modify `ARCH` and `SYNOLOGY_ARCH` in the script for your target model.

## Troubleshooting

### Package Installation Fails

**Error: "Package format not recognized"**
- Ensure the SPK file was built correctly on Linux/macOS with bash
- Check that `tar` command executed successfully
- Try rebuilding the package

**Error: "Insufficient permissions"**
- Ensure you're logged in as Administrator
- Check DSM security settings allow package installation

### VPN Connection Issues

**VPN won't start:**
```bash
ssh admin@YOUR_NAS_IP
cat /var/packages/vpn-client/target/var/log/vpn-client.log
```

**Cannot access configuration:**
```bash
# Check file permissions
ssh admin@YOUR_NAS_IP
ls -la /var/packages/vpn-client/target/etc/
```

**Logs show "Permission denied":**
```bash
ssh admin@YOUR_NAS_IP
sudo chown -R vpn-client:vpn-client /var/packages/vpn-client/target/var
```

### Port Conflicts

If port 8443 is already in use, modify the `serviceport` in the INFO section:
```bash
serviceport=9443    # Change to unused port
```

## Uninstallation

### Via DSM Package Center
1. Go to Package Center
2. Find "VPN Client" in your installed packages
3. Click "Uninstall"
4. Confirm removal

### Via SSH
```bash
ssh admin@YOUR_NAS_IP
sudo /var/packages/vpn-client/bin/vpn-client stop
sudo ipkg remove vpn-client
```

## Security Considerations

1. **Configuration File Security**
   - Always set restrictive permissions on VPN config files (600)
   - Don't store credentials in plaintext if possible
   - Use certificate-based authentication when available

2. **Log Files**
   - VPN logs may contain sensitive information
   - Review and rotate logs regularly
   - Store backups securely

3. **Package Updates**
   - Check for updates to OpenVPN/WireGuard
   - Rebuild package with latest versions
   - Test updates on non-production NAS first

## Advanced Usage

### Scheduling VPN Connection

Create a cron job to automatically start VPN on boot:

```bash
ssh admin@YOUR_NAS_IP
sudo crontab -e
```

Add:
```
@reboot /var/packages/vpn-client/bin/vpn-client start
```

### Monitoring VPN Connection

Check if VPN is connected:
```bash
ssh admin@YOUR_NAS_IP
/var/packages/vpn-client/bin/vpn-client status
```

Monitor connection continuously:
```bash
ssh admin@YOUR_NAS_IP
watch -n 5 '/var/packages/vpn-client/bin/vpn-client status'
```

### Multiple VPN Profiles

To support multiple VPN profiles, modify the `vpn-client` script to accept a profile parameter:

```bash
/var/packages/vpn-client/bin/vpn-client start profile1
/var/packages/vpn-client/bin/vpn-client stop profile1
```

## Rebuilding the Package

After modifications:

```bash
# Clean previous build
rm -rf build/ vpn-client-*.spk

# Run the script again
./build-vpn-client.sh

# Transfer new SPK to NAS
scp vpn-client-1.0.0-x86_64.spk admin@YOUR_NAS_IP:/home/admin/
```

Uninstall the old version first, then install the new one.

## Support & References

- **Synology Package Development**: https://developer.synology.com/tools
- **DSM 7.1 Documentation**: https://www.synology.com/dsm
- **OpenVPN Documentation**: https://openvpn.net/docs/
- **WireGuard Documentation**: https://www.wireguard.com/quickstart/

## Contributing

Found issues or have improvements? 

1. Report issues to the GitHub repository
2. Submit pull requests with enhancements
3. Share your custom configurations (sanitized)

## License

This project is provided as-is. Ensure compliance with OpenVPN and WireGuard licenses when using.

## Changelog

### v1.0.0 (Initial Release)
- Support for OpenVPN client on Synology DS725+
- Support for WireGuard client (experimental)
- Basic web UI for configuration
- Auto-start/stop functionality
- Log rotation and management

---

**Last Updated**: 2026-06-22  
**Compatible with**: DSM 7.1+  
**Target Device**: Synology DS725+
