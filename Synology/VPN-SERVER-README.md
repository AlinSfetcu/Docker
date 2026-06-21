# Synology VPN Server Package (DS725+)

Build script and compiled Synology Package for installing an OpenVPN server directly on your Synology NAS via the Package Manager.

## Files in This Directory

- **build-vpn-client.sh** - Script to build the VPN client package
- **vpn-client-1.0.0-x86_64.spk** - Compiled VPN client package
- **build-vpn-server.sh** - Script to build the VPN server package
- **vpn-server-1.0.0-x86_64.spk** - Compiled VPN server package (**Use this for NAS VPN Server**)
- **README.md** - This file

## Quick Start: Installing VPN Server on DS725+

### Step 1: Download the SPK Package

Download `vpn-server-1.0.0-x86_64.spk` from this repository to your computer.

### Step 2: Access Synology Package Center

1. Open DSM (Synology web interface) on your NAS
2. Go to **Package Center** in the main menu
3. Click **Manual Install** (top-right corner)

### Step 3: Install the Package

1. Select the `vpn-server-1.0.0-x86_64.spk` file
2. Click **Next** and follow the wizard
3. Accept the license and permissions
4. Click **Install** to complete installation

### Step 4: Configure OpenVPN

The package will be installed but requires configuration. You have two options:

**Option A: Via SSH/Docker (Recommended)**

If you're comfortable with the command line, use Docker to generate configuration:

```bash
# SSH into your NAS
ssh admin@YOUR_NAS_IP

# Create a temporary directory for setup
mkdir -p ~/vpn-setup && cd ~/vpn-setup

# Generate server configuration with Docker
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://your-nas.ddns.com

# Initialize PKI (generates certificates)
docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  ovpn_initpki
```

Then copy the configuration to the VPN Server package directory:

```bash
# Create backup of generated config
docker run -v openvpn-data:/etc/openvpn --rm -v ~/vpn-setup:/backup \
  alpine tar czf /backup/openvpn-config.tar.gz -C / etc/openvpn

# Extract to VPN Server location
sudo tar xzf ~/vpn-setup/openvpn-config.tar.gz -C /var/packages/vpn-server/target/
```

**Option B: Manual Configuration (Advanced)**

1. SSH into your NAS: `ssh admin@YOUR_NAS_IP`
2. Create configuration directory:
   ```bash
   sudo mkdir -p /var/packages/vpn-server/target/etc/openvpn
   ```
3. Copy your OpenVPN configuration files to this directory
4. Ensure proper permissions:
   ```bash
   sudo chmod 755 /var/packages/vpn-server/target/etc/openvpn
   sudo chmod 600 /var/packages/vpn-server/target/etc/openvpn/*.key
   ```

### Step 5: Start the VPN Server

1. In DSM Package Center, find **VPN Server** in your installed packages
2. Click the **Run** button to start the service
3. Check **View logs** to verify it started successfully

## Managing the VPN Server

### Via DSM Package Center

- **Start**: Click "Run" button
- **Stop**: Click "Stop" button
- **View Logs**: Package Center logs
- **Enable Auto-start**: Right-click package → Auto-start on boot

### Via SSH Command Line

Connect via SSH:
```bash
ssh admin@YOUR_NAS_IP
```

**Start VPN Server:**
```bash
/var/packages/vpn-server/bin/vpn-server start
```

**Stop VPN Server:**
```bash
/var/packages/vpn-server/bin/vpn-server stop
```

**Check Status:**
```bash
/var/packages/vpn-server/bin/vpn-server status
```

**View Logs:**
```bash
tail -f /var/packages/vpn-server/target/var/log/vpn-server.log
```

## Network Configuration

### Port Forwarding

Ensure your router forwards port 1194/UDP to your NAS:

1. Log into your router's admin panel
2. Find Port Forwarding settings
3. Add a new rule:
   - External Port: `1194`
   - Protocol: `UDP`
   - Internal IP: `YOUR_NAS_LOCAL_IP` (e.g., 192.168.1.50)
   - Internal Port: `1194`

### Firewall Rules

If your NAS firewall is enabled:

1. DSM → Control Panel → Security → Firewall
2. Add a rule allowing UDP on port 1194
3. Or via SSH:
   ```bash
   sudo synoservicectl --enable vpn-server
   ```

### Dynamic DNS (Recommended)

Use a Dynamic DNS service if your ISP changes your public IP:

1. In DSM Control Panel, find Dynamic DNS settings
2. Configure with your provider (No-IP, DynDNS, etc.)
3. Use the DDNS hostname in your OpenVPN configuration

## Generating Client Certificates

Once configured, generate certificates for remote clients:

```bash
# SSH to NAS
ssh admin@YOUR_NAS_IP

# List available certificates
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ls -la pki/issued/

# Generate new client certificate
docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  easyrsa build-client-full client-name nopass

# Extract .ovpn file for client
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_getclient client-name > client-name.ovpn
```

Download the `.ovpn` file and use with your VPN client.

## Troubleshooting

### VPN Server Won't Start

```bash
ssh admin@YOUR_NAS_IP
cat /var/packages/vpn-server/target/var/log/vpn-server.log
```

**Common Issues:**
- Configuration file not found - ensure `openvpn.conf` exists in the config directory
- Port already in use - check if another service uses port 1194
- Permission denied - verify file permissions are correct

### Clients Can't Connect

1. **Verify port forwarding is working:**
   ```bash
   nmap -sU -p 1194 YOUR.PUBLIC.IP.ADDRESS
   ```

2. **Check firewall:**
   ```bash
   ssh admin@YOUR_NAS_IP
   sudo iptables -L -n | grep 1194
   ```

3. **Verify DNS/hostname:**
   ```bash
   nslookup your-nas.ddns.com
   ```

### Slow Connection/Performance

1. Check NAS CPU usage: `top` (via SSH)
2. Check bandwidth: `iftop` (if installed)
3. Consider limiting connections or enabling compression

## Advanced Configuration

### Static Client IPs

Assign fixed IPs to specific clients:

```bash
ssh admin@YOUR_NAS_IP
cd /var/packages/vpn-server/target/etc/openvpn

# Create client config directory if not exists
mkdir -p ccd

# Add static IP for a client
cat > ccd/laptop << EOF
ifconfig-push 192.168.255.10 192.168.255.11
EOF
```

### Client-to-Client Communication

Edit your OpenVPN config to add:
```
client-to-client
```

This allows VPN clients to communicate with each other.

### Network Access

Allow clients to access resources on your home network:

1. Edit `/var/packages/vpn-server/target/etc/openvpn/openvpn.conf`
2. Add routes for your home network:
   ```
   push "route 192.168.1.0 255.255.255.0"
   push "route 192.168.0.0 255.255.255.0"
   ```
3. Enable NAT/masquerading on the NAS

### Two-Factor Authentication

For enhanced security:

```bash
docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  ovpn_otp_user username
```

Then provide the generated OTP secret to the client.

## Uninstalling the Package

### Via DSM Package Center

1. Go to Package Center
2. Find VPN Server
3. Click **Uninstall**
4. Confirm removal

### Via SSH

```bash
ssh admin@YOUR_NAS_IP
sudo ipkg remove vpn-server
```

All configuration will be preserved for reinstallation.

## Package Details

- **Package Name**: vpn-server
- **Version**: 1.0.0
- **Architecture**: x86_64 (DS725+, DS920+, DS721+2, DS225+)
- **Minimum DSM Version**: 7.1
- **Port**: 1194/UDP
- **Config Directory**: `/var/packages/vpn-server/target/etc/openvpn/`
- **Log Directory**: `/var/packages/vpn-server/target/var/log/`

## Security Considerations

1. **Use DDNS** - Don't expose your public IP directly
2. **Enable Firewall** - Restrict VPN access to authorized networks
3. **Rotate Certificates** - Regenerate client certs periodically
4. **Update OpenVPN** - Keep OpenVPN binary updated
5. **Use Strong Passphrases** - Protect your CA private key
6. **Monitor Logs** - Check for unauthorized connection attempts

## Backing Up Your Configuration

```bash
# SSH to NAS
ssh admin@YOUR_NAS_IP

# Create backup
tar czf ~/vpn-server-backup-$(date +%Y%m%d).tar.gz \
  /var/packages/vpn-server/target/etc/openvpn

# Download to computer
scp admin@YOUR_NAS_IP:~/vpn-server-backup-*.tar.gz .
```

## Support & References

- **kylemanna/docker-openvpn**: https://github.com/kylemanna/docker-openvpn
- **OpenVPN Documentation**: https://openvpn.net/community-resources/
- **Synology NAS**: https://www.synology.com/dsm
- **Dynamic DNS Services**: https://no-ip.com, https://www.dyndns.com/

## Building Your Own SPK

If you want to rebuild the package with custom configurations:

```bash
# Edit the build script
nano build-vpn-server.sh

# Rebuild the package
bash build-vpn-server.sh
```

The new SPK will be created in the `build/` directory.

---

**Last Updated**: 2026-06-22  
**Compatible with**: DSM 7.1+  
**Target Device**: Synology DS725+
