# VPN Server Setup Wizard - No SSH Required

Complete VPN Server installation and configuration for Synology NAS **without SSH access**. Everything is done through a beautiful web-based setup wizard.

## Quick Summary

This package provides a **web-based setup wizard** that lets you:
- ✅ Configure OpenVPN server without SSH
- ✅ Upload certificates and configuration files
- ✅ Auto-generate configuration if needed
- ✅ Manage the VPN server from the web interface
- ✅ Monitor server status and connected clients

## Installation on Synology DS725+ (No SSH Required)

### Step 1: Download the Package

Download **`vpn-server-wizard-2.0.0-x86_64.spk`** from the repository:
- https://github.com/AlinSfetcu/Docker/blob/main/Synology/vpn-server-wizard-2.0.0-x86_64.spk

### Step 2: Install via Package Center

1. **Open DSM web interface** on your NAS (http://your-nas-ip:5000)
2. **Login** with your administrator account
3. Go to **Package Center**
4. Click **Manual Install** (top-right button)
5. Select the downloaded `vpn-server-wizard-2.0.0-x86_64.spk` file
6. Click **Next** and follow the installation wizard
7. Accept permissions and complete installation
8. The package will be installed in your Package Center

### Step 3: Access the Setup Wizard

Once installation completes:

1. **Find "VPN Server Wizard"** in your Package Center (installed packages)
2. Click **Run** or open it from the package detail page
3. The **web-based setup wizard** opens in a new window
4. Follow the 5-step wizard to configure your VPN server

## Using the Setup Wizard

### Step 1: Welcome

- Review what you need (certificates and configuration file)
- Option to **auto-generate** configuration with pre-configured settings
- If auto-generating, enter your NAS domain/IP

### Step 2: OpenVPN Configuration

**If you HAVE a configuration file:**
1. Paste your OpenVPN configuration (openvpn.conf) into the text area
2. Ensure it includes all required options (port, proto, dev, certificate paths, etc.)

**If you DON'T have a configuration file:**
- Use the auto-generate option from Step 1
- The wizard will create a basic working configuration

### Step 3: Upload Certificate Files

Upload these files by clicking each upload area and selecting from your computer:

1. **CA Certificate** (ca.crt) - The Certificate Authority certificate
2. **Server Certificate** (server.crt) - Your server's certificate
3. **Server Private Key** (server.key) - Your server's private key
4. **Diffie-Hellman Parameters** (dh.pem) - DH parameters file

**File formats supported:**
- `.crt` - Certificate files
- `.key` - Private key files
- `.pem` - PEM format files

### Step 4: Review Configuration

Review your setup:
- Port: 1194/UDP
- Protocol: UDP
- VPN Device: TUN
- Configuration directory path
- **Important:** Ensure your router firewall allows UDP port 1194

### Step 5: Complete Setup

🎉 Setup is complete! The wizard shows next steps:

1. **Start the VPN Server**
   - Go back to Package Center
   - Find "VPN Server Wizard"
   - Click "Run" to start the service

2. **Configure Router Firewall**
   - Port forward: External 1194 UDP → NAS 1194 UDP
   - Allow incoming UDP on port 1194

3. **Set up Dynamic DNS** (recommended)
   - Use a DDNS service if your ISP changes your IP
   - Access the wizard again to update the domain if needed

4. **Generate Client Certificates**
   - See section below for client setup

5. **Connect Remote Clients**
   - Download client .ovpn files from your server
   - Use with OpenVPN client applications

## Without SSH: How to Get Configuration Files

### Option A: Use Auto-Generate (Recommended)

In Step 1 of the wizard, check **"Auto-generate with pre-configured settings"** and the package will create everything for you automatically.

### Option B: Pre-generate Using Docker (Different NAS)

If you have another device with Docker:

```bash
# On a Linux/Mac with Docker
docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_genconfig -u udp://your-nas.ddns.com

docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  ovpn_initpki

# Then transfer the files via download
docker run -v openvpn-data:/etc/openvpn --rm -v ~/Downloads:/backup \
  alpine tar czf /backup/openvpn-config.tar.gz -C / etc/openvpn

# Extract and upload individual files using the wizard
```

### Option C: Use Pre-Made Templates

Contact your VPN administrator or use a pre-configured template from kylemanna/docker-openvpn documentation.

## Managing VPN Server (No SSH)

### Start/Stop the Server

1. Open Package Center
2. Find "VPN Server Wizard"
3. Click **Run** to start
4. Click **Stop** to stop
5. Check the status indicator

### View Server Status

1. Open the wizard again to see current status
2. View connected clients on the dashboard
3. Check server logs through the interface

### Manage Clients (Without SSH)

Since you don't have SSH access, you'll need to:

1. **Add clients** - Have your VPN administrator generate client certificates
2. **Revoke clients** - Ask your administrator to revoke certificates
3. **Create static IPs** - Provide configuration to administrator

**Alternative:** Share read-only SSH access with your administrator so they can manage clients for you.

## Troubleshooting (No SSH)

### Server Won't Start

1. **Check configuration** - Review the OpenVPN config in the wizard
2. **Verify certificates** - Ensure all certificate files were uploaded
3. **Check port** - Verify port 1194 isn't used by another service
4. **Review logs** - Access through the Package Center logs view

### Clients Can't Connect

1. **Router firewall** - Ensure port 1194 UDP is allowed
2. **Port forwarding** - Configure router to forward 1194 to NAS IP
3. **Domain/IP** - Verify clients are connecting to correct domain/IP
4. **Certificates** - Ensure client certificates are valid

### Slow Connection

1. **Check NAS resources** - Monitor through DSM
2. **Network bandwidth** - Check if NAS network is saturated
3. **VPN settings** - Enable compression in configuration

### Configuration Errors

If the wizard shows configuration errors:

1. **Re-paste configuration** - Use copy/paste carefully without extra spaces
2. **Verify format** - Check for line ending issues (use Unix LF, not Windows CRLF)
3. **Use auto-generate** - Let the wizard create a working config

## Generating Client Certificates (Without SSH)

### Option A: Ask Your Administrator

If your NAS administrator has SSH access, they can generate clients using:

```bash
docker run -v openvpn-data:/etc/openvpn --rm -it kylemanna/openvpn \
  easyrsa build-client-full laptop nopass

docker run -v openvpn-data:/etc/openvpn --rm kylemanna/openvpn \
  ovpn_getclient laptop > laptop.ovpn
```

### Option B: Use a Web Panel (Future Enhancement)

The wizard can be extended with a client management panel for full no-SSH functionality.

### Option C: Generate on Another NAS

If you have another NAS with Docker installed, use it to generate certificates and transfer via downloads.

## Advanced Usage (No SSH)

### Accessing Configuration Directory

Without SSH, you can't directly edit files. However, you can:

1. **Re-run the wizard** to update configuration
2. **Use File Station** (if enabled) to browse `/var/packages/vpn-server-wizard/target/etc/openvpn/`
3. **Ask your administrator** to make SSH edits

### Monitoring Performance

Through Package Center:
- View CPU usage
- Check memory usage
- Monitor network traffic
- Review package logs

### Backing Up Configuration

1. Use File Station to navigate to `/var/packages/vpn-server-wizard/target/etc/openvpn/`
2. Download the entire folder as backup
3. Store safely for disaster recovery

## Network Configuration (No SSH)

### Router Port Forwarding

Without SSH, configure manually on your router:

1. **Log into router** at 192.168.1.1 (or your router IP)
2. Find **Port Forwarding** or **Virtual Server** section
3. Create new rule:
   - External Port: `1194`
   - Protocol: `UDP`
   - Internal IP: `192.168.X.X` (your NAS IP)
   - Internal Port: `1194`
4. **Save** and reboot router if needed

### Dynamic DNS Setup

1. In **DSM Control Panel**, find **Network** → **DDNS**
2. Select your DDNS provider (No-IP, DynDNS, etc.)
3. Enter credentials
4. Test connection
5. Use the DDNS hostname in VPN configuration

### Firewall Configuration

Check DSM firewall settings:

1. **DSM Control Panel** → **Security** → **Firewall**
2. Ensure **Port 1194/UDP** is allowed
3. Or disable firewall temporarily to test

## Security Without SSH

### Protecting Your Configuration

1. **Enable NAS user permissions** - Limit who can access the package
2. **Use strong admin password** - Protect DSM access
3. **Enable 2-factor auth** - on your NAS admin account
4. **HTTPS only** - Use secure connections to NAS

### Secure Certificate Handling

1. **Download certificates securely** - Use HTTPS connections only
2. **Don't share private keys** - Keep server.key confidential
3. **Backup encrypted** - Store backups with encryption
4. **Use strong passphrases** - If using encrypted keys

## Support & Alternatives

If you need more advanced features without SSH:

### Option A: Ask Administrator

Have someone with SSH access perform advanced tasks:
- Client certificate management
- Performance tuning
- Backup/restore procedures

### Option B: Use Web Admin Panel

Request implementation of additional web UI features:
- Client management dashboard
- Server statistics and monitoring
- Configuration versioning
- Log viewer

### Option C: Limited SSH Access

Request read-only or limited SSH access for specific tasks

## FAQ

**Q: Can I change configuration without reinstalling?**
A: Yes - run the wizard again to upload new files and configuration

**Q: How do I generate client certificates?**
A: Ask your NAS administrator or use another device with Docker

**Q: Is the web interface secure?**
A: It's protected by your NAS authentication and should only be accessed via HTTPS

**Q: Can I access this from outside my network?**
A: Only if your NAS is configured for external access via dynamic DNS

**Q: What if I need SSH later?**
A: You can enable SSH access in DSM Control Panel → Terminal & SNMP

## Next Steps

1. **Download the SPK** - `vpn-server-wizard-2.0.0-x86_64.spk`
2. **Install on your NAS** - Via Package Center Manual Install
3. **Run the wizard** - Configure your VPN server
4. **Start the service** - Through Package Center
5. **Configure firewall** - Port forward on your router
6. **Connect clients** - Get client certificates from administrator
7. **Test connection** - Verify VPN connectivity

---

**Package Version**: 2.0.0  
**Architecture**: x86_64 (DS725+, DS920+, DS721+2, DS225+)  
**Requires DSM**: 7.1 or later  
**Setup Method**: Web-based wizard (No SSH required)  
**Last Updated**: 2026-06-22
