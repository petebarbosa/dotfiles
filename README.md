# dotfiles

The good old dotfiles repository that every dev loves. This repository provides a complete setup for a brand new system with [Ubuntu][ubuntu] and [Omakub][omakub], plus a self-hosted server infrastructure using Docker, Traefik, and Cloudflare Tunnel.

## 🏗️ Architecture Overview

```
Internet → Cloudflare Tunnel (HTTPS Only) → Traefik (443) → Services
                                              ├── Vaultwarden
                                              ├── PostgreSQL + PgAdmin
                                              ├── Uptime Kuma
                                              └── Portainer
```

**Key Security Features:**
- ✅ No HTTP port (80) exposure
- ✅ No local database port exposure
- ✅ HTTPS-only communication
- ✅ DNS challenge for SSL certificates
- ✅ All traffic through Cloudflare Tunnel
- ✅ Secrets scanning with pre-commit hooks

## 🚀 Quick Start

### Automated Installation (Recommended)

The easiest way to set up everything is to use the Omarchy installer:

```bash
cd ~/.dotfiles  # or wherever you cloned this repository
chmod +x install_omarchy.sh
./install_omarchy.sh
```

The installer will:
- ✅ Install all required dependencies (Docker, Docker Compose plugin, etc.)
- ✅ Guide you through configuration with helpful prompts
- ✅ Set up systemd user services for auto-start
- ✅ Create automated daily backups
- ✅ Configure everything with proper permissions

After installation:
1. Configure Cloudflare Tunnel routes (see Configuration section)
2. Set up systemd user services (see Systemd Services section)
3. Start services: `cd docker && ./up.sh up -d`

### Manual Setup

If you prefer manual setup:

1. **Install prerequisites:**
   ```bash
   sudo pacman -S docker docker-compose docker-buildx apache
   sudo systemctl enable --now docker
   sudo usermod -aG docker $USER
   ```

2. **Configure environment:**
   ```bash
   cd docker
   cp env.example .env
   nano .env  # Edit with your values
   ```

3. **Set up systemd user services:**
   ```bash
   # Copy service files from examples
   cp docker-compose-apps.service.example docker-compose-apps.service
   cp docker-backup.service.example docker-backup.service
   cp docker-backup.timer.example docker-backup.timer
   
   # Edit service files if your dotfiles are not in ~/.dotfiles
   nano docker-compose-apps.service
   nano docker-backup.service
   
   # Install services (user services, no sudo needed)
   mkdir -p ~/.config/systemd/user
   cp *.service *.timer ~/.config/systemd/user/
   
   # Enable and start services
   systemctl --user enable docker-compose-apps.service
   systemctl --user enable docker-backup.timer
   systemctl --user start docker-compose-apps.service
   systemctl --user start docker-backup.timer
   ```

4. **Start services:**
   ```bash
   ./up.sh up -d
   ```

## 📋 Prerequisites

- Arch Linux (or compatible distribution)
- A domain name managed by Cloudflare
- Cloudflare account with:
  - Tunnel access (Cloudflare Zero Trust)
  - API key for DNS challenges
- Internet connection for downloading Docker images

## 🔧 Configuration

### 1. Cloudflare API Setup

1. **Get Cloudflare API Key (for SSL certificates):**
   - Go to https://dash.cloudflare.com/profile/api-tokens
   - Scroll down to **"API Keys"** section
   - Click **"View"** next to "Global API Key"
   - Enter your password to reveal the key
   - Copy the API key and your account email
   
   **Note:** This is used by Traefik to create DNS records for Let's Encrypt SSL certificates.

### 2. Cloudflare Tunnel Setup

1. **Create a Tunnel in Cloudflare Zero Trust:**
   - Go to https://one.dash.cloudflare.com/
   - Navigate to: **Zero Trust → Networks → Tunnels**
   - Click "Create a tunnel"
   - Choose "Cloudflared"
   - Name your tunnel (e.g., "home-server")
   - Follow the installation steps (or skip if using Docker)
   - Save the tunnel token (long string starting with 'ey...')

2. **Configure Public Hostnames:**
   In the tunnel configuration page:
   - Go to the **"Public Hostnames"** tab
   - Click **"Add a public hostname"** for each service
   - Add these routes (all pointing to Service: `https://traefik:443`):
   
   | Subdomain | Domain | Service |
   |-----------|--------|---------|
   | vault | yourdomain.com | https://traefik:443 |
   | traefik | yourdomain.com | https://traefik:443 |
   | status | yourdomain.com | https://traefik:443 |
   | docker | yourdomain.com | https://traefik:443 |
   | db | yourdomain.com | https://traefik:443 |

3. **DNS Records (Automatic):**
   Cloudflare automatically creates the DNS records when you add public hostnames.
   You don't need to manually create CNAME records.

### 3. Environment Variables

Copy `docker/env.example` to `docker/.env` and configure:

```bash
# Required Configuration
CLOUDFLARE_TUNNEL_TOKEN=your_tunnel_token_here
DOMAIN=yourdomain.com
VAULTWARDEN_DOMAIN=vault.yourdomain.com
TRAEFIK_DOMAIN=traefik.yourdomain.com

# Cloudflare API for DNS challenge (for SSL certificates)
CF_API_EMAIL=your-cloudflare-email@example.com
CF_API_KEY=your_cloudflare_api_key_here

# Generate auth users with: htpasswd -nb username password
TRAEFIK_AUTH_USERS=admin:$$2y$$10$$your_hash_here

# Generate admin token with: openssl rand -base64 48
VAULTWARDEN_ADMIN_TOKEN=your_admin_token_here

# Email configuration for Vaultwarden
VAULTWARDEN_SMTP_HOST=smtp.gmail.com
VAULTWARDEN_SMTP_FROM=your-email@gmail.com
VAULTWARDEN_SMTP_USERNAME=your-email@gmail.com
VAULTWARDEN_SMTP_PASSWORD=your-app-password

# Database configuration
POSTGRES_DB=selfhosted
POSTGRES_USER=selfhosted
POSTGRES_PASSWORD=your_secure_password_here

# Timezone
TZ=America/New_York
```

**IMPORTANT:** Never commit your `.env` file to git! It's already in `.gitignore`.

## 🛠️ Services

### Traefik (Reverse Proxy)
- **URL:** `https://traefik.yourdomain.com`
- **Port:** 443 only (no HTTP)
- **Purpose:** Routes HTTPS traffic to services, handles SSL certificates
- **Features:**
  - Automatic Let's Encrypt certificates via DNS challenge
  - Dashboard with authentication
  - No HTTP exposure for maximum security

### Vaultwarden (Password Manager)
- **URL:** `https://vault.yourdomain.com`
- **Purpose:** Self-hosted Bitwarden-compatible password manager
- **Features:**
  - Web vault access
  - WebSocket for live sync
  - Email invitations (signups disabled)
  - Admin panel at `/admin`

### PostgreSQL + PgAdmin
- **Database:** Internal network only (no external access)
- **PgAdmin:** `https://db.yourdomain.com`
- **Purpose:** Database for future applications
- **Features:**
  - Persistent data storage
  - Web-based administration
  - Health checks
  - No local port exposure for security

### Uptime Kuma (Monitoring)
- **URL:** `https://status.yourdomain.com`
- **Purpose:** Monitor service availability
- **Features:**
  - Service monitoring
  - Status page
  - Notifications

### Portainer (Docker Management)
- **URL:** `https://docker.yourdomain.com`
- **Purpose:** Web-based Docker management
- **Features:**
  - Container management
  - Image management
  - Volume and network management

### Cloudflared (Tunnel Client)
- **Purpose:** Secure HTTPS-only tunnel to Cloudflare
- **Features:**
  - No open ports required
  - Automatic failover
  - DDoS protection
  - HTTPS-only communication

## 📁 Directory Structure

```
docker/
├── cloudflared/
│   └── docker-compose.yml
├── traefik/
│   ├── docker-compose.yml
│   └── letsencrypt/          # SSL certificates
├── vaultwarden/
│   ├── docker-compose.yml
│   └── vw-data/              # Vaultwarden data
├── database/
│   ├── docker-compose.yml
│   ├── postgres-data/        # Database files
│   ├── pgadmin-data/         # PgAdmin settings
│   └── init-scripts/         # Database init scripts
├── monitoring/
│   ├── docker-compose.yml
│   ├── uptime-kuma-data/     # Monitoring data
│   └── portainer-data/       # Portainer data
├── backups/                  # Backup files
├── .env                      # Environment variables (not in git)
├── env.example               # Environment template
├── up.sh                     # Main management script
├── setup.sh                  # Initial setup script
├── backup.sh                 # Backup script
├── docker-compose-apps.service.example  # Systemd service template
├── docker-backup.service.example        # Backup service template
└── docker-backup.timer.example          # Backup timer template
```

## 🔄 Management Commands

### Start Services
```bash
cd docker
./up.sh up -d
```

### Stop Services
```bash
./up.sh down
```

### View Logs
```bash
./up.sh logs -f
./up.sh logs -f vaultwarden  # Specific service
```

### Update Services
```bash
./up.sh pull
./up.sh up -d
```

### Backup Data
```bash
./backup.sh         # Manual backup
./backup.sh force   # Force backup even if one exists for today
```

## 🔧 Systemd User Services

This setup uses **systemd user services** (not system services), which means:
- No `sudo` required to manage services
- Services run as your user
- Services start automatically when you log in
- Your home directory path is resolved automatically using `%h`

### Setting Up Services

1. **Copy example service files:**
   ```bash
   cd docker
   cp docker-compose-apps.service.example docker-compose-apps.service
   cp docker-backup.service.example docker-backup.service
   cp docker-backup.timer.example docker-backup.timer
   ```

2. **Edit if needed (only if your dotfiles are not in `~/.dotfiles`):**
   ```bash
   nano docker-compose-apps.service
   # Change %h/.dotfiles to your actual path if different
   ```

3. **Install services:**
   ```bash
   mkdir -p ~/.config/systemd/user
   cp docker-compose-apps.service ~/.config/systemd/user/
   cp docker-backup.service ~/.config/systemd/user/
   cp docker-backup.timer ~/.config/systemd/user/
   ```

4. **Enable and start:**
   ```bash
   # Enable services to start on login
   systemctl --user enable docker-compose-apps.service
   systemctl --user enable docker-backup.timer
   
   # Start services now
   systemctl --user start docker-compose-apps.service
   systemctl --user start docker-backup.timer
   ```

### Managing Services

```bash
# Check status
systemctl --user status docker-compose-apps.service
systemctl --user status docker-backup.timer

# Start/stop/restart
systemctl --user start docker-compose-apps.service
systemctl --user stop docker-compose-apps.service
systemctl --user restart docker-compose-apps.service

# View logs
journalctl --user -u docker-compose-apps.service -f
journalctl --user -u docker-backup.service -f

# Check next backup time
systemctl --user list-timers
```

### Important Notes

- Services are **user services**, not system services (no `sudo` needed)
- The service files use `%h` which automatically resolves to your home directory
- If your dotfiles are in a different location, edit the service files before installing
- User services require you to be logged in (or enable lingering: `loginctl enable-linger $USER`)
- The backup timer runs daily and keeps backups for 2 weeks

## 🔒 Security Features

### Network Security
- **No HTTP Exposure:** Only HTTPS (port 443) is exposed
- **No Local Database Ports:** PostgreSQL only accessible within Docker network
- **Isolated Networks:** All services run in isolated Docker network
- **Cloudflare Protection:** DDoS protection and WAF
- **Zero Port Forwarding:** No router configuration needed

### Authentication
- Traefik dashboard protected with basic auth
- Vaultwarden admin panel protected
- PgAdmin requires login
- Portainer requires login

### SSL/TLS
- **DNS Challenge:** SSL certificates via Cloudflare DNS API (more secure than HTTP challenge)
- **HTTPS Only:** No HTTP traffic allowed
- **Automatic Renewal:** Let's Encrypt certificates auto-renew
- **Secure Headers:** Security headers configured

### Data Protection
- Regular automated backups (daily)
- Persistent volumes for data
- Database health checks
- Internal-only database access
- 2-week backup retention

### Secrets Management
- All sensitive data in `.env` files (git-ignored)
- Pre-commit hooks to prevent secret commits
- Service files templated to avoid personal info in git
- No hardcoded credentials in repository

## 🚨 Troubleshooting

### Common Issues

1. **Tunnel not connecting:**
   - Check tunnel token in `.env`
   - Verify tunnel is active in Cloudflare dashboard
   - Check cloudflared container logs: `./up.sh logs cloudflared`

2. **SSL certificate issues:**
   - Verify CF_API_KEY and CF_API_EMAIL in `.env`
   - Check Cloudflare API token permissions
   - Check Traefik logs: `./up.sh logs traefik`
   - Ensure DNS records point to tunnel

3. **Service not accessible:**
   - Check if service is running: `./up.sh ps`
   - Verify DNS records in Cloudflare
   - Check Traefik dashboard for routing rules
   - Ensure tunnel routes are configured for HTTPS

4. **Database connection issues:**
   - Check PostgreSQL health: `./up.sh logs postgres`
   - Verify environment variables
   - Ensure database is fully started before dependent services
   - Use PgAdmin web interface instead of direct connection

5. **Systemd service issues:**
   - Check service status: `systemctl --user status docker-compose-apps.service`
   - View logs: `journalctl --user -u docker-compose-apps.service`
   - Ensure Docker group membership: `groups` (should include `docker`)
   - Verify service file paths match your dotfiles location

### Log Locations
```bash
# Docker service logs
cd docker
./up.sh logs              # All services
./up.sh logs [service]    # Specific service
./up.sh logs -f [service] # Follow logs

# Systemd logs
journalctl --user -u docker-compose-apps.service
journalctl --user -u docker-backup.service
journalctl --user -u docker-backup.timer
```

### Health Checks
```bash
# Check all running containers
docker ps

# Check specific service health
docker inspect [container-name] | grep Health -A 10

# Check systemd services
systemctl --user list-units --type=service
systemctl --user list-timers
```

## 🔄 Adding New Services

1. **Create new directory:**
   ```bash
   cd docker
   mkdir new-service
   cd new-service
   ```

2. **Create docker-compose.yml:**
   ```yaml
   services:
     new-service:
       image: your-image:latest
       container_name: new-service
       restart: unless-stopped
       environment:
         - TZ=${TZ}
       labels:
         - traefik.enable=true
         - traefik.http.routers.newservice.rule=Host(`service.${DOMAIN}`)
         - traefik.http.routers.newservice.entrypoints=websecure
         - traefik.http.routers.newservice.tls.certresolver=letsencrypt
         - traefik.http.services.newservice.loadbalancer.server.port=80
       networks:
         - traefik_network

   networks:
     traefik_network:
       external: true
   ```

3. **Add HTTPS route to Cloudflare tunnel:**
   - Go to tunnel configuration
   - Add public hostname: `service.yourdomain.com` → `https://traefik:443`

4. **Restart services:**
   ```bash
   cd ..
   ./up.sh up -d
   ```

## 📊 Monitoring and Maintenance

### Regular Tasks
- Check service status weekly
- Review logs for errors
- Update services monthly
- Test backups quarterly
- Monitor SSL certificate renewals

### Backup Strategy
- Automated daily backups via systemd timer
- Retention: 2 weeks (14 days)
- Includes: Vaultwarden data, database, certificates, configs
- Manual backup: `cd docker && ./backup.sh`
- Force backup: `./backup.sh force`

### Updates
```bash
cd docker

# Update all images
./up.sh pull

# Restart with new images
./up.sh up -d

# Clean up old images
docker image prune -f
```

## 🔐 Security Best Practices

1. **Use strong passwords** for all services
2. **Enable 2FA** where possible (Vaultwarden supports it)
3. **Regularly update** Docker images
4. **Monitor logs** for suspicious activity
5. **Use Cloudflare WAF rules** for additional protection
6. **Backup regularly** and test restore procedures
7. **Limit access** to necessary users only
8. **Never commit `.env` files** to git
9. **Use the pre-commit hooks** to scan for secrets
10. **Keep systemd service files** (`.service`, `.timer`) out of git (use `.example` templates)

## 🛡️ Secrets Scanning

To prevent accidentally committing secrets:

1. **Install pre-commit:**
   ```bash
   pip install pre-commit
   ```

2. **Install the hooks:**
   ```bash
   cd ~/.dotfiles
   pre-commit install
   ```

3. **Test the hooks:**
   ```bash
   pre-commit run --all-files
   ```

The hooks will automatically:
- Scan for secrets, tokens, and API keys
- Check for AWS credentials
- Detect private keys
- Warn about suspicious patterns

## 🆘 Support

For issues or questions:
1. Check the troubleshooting section
2. Review service logs
3. Verify configuration
4. Check Cloudflare tunnel status
5. Verify DNS records and API permissions

## 📝 Important Notes

- **HTTPS Only:** This setup only uses HTTPS (port 443). No HTTP traffic is allowed.
- **DNS Challenge:** SSL certificates are obtained via Cloudflare DNS API, not HTTP challenge.
- **No Local Ports:** Database and other services are only accessible through the web interfaces.
- **Cloudflare Required:** This setup requires Cloudflare for DNS and tunnel services.
- **User Services:** Systemd services run as your user, not as system services.
- **Template Files:** Service files ending in `.example` are templates. Copy and customize them.

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

<!-- Links -->
[ubuntu]: https://ubuntu.com/
[omakub]: https://omakub.org/
