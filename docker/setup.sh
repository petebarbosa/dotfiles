#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[SETUP]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[SETUP] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[SETUP] ERROR:${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[SETUP] INFO:${NC} $1"
}

log "Starting self-hosted server setup..."

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Please don't run this script as root!"
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first."
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    error "Docker Compose is not available. Please install Docker Compose."
fi

# Create .env file from example if it doesn't exist
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    log "Creating .env file from example..."
    cp "$SCRIPT_DIR/env.example" "$SCRIPT_DIR/.env"
    warn "Please edit $SCRIPT_DIR/.env with your configuration before proceeding!"
    info "You need to configure:"
    echo "  - CLOUDFLARE_TUNNEL_TOKEN (from Cloudflare dashboard)"
    echo "  - DOMAIN and subdomains"
    echo "  - CF_API_EMAIL and CF_API_KEY (for SSL certificates)"
    echo "  - TRAEFIK_AUTH_USERS (generate with: htpasswd -nb username password)"
    echo "  - VAULTWARDEN_ADMIN_TOKEN (generate with: openssl rand -base64 48)"
    echo "  - Email configuration for Vaultwarden"
    echo "  - Database password"
    exit 0
fi

# Make scripts executable
log "Making scripts executable..."
chmod +x "$SCRIPT_DIR/up.sh"
chmod +x "$SCRIPT_DIR/backup.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/restore.sh" 2>/dev/null || true

# Create necessary directories
log "Creating necessary directories..."
mkdir -p "$SCRIPT_DIR/traefik/letsencrypt"
mkdir -p "$SCRIPT_DIR/vaultwarden/vw-data"
mkdir -p "$SCRIPT_DIR/database/postgres-data"
mkdir -p "$SCRIPT_DIR/database/pgadmin-data"
mkdir -p "$SCRIPT_DIR/database/init-scripts"
mkdir -p "$SCRIPT_DIR/monitoring/uptime-kuma-data"
mkdir -p "$SCRIPT_DIR/monitoring/portainer-data"

# Set proper ownership
log "Setting proper ownership..."
sudo chown -R $(id -u):$(id -g) "$SCRIPT_DIR"

# Install systemd service
if [ -f "$SCRIPT_DIR/docker-compose-apps.service" ]; then
    log "Installing systemd service..."
    sudo cp "$SCRIPT_DIR/docker-compose-apps.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable docker-compose-apps.service
    info "Systemd service installed and enabled"
fi

log "Setup completed successfully!"
info "Next steps:"
echo "  1. Configure your .env file with proper values"
echo "  2. Set up Cloudflare Tunnel in your Cloudflare dashboard"
echo "  3. Get Cloudflare API key for DNS challenge"
echo "  4. Run './up.sh up -d' to start all services"
echo "  5. Check logs with './up.sh logs -f'"
echo "  6. Access your services at the configured domains"
