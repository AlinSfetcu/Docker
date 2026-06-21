# OpenVPN Docker Project

A production-ready OpenVPN server deployment using Docker and Docker Compose, based on kylemanna's docker-openvpn image with proper configuration and security hardening.

## Project Overview

This project containerizes OpenVPN in Docker with:
- **kylemanna/openvpn** image for the VPN server
- Persistent configuration storage via Docker named volumes
- Proper file permissions and ownership (aligned with kylemanna's best practices)
- IPv6 support and health monitoring
- Automatic log rotation to prevent disk space issues
- Custom Alpine-based support image with OpenVPN utilities

## Quick Start

### Prerequisites

- Docker & Docker Compose installed
- A domain name (for certificate generation)
- Network access to port 1194/UDP

### 1. Create the OpenVPN Data Volume

```bash
docker volume create openvpn-data
```

### 2. Generate Server Configuration

Replace `YOUR.VPN.DOMAIN` with your actual domain:

```bash
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://YOUR.VPN.DOMAIN
```

### 3. Initialize the PKI (Certificate Authority)

This will prompt you for a passphrase:

```bash
docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  ovpn_initpki
```

### 4. Start the OpenVPN Server

```bash
docker-compose up -d
```

### 5. Generate Client Certificates

For each client, generate a certificate:

```bash
docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  easyrsa build-client-full <CLIENT_NAME> nopass
```

### 6. Extract Client Configuration

```bash
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_getclient <CLIENT_NAME> > <CLIENT_NAME>.ovpn
```

## Setting Up NAS as VPN Server

This section explains how to deploy the OpenVPN server on a Synology NAS to allow remote devices to securely access your NAS and home network.

### Prerequisites for NAS Deployment

- **Synology NAS** with Docker support (DS920+, DS721+2, DS225+, DS725+, etc.)
- **Docker** installed via Package Center
- **Port forwarding** configured on your router
- **Dynamic DNS** (optional but recommended) to handle changing IP addresses
- **Domain name** or Dynamic DNS hostname
- Sufficient storage space (1-2GB minimum)

### Installation on Synology NAS

#### Step 1: Prepare the NAS Environment

SSH into your Synology NAS:
```bash
ssh admin@YOUR_NAS_IP
```

Create a working directory:
```bash
mkdir -p /volume1/docker/openvpn
cd /volume1/docker/openvpn
```

#### Step 2: Create docker-compose.yml on NAS

Create the `docker-compose.yml` file:
```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  openvpn-server:
    image: kylemanna/openvpn:latest
    container_name: openvpn-server
    ports:
      - "1194:1194/udp"
    volumes:
      - openvpn-data:/etc/openvpn
      - /etc/localtime:/etc/localtime:ro
    cap_add:
      - NET_ADMIN
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    healthcheck:
      test: ["CMD", "netstat", "-tlnup"]
      interval: 30s
      timeout: 5s
      retries: 3

volumes:
  openvpn-data:
    driver: local
EOF
```

#### Step 3: Initialize OpenVPN on NAS

Generate the server configuration with your NAS's public IP or domain:

```bash
# For external IP (not recommended for changing IPs)
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://YOUR.PUBLIC.IP.ADDRESS

# For Dynamic DNS (recommended)
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://your-nas.ddns.com
```

Initialize the PKI and certificate authority:
```bash
docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  ovpn_initpki
```

Generate certificates for each client:
```bash
docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  easyrsa build-client-full laptop nopass

docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  easyrsa build-client-full smartphone nopass
```

#### Step 4: Start the VPN Server

```bash
docker-compose up -d
```

Verify the server is running:
```bash
docker-compose ps
docker-compose logs -f openvpn-server
```

### Network Configuration for NAS VPN Server

#### Router Port Forwarding

To allow external clients to connect to your VPN server:

1. **Access your router's admin interface** (usually 192.168.1.1 or 192.168.0.1)
2. **Enable port forwarding**:
   - External Port: `1194`
   - Protocol: `UDP`
   - Internal IP: `YOUR_NAS_LOCAL_IP` (e.g., 192.168.1.50)
   - Internal Port: `1194`

3. **Test port forwarding** (from external network):
```bash
nmap -sU -p 1194 YOUR.PUBLIC.IP.ADDRESS
# Should show: 1194/udp open|filtered openvpn
```

#### Dynamic DNS Setup (Recommended)

If your ISP changes your IP address regularly:

1. **Choose a Dynamic DNS provider**: No-IP, DynDNS, FreeDNS, etc.
2. **Install DDNS client on NAS**:
   - Go to NAS Control Panel → Network → General
   - Set up Dynamic DNS with your provider
   - Test connectivity: `nslookup your-nas.ddns.com`

3. **Use DDNS hostname in OpenVPN config**:
```bash
# Regenerate config with DDNS hostname
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://your-nas.ddns.com
```

#### Network Access Configuration

Allow clients to access resources on your home network:

```bash
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://your-nas.ddns.com \
  -r 192.168.1.0/24 \
  -N \
  -c
```

This enables:
- `-r 192.168.1.0/24`: Route to home network
- `-N`: NAT mode (needed for NAS to access other network resources)
- `-c`: Client-to-client communication

### Firewall Configuration for NAS

#### On Synology NAS

If the NAS firewall is enabled (Control Panel → Security → Firewall):

1. Go to **Control Panel → Security → Firewall**
2. Click **Firewall Rules** or **Port Rules**
3. **Add a rule** to allow incoming UDP on port 1194:
   - Protocol: UDP
   - Port: 1194
   - Allow: Yes

Or via SSH:
```bash
sudo ufw allow 1194/udp
```

#### On Your Router

1. Disable UPnP if not needed for additional security
2. Set up a static route (optional) for better performance:
   - Destination: `192.168.255.0/24` (OpenVPN subnet)
   - Gateway: `192.168.1.50` (NAS IP)

### Client Connection to NAS VPN Server

#### Step 1: Get Client Configuration

Extract the `.ovpn` file for each client:

```bash
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_getclient laptop > laptop.ovpn

docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_getclient smartphone > smartphone.ovpn
```

Download these files from the NAS via SSH/SFTP or File Station

#### Step 2: Install OpenVPN Client

**Windows:**
- Download OpenVPN GUI: https://openvpn.net/community-downloads/
- Install and import the `.ovpn` file
- Right-click → Connect

**macOS:**
- Install via Homebrew: `brew install openvpn`
- Or use Tunnelblick: https://tunnelblick.net/
- Import the `.ovpn` file

**Linux:**
```bash
sudo apt install openvpn
sudo openvpn --config laptop.ovpn
```

**iOS:**
- Install "OpenVPN Connect" from App Store
- Open the `.ovpn` file and import
- Enable and connect

**Android:**
- Install "OpenVPN Connect" from Google Play
- Open the `.ovpn` file and import
- Enable and connect

#### Step 3: Connect to VPN

1. Open OpenVPN client
2. Select the configuration file
3. Click Connect/Enable
4. Wait for connection confirmation

**Verify connection:**
```bash
# On client machine, check IP
curl https://api.ipify.org  # Should show your NAS's public IP

# Or via SSH to NAS
docker-compose logs openvpn-server | grep -i "client.*connected"
```

### Advanced NAS VPN Server Configuration

#### Enable Two-Factor Authentication

For enhanced security on NAS:

```bash
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://your-nas.ddns.com -2 -C AES-256-CBC

docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  ovpn_initpki

docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  ovpn_otp_user laptop
```

#### Static Client IPs

Assign fixed VPN IPs to clients:

```bash
# SSH to NAS
ssh admin@YOUR_NAS_IP
cd /volume1/docker/openvpn

# Create client-specific config
mkdir -p ./ccd
cat > ./ccd/laptop << EOF
ifconfig-push 192.168.255.10 192.168.255.11
EOF

cat > ./ccd/smartphone << EOF
ifconfig-push 192.168.255.20 192.168.255.21
EOF

# Restart container to apply
docker-compose restart openvpn-server
```

#### Bandwidth Limiting

Prevent VPN from consuming all NAS bandwidth:

```bash
docker update --memory=512m openvpn-server
```

Or use Linux traffic control in `docker-compose.yml`:
```yaml
  openvpn-server:
    ...
    ulimits:
      nofile:
        soft: 4096
        hard: 8192
```

#### Split Tunnel (Optional)

Allow clients to route only specific traffic through VPN:

```bash
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://your-nas.ddns.com -d -r 192.168.1.0/24
```

This disables default route but routes home network traffic through VPN.

### NAS-Specific Considerations

#### Docker Storage Location

On Synology, Docker data is stored in:
```bash
/var/lib/docker/volumes/openvpn-data
```

To change storage location:
```bash
# Move to larger volume if needed
mv /var/lib/docker/volumes/openvpn-data /volume1/docker/openvpn-data
docker volume create --opt type=none --opt o=bind --opt device=/volume1/docker/openvpn-data openvpn-data
```

#### NAS Performance

Monitor NAS resources while VPN is running:
```bash
ssh admin@YOUR_NAS_IP
# Check CPU usage
top

# Check memory usage
free -h

# Check disk I/O
iostat -x 1 5
```

Typical VPN server usage on NAS:
- CPU: 5-15% per active connection
- RAM: 50-100MB base + 10-20MB per connection
- Disk I/O: Minimal (logs only)

#### Scheduled Backups

Backup your VPN configuration daily:

```bash
# SSH to NAS
ssh admin@YOUR_NAS_IP

# Create backup script
cat > /volume1/docker/backup-openvpn.sh << 'SCRIPT'
#!/bin/bash
BACKUP_DIR="/volume1/docker/backups"
mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_DIR/openvpn-$(date +%Y%m%d-%H%M%S).tar.gz" \
  -C /var/lib/docker/volumes/openvpn-data/_data .

# Keep only last 7 backups
find "$BACKUP_DIR" -name "openvpn-*.tar.gz" -mtime +7 -delete
SCRIPT

chmod +x /volume1/docker/backup-openvpn.sh

# Add to crontab (runs daily at 2 AM)
(crontab -l; echo "0 2 * * * /volume1/docker/backup-openvpn.sh") | crontab -
```

## Project Structure

```
Docker/
├── README.md                     # Main project documentation
├── Build/
│   ├── dockerfile               # Custom Alpine image with OpenVPN
│   ├── Compose.yaml             # Docker Compose orchestration
│   └── OpenVPN/
│       └── README.md            # This file
└── openvpn-data/                # Volume mount (created at runtime)
    ├── openvpn.conf             # Server configuration
    ├── pki/                      # Certificate authority & keys
    ├── ccd/                      # Per-client configuration
    └── crl.pem                   # Certificate revocation list
```

## Configuration Details

### Docker Compose Services

#### **openvpn-server** (kylemanna/openvpn)
- **Image**: `kylemanna/openvpn:latest`
- **Port**: `1194/UDP` (can be changed in Compose.yaml)
- **Volume**: `openvpn-data:/etc/openvpn` (persistent configuration)
- **Network Capability**: `NET_ADMIN` (required for TUN device management)
- **Health Check**: Monitors connectivity every 30 seconds
- **Restart Policy**: Auto-restarts unless manually stopped

#### **empty-image** (Custom Alpine)
- **Build Context**: Custom dockerfile with OpenVPN utilities
- **Purpose**: Provides OpenVPN utilities and management tools
- **Permissions**: Properly configured for `nobody:nogroup` user

### File Permissions

All OpenVPN paths are created with proper permissions aligned with kylemanna's practices:

| Path | Permissions | Owner | Purpose |
|------|-------------|-------|---------|
| `/etc/openvpn` | `755` | root | Configuration directory |
| `/etc/openvpn/certs` | `755` | root | Certificates |
| `/etc/openvpn/keys` | `755` | root | Private keys (readable by nobody user) |
| `/var/log/openvpn` | `755` | nobody | Log storage |
| `/var/run/openvpn` | `755` | nobody | Runtime sockets |

## Advanced Configuration

### Enable Two-Factor Authentication (OTP)

Generate config with OTP support:

```bash
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://YOUR.VPN.DOMAIN -2 -C AES-256-CBC
```

Initialize PKI:

```bash
docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  ovpn_initpki
```

Create OTP user:

```bash
docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  ovpn_otp_user <USERNAME>
```

### Enable Client-to-Client Communication

When generating config, add the `-c` flag:

```bash
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://YOUR.VPN.DOMAIN -c
```

### Custom DNS Servers

Push custom DNS servers to clients:

```bash
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://YOUR.VPN.DOMAIN -n 1.1.1.1 -n 8.8.8.8
```

### NAT Configuration (Access External Networks)

Enable NAT for clients to access external networks:

```bash
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://YOUR.VPN.DOMAIN -N
```

### Static Client IPs

Create a file for each client in the volume's `ccd/` directory:

```bash
# Inside container or via volume mount
cat > openvpn-data/ccd/<CLIENT_NAME> << EOF
ifconfig-push 192.168.255.10 192.168.255.11
EOF
```

### Split-Tunnel (Disable Default Route)

Clients access only VPN resources, not all internet traffic:

```bash
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://YOUR.VPN.DOMAIN -d
```

## Management Commands

### View Server Logs

```bash
docker-compose logs -f openvpn-server
```

### Check Container Health

```bash
docker-compose ps
```

### Restart the Server

```bash
docker-compose restart openvpn-server
```

### Revoke a Client Certificate

```bash
docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  easyrsa revoke <CLIENT_NAME>
```

Then update the CRL:

```bash
docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  easyrsa gen-crl
```

### List Generated Clients

```bash
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ls -la pki/issued/
```

## Security Considerations

1. **Private Key Protection**: The CA private key (`pki/private/ca.key`) should be:
   - Protected with a strong passphrase during generation
   - Kept separate from the running server for maximum security
   - Backed up securely and encrypted

2. **TLS Authentication**: The generated `ta.key` file adds an extra layer of HMAC authentication

3. **Certificate Revocation**: Regularly check and update the CRL (Certificate Revocation List)

4. **Docker Volume Security**: The `openvpn-data` volume contains sensitive data
   - Ensure proper host filesystem permissions
   - Back up the volume regularly
   - Use encrypted storage for production

5. **Network Security**: 
   - Firewall port 1194/UDP appropriately
   - Consider using a WAF or DDoS protection
   - Monitor connection logs

## Environment Variables

Optional environment variables for advanced configuration (set during `ovpn_genconfig`):

| Variable | Example | Purpose |
|----------|---------|---------|
| `OVPN_SERVER` | `192.168.255.0/24` | Internal VPN subnet for clients |
| `OVPN_DEVICE` | `tun` | TUN (routed) or TAP (bridged) mode |
| `OVPN_PROTO` | `udp` or `tcp` | Protocol (UDP recommended) |
| `OVPN_PORT` | `1194` | OpenVPN port |
| `OVPN_DEFROUTE` | `1` | Push default route to clients |
| `OVPN_ROUTES` | `192.168.0.0/24` | Additional routes to push |
| `OVPN_NATDEVICE` | `eth0` | Interface for NAT |
| `OVPN_DNS_SERVERS` | `1.1.1.1 8.8.8.8` | DNS servers to push |
| `OVPN_COMP_LZO` | `1` | Enable LZO compression |
| `OVPN_CLIENT_TO_CLIENT` | `1` | Allow client-to-client communication |

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs openvpn-server

# Verify volume exists
docker volume ls | grep openvpn-data

# Verify configuration file exists
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn ls -la
```

### Cannot Connect to VPN

1. Verify firewall allows 1194/UDP inbound
2. Check that client certificate is not revoked
3. Verify DNS/hostname resolution for your domain
4. Check client `.ovpn` configuration file for correct server address

### Connection Drops

1. Check keepalive settings in server config
2. Verify network stability
3. Check firewall rules for UDP timeout issues
4. Consider increasing MTU or enabling fragmentation

### Performance Issues

1. Check CPU/memory usage: `docker stats openvpn-server`
2. Enable compression if bandwidth-limited: `-C LZ4`
3. Check for certificate validation delays
4. Monitor log file size (auto-rotated at 10MB)

## Monitoring & Maintenance

### Log Rotation

Logs are automatically rotated:
- Max file size: 10MB
- Max files retained: 3
- Configured in `Compose.yaml` logging section

### Health Check

The container includes a health check that:
- Runs every 30 seconds
- Tests if OpenVPN is listening on port 1194
- Marks container unhealthy after 3 failed checks
- Timeout: 5 seconds per check

Monitor health:

```bash
docker-compose ps
# Look for "(healthy)" or "(unhealthy)" status
```

## Backup & Restore

### Backup Configuration

```bash
# Backup the entire volume
docker run --rm -v openvpn-data:/etc/openvpn -v $(pwd):/backup \
  alpine tar czf /backup/openvpn-backup-$(date +%s).tar.gz -C / etc/openvpn
```

### Restore Configuration

```bash
# Restore from backup
docker run --rm -v openvpn-data:/etc/openvpn -v $(pwd):/backup \
  alpine tar xzf /backup/openvpn-backup-<timestamp>.tar.gz -C /
```

## Support & References

- **kylemanna/docker-openvpn**: https://github.com/kylemanna/docker-openvpn
- **OpenVPN Documentation**: https://openvpn.net/community-resources/
- **Applied Crypto Hardening**: https://github.com/BetterCrypto/Applied-Crypto-Hardening
- **Docker Documentation**: https://docs.docker.com/

## License

This project uses kylemanna/openvpn which is under the MIT License. See the original repository for details.

## Contributing

Feel free to submit issues and enhancement requests to improve this Docker setup.
