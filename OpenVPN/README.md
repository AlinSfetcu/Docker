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
