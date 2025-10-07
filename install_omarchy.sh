#!/bin/bash

set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

## Helper Functions

log() {
    echo -e "${GREEN}[OMARCHY]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[OMARCHY] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[OMARCHY] ERROR:${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[OMARCHY] INFO:${NC} $1"
}

success() {
    echo -e "${PURPLE}[OMARCHY] SUCCESS:${NC} $1"
}

create_symlink() {
  local source_path="$1"
  local target_path="$2"
  mkdir -p "$(dirname "$target_path")"
  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    log "Backing up existing '$target_path' to '${target_path}.backup'"
    mv "$target_path" "${target_path}.backup"
  fi
  log "Creating symlink: $target_path -> $source_path"
  ln -s "$source_path" "$target_path"
}

update_file_placeholder() {
  local file_path="$1"
  local current_user
  current_user=$(whoami)

  if [[ -f "$file_path" ]]; then
    log "Updating placeholders in $file_path"
    sed -i "s#YOUR_USER_NAME#$current_user#g" "$file_path"
    sed -i "s#YOUR_DOTFILES_PATH#$SCRIPT_DIR#g" "$file_path"
  fi
}

check_arch_linux() {
    if [[ ! -f /etc/arch-release ]]; then
        error "This script is designed for Arch Linux only!"
    fi
    log "Arch Linux detected ✓"
}

check_hyprland() {
    if ! command -v hyprctl &> /dev/null; then
        warn "Hyprland not detected. This script is optimized for Hyprland."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log "Hyprland detected ✓"
    fi
}

## Setup Functions

install_dependencies() {
    log "Installing Arch Linux dependencies..."
    
    # Update system first
    sudo pacman -Syu --noconfirm
    
    # Essential packages
    local packages=(
        "docker"
        "docker-compose"  # Legacy standalone tool
        "docker-buildx"   # Docker buildx plugin
        "git"
        "curl"
        "wget"
        "neovim"
        "htop"
        "tree"
        "unzip"
        "zip"
        "xclip"
        "wl-clipboard"  # Wayland clipboard for Hyprland
        "jq"
        "yq"
        "base-devel"
        "apache"  # Provides htpasswd utility
    )
    
    for package in "${packages[@]}"; do
        log "Installing $package..."
        sudo pacman -S --needed --noconfirm "$package" || warn "Failed to install $package"
    done
    
    # Install yay AUR helper if not present
    if ! command -v yay &> /dev/null; then
        log "Installing yay AUR helper..."
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd "$SCRIPT_DIR"
    fi
    
    # Set up Docker Compose plugin (v2)
    log "Setting up Docker Compose plugin..."
    local compose_plugin_dir="/usr/local/lib/docker/cli-plugins"
    sudo mkdir -p "$compose_plugin_dir"
    
    # Check if docker compose works, if not create symlink
    if ! docker compose version &> /dev/null; then
        log "Creating Docker Compose plugin symlink..."
        sudo ln -sf /usr/bin/docker-compose "$compose_plugin_dir/docker-compose"
    fi
    
    # Verify installation
    if docker compose version &> /dev/null; then
        success "Docker Compose plugin is working!"
    else
        warn "Docker Compose plugin setup may need manual intervention"
    fi
}

setup_docker() {
    log "Setting up Docker for Arch Linux..."
    
    # Enable and start Docker service
    sudo systemctl enable docker.service
    sudo systemctl start docker.service
    
    # Add user to docker group
    local current_user=$(whoami)
    sudo usermod -aG docker "$current_user"
    
    log "Setting up systemd user services..."
    
    # Create user systemd directory
    mkdir -p "$HOME/.config/systemd/user"
    
    # Copy service files from examples
    local docker_dir="$SCRIPT_DIR/docker"
    
    if [[ ! -f "$docker_dir/docker-compose-apps.service.example" ]]; then
        error "Service template not found: $docker_dir/docker-compose-apps.service.example"
    fi
    
    log "Creating service files from templates..."
    cp "$docker_dir/docker-compose-apps.service.example" "$docker_dir/docker-compose-apps.service"
    cp "$docker_dir/docker-backup.service.example" "$docker_dir/docker-backup.service"
    cp "$docker_dir/docker-backup.timer.example" "$docker_dir/docker-backup.timer"
    
    # If dotfiles are not in the default location, update the service files
    if [[ "$SCRIPT_DIR" != "$HOME/.dotfiles" ]]; then
        log "Updating service files with custom dotfiles path: $SCRIPT_DIR"
        sed -i "s|%h/.dotfiles|$SCRIPT_DIR|g" "$docker_dir/docker-compose-apps.service"
        sed -i "s|%h/.dotfiles|$SCRIPT_DIR|g" "$docker_dir/docker-backup.service"
    fi
    
    # Install user services
    log "Installing systemd user services..."
    cp "$docker_dir/docker-compose-apps.service" "$HOME/.config/systemd/user/"
    cp "$docker_dir/docker-backup.service" "$HOME/.config/systemd/user/"
    cp "$docker_dir/docker-backup.timer" "$HOME/.config/systemd/user/"
    
    # Reload and enable user services
    systemctl --user daemon-reload
    systemctl --user enable docker-compose-apps.service
    systemctl --user enable docker-backup.timer
    
    # Start the backup timer immediately
    systemctl --user start docker-backup.timer
    
    success "Docker user services configured and enabled!"
    success "Backup timer started and will run daily"
    warn "You'll need to log out and back in for Docker group membership to take effect."
    info "Services will start automatically when you log in."
}

collect_configuration() {
    log "Collecting configuration information..."
    
    echo
    info "Please provide the following configuration details:"
    echo "Press Enter to use default values where available."
    echo
    
    # Domain configuration
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    info "Domain Configuration"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Enter the domain name you own (e.g., example.com)"
    echo "This should be a domain registered and managed through Cloudflare"
    echo
    
    read -p "Enter your domain name: " DOMAIN
    while [[ -z "$DOMAIN" ]]; do
        warn "Domain name is required!"
        read -p "Enter your domain name: " DOMAIN
    done
    
    echo
    echo "Your services will be available at subdomains of $DOMAIN"
    echo
    
    # Subdomain configuration with defaults
    read -p "Vaultwarden subdomain [vault.$DOMAIN]: " VAULTWARDEN_DOMAIN
    VAULTWARDEN_DOMAIN=${VAULTWARDEN_DOMAIN:-"vault.$DOMAIN"}
    
    read -p "Traefik dashboard subdomain [traefik.$DOMAIN]: " TRAEFIK_DOMAIN
    TRAEFIK_DOMAIN=${TRAEFIK_DOMAIN:-"traefik.$DOMAIN"}
    
    # Cloudflare configuration
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    info "Cloudflare Configuration"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "This setup requires Cloudflare for DNS and tunneling."
    echo
    echo "How to get your Cloudflare Tunnel Token:"
    echo "  1. Go to https://one.dash.cloudflare.com/"
    echo "  2. Navigate to: Zero Trust → Networks → Tunnels"
    echo "  3. Click 'Create a tunnel' (or select existing tunnel)"
    echo "  4. After creating/selecting, go to 'Configure' tab"
    echo "  5. Copy the tunnel token (long string starting with 'ey...')"
    echo
    echo "How to get your Cloudflare API credentials (for SSL certificates):"
    echo "  1. Go to https://dash.cloudflare.com/profile/api-tokens"
    echo "  2. Scroll down to 'API Keys' section"
    echo "  3. For 'Global API Key', click 'View' and copy it"
    echo "  4. You'll need:"
    echo "     - Your Cloudflare account email"
    echo "     - The Global API Key (or create a custom token with Zone:DNS:Edit + Zone:Zone:Read)"
    echo
    echo "Note: Tunnel Token is different from API Key!"
    echo "  - Tunnel Token: Used by cloudflared to connect to Cloudflare"
    echo "  - API Key: Used by Traefik to create DNS records for SSL certificates"
    echo
    read -p "Press Enter when ready to continue..."
    echo
    
    read -p "Cloudflare Tunnel Token: " CLOUDFLARE_TUNNEL_TOKEN
    while [[ -z "$CLOUDFLARE_TUNNEL_TOKEN" ]]; do
        warn "Cloudflare Tunnel Token is required!"
        read -p "Cloudflare Tunnel Token: " CLOUDFLARE_TUNNEL_TOKEN
    done
    
    read -p "Cloudflare API Email: " CF_API_EMAIL
    while [[ -z "$CF_API_EMAIL" ]]; do
        warn "Cloudflare API Email is required!"
        read -p "Cloudflare API Email: " CF_API_EMAIL
    done
    
    read -p "Cloudflare API Key: " CF_API_KEY
    while [[ -z "$CF_API_KEY" ]]; do
        warn "Cloudflare API Key is required!"
        read -p "Cloudflare API Key: " CF_API_KEY
    done
    
    
    # Authentication configuration
    echo
    info "Authentication Configuration:"
    echo "Creating Traefik dashboard authentication..."
    echo
    
    read -p "Admin username [admin]: " ADMIN_USERNAME
    ADMIN_USERNAME=${ADMIN_USERNAME:-"admin"}
    
    read -s -p "Admin password: " ADMIN_PASSWORD
    echo
    while [[ -z "$ADMIN_PASSWORD" ]]; do
        warn "Admin password is required!"
        read -s -p "Admin password: " ADMIN_PASSWORD
        echo
    done
    
    # Generate Traefik auth hash with multiple fallback methods
    log "Generating authentication hash..."
    
    TRAEFIK_AUTH_USERS=""
    
    # Method 1: Try Docker with httpd (most reliable, works everywhere)
    if command -v docker &> /dev/null && docker ps &> /dev/null 2>&1; then
        log "Using Docker to generate auth hash..."
        TRAEFIK_AUTH_USERS=$(docker run --rm httpd:2.4-alpine htpasswd -nbB "$ADMIN_USERNAME" "$ADMIN_PASSWORD" 2>/dev/null || echo "")
        if [[ -n "$TRAEFIK_AUTH_USERS" ]]; then
            success "Generated auth hash using Docker (bcrypt)"
        fi
    fi
    
    # Method 2: Try system htpasswd with bcrypt
    if [[ -z "$TRAEFIK_AUTH_USERS" ]] && command -v htpasswd &> /dev/null; then
        log "Trying system htpasswd..."
        # Test if htpasswd supports -n and -B flags
        if htpasswd -nbB test test &> /dev/null; then
            TRAEFIK_AUTH_USERS=$(htpasswd -nbB "$ADMIN_USERNAME" "$ADMIN_PASSWORD" 2>/dev/null || echo "")
            if [[ -n "$TRAEFIK_AUTH_USERS" ]]; then
                success "Generated auth hash using system htpasswd (bcrypt)"
            fi
        else
            # Try without -B (older htpasswd versions)
            TRAEFIK_AUTH_USERS=$(htpasswd -nb "$ADMIN_USERNAME" "$ADMIN_PASSWORD" 2>/dev/null || echo "")
            if [[ -n "$TRAEFIK_AUTH_USERS" ]]; then
                success "Generated auth hash using system htpasswd (MD5)"
            fi
        fi
    fi
    
    # Method 3: Use openssl for APR1 hash (compatible with Traefik)
    if [[ -z "$TRAEFIK_AUTH_USERS" ]] && command -v openssl &> /dev/null; then
        log "Trying openssl APR1 hash..."
        # Generate APR1 hash using openssl
        HASH=$(openssl passwd -apr1 "$ADMIN_PASSWORD" 2>/dev/null || echo "")
        if [[ -n "$HASH" ]]; then
            TRAEFIK_AUTH_USERS="$ADMIN_USERNAME:$HASH"
            success "Generated auth hash using openssl (APR1)"
        fi
    fi
    
    # Method 4: Last resort - manual entry
    if [[ -z "$TRAEFIK_AUTH_USERS" ]]; then
        error "Cannot generate auth hash automatically."
        echo
        warn "Please generate the hash manually using one of these methods:"
        echo "  1. Docker:  docker run --rm httpd:2.4-alpine htpasswd -nbB $ADMIN_USERNAME yourpassword"
        echo "  2. Online:  https://hostingcanada.org/htpasswd-generator/"
        echo "  3. Install: sudo pacman -S apache"
        echo
        read -p "Paste the generated hash line (format: username:\$2y\$...): " TRAEFIK_AUTH_USERS
        if [[ -z "$TRAEFIK_AUTH_USERS" ]]; then
            error "Authentication hash is required to continue!"
        fi
    fi
    
    # Generate Vaultwarden admin token
    if command -v openssl &> /dev/null; then
        VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 48)
        info "Generated Vaultwarden admin token"
    else
        warn "openssl not found. Using default token."
        VAULTWARDEN_ADMIN_TOKEN="your_admin_token_here"
    fi
    
    # Email configuration for Vaultwarden
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    info "Email Configuration for Vaultwarden (optional but recommended)"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Vaultwarden needs SMTP to send invitation emails and password reset links."
    echo
    echo "Common SMTP providers:"
    echo "  Gmail:        smtp.gmail.com (requires App Password)"
    echo "  Outlook:      smtp-mail.outlook.com"
    echo "  Yahoo:        smtp.mail.yahoo.com"
    echo "  Custom:       Your mail server address"
    echo
    echo "For Gmail App Password:"
    echo "  1. Enable 2FA on your Google account"
    echo "  2. Go to https://myaccount.google.com/apppasswords"
    echo "  3. Create a new app password"
    echo "  4. Use that 16-character password (not your regular password)"
    echo
    
    read -p "SMTP Host (leave empty to skip email setup): " VAULTWARDEN_SMTP_HOST
    if [[ -n "$VAULTWARDEN_SMTP_HOST" ]]; then
        read -p "SMTP From Email (e.g., vaultwarden@$DOMAIN): " VAULTWARDEN_SMTP_FROM
        read -p "SMTP Username (usually your email): " VAULTWARDEN_SMTP_USERNAME
        read -s -p "SMTP Password/App Password: " VAULTWARDEN_SMTP_PASSWORD
        echo
    else
        info "Skipping email configuration. You can add it later in docker/.env"
        VAULTWARDEN_SMTP_HOST=""
        VAULTWARDEN_SMTP_FROM=""
        VAULTWARDEN_SMTP_USERNAME=""
        VAULTWARDEN_SMTP_PASSWORD=""
    fi
    
    # Database configuration
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    info "Database Configuration"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "PostgreSQL database will be used for data storage."
    echo "Choose a strong password for database access."
    echo
    
    read -s -p "PostgreSQL password: " POSTGRES_PASSWORD
    echo
    while [[ -z "$POSTGRES_PASSWORD" ]]; do
        warn "Database password is required!"
        read -s -p "PostgreSQL password: " POSTGRES_PASSWORD
        echo
    done
    
    # Timezone
    echo
    DETECTED_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || echo "UTC")
    read -p "Timezone [$DETECTED_TZ]: " TZ
    TZ=${TZ:-"$DETECTED_TZ"}
    
    success "Configuration collection completed!"
    
    # Display configuration summary
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    info "Configuration Summary"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Domain:              $DOMAIN"
    echo "Vaultwarden:         https://$VAULTWARDEN_DOMAIN"
    echo "Traefik Dashboard:   https://$TRAEFIK_DOMAIN"
    echo "Uptime Kuma:         https://status.$DOMAIN"
    echo "Portainer:           https://docker.$DOMAIN"
    echo "PgAdmin:             https://db.$DOMAIN"
    echo "Timezone:            $TZ"
    if [[ -n "$VAULTWARDEN_SMTP_HOST" ]]; then
        echo "SMTP:                Configured ($VAULTWARDEN_SMTP_HOST)"
    else
        echo "SMTP:                Not configured"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    read -p "Proceed with this configuration? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        warn "Configuration cancelled. Rerun the script to start over."
        exit 0
    fi
}

write_env_file() {
    local docker_dir="$1"
    local env_file="$docker_dir/.env"
    
    log "Writing configuration to $env_file..."
    
    cat > "$env_file" << EOF
# Cloudflare Tunnel Configuration
CLOUDFLARE_TUNNEL_TOKEN=$CLOUDFLARE_TUNNEL_TOKEN

# Domain Configuration
DOMAIN=$DOMAIN
VAULTWARDEN_DOMAIN=$VAULTWARDEN_DOMAIN
TRAEFIK_DOMAIN=$TRAEFIK_DOMAIN

# Cloudflare API for DNS challenge (for SSL certificates)
CF_API_EMAIL=$CF_API_EMAIL
CF_API_KEY=$CF_API_KEY

# Traefik Authentication
TRAEFIK_AUTH_USERS=$TRAEFIK_AUTH_USERS

# Vaultwarden Configuration
VAULTWARDEN_ADMIN_TOKEN=$VAULTWARDEN_ADMIN_TOKEN
VAULTWARDEN_SMTP_HOST=$VAULTWARDEN_SMTP_HOST
VAULTWARDEN_SMTP_FROM=$VAULTWARDEN_SMTP_FROM
VAULTWARDEN_SMTP_USERNAME=$VAULTWARDEN_SMTP_USERNAME
VAULTWARDEN_SMTP_PASSWORD=$VAULTWARDEN_SMTP_PASSWORD

# Database Configuration
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Timezone
TZ=$TZ
EOF
    
    success "Configuration file created successfully!"
}

setup_docker_environment() {
    log "Setting up Docker environment..."
    
    local docker_dir="$SCRIPT_DIR/docker"
    
    if [[ ! -d "$docker_dir" ]]; then
        error "Docker directory not found: $docker_dir"
    fi
    
    # Interactive configuration collection
    if [[ ! -f "$docker_dir/.env" ]]; then
        collect_configuration
        write_env_file "$docker_dir"
    else
        warn "Configuration file already exists at $docker_dir/.env"
        read -p "Do you want to reconfigure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            collect_configuration
            write_env_file "$docker_dir"
        fi
    fi
    
    # Make scripts executable
    chmod +x "$docker_dir/up.sh" 2>/dev/null || warn "up.sh not found"
    chmod +x "$docker_dir/setup.sh" 2>/dev/null || warn "setup.sh not found"
    chmod +x "$docker_dir/backup.sh" 2>/dev/null || warn "backup.sh not found"
    
    # Create necessary directories
    local dirs=(
        "$docker_dir/traefik/letsencrypt"
        "$docker_dir/vaultwarden/vw-data"
        "$docker_dir/database/postgres-data"
        "$docker_dir/database/pgadmin-data"
        "$docker_dir/database/init-scripts"
        "$docker_dir/monitoring/uptime-kuma-data"
        "$docker_dir/monitoring/portainer-data"
        "$docker_dir/backups"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log "Created directory: $dir"
    done
    
    # Set proper ownership
    local current_user=$(whoami)
    sudo chown -R "$current_user:$current_user" "$docker_dir"
    
    success "Docker environment configured!"
}

setup_bash() {
    log "Setting up bash configuration..."
    
    if [[ -f "$SCRIPT_DIR/.bashrc" ]]; then
        create_symlink "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
    else
        warn ".bashrc not found in $SCRIPT_DIR"
    fi
    
    if [[ -f "$SCRIPT_DIR/.bashrc.env.example" ]]; then
        create_symlink "$SCRIPT_DIR/.bashrc.env.example" "$HOME/.bashrc.env.example"
        if [[ ! -f "$HOME/.bashrc.env" ]]; then
            log "Creating .bashrc.env from example"
            cp "$HOME/.bashrc.env.example" "$HOME/.bashrc.env"
        fi
    else
        warn ".bashrc.env.example not found in $SCRIPT_DIR"
    fi
    
    success "Bash configuration completed!"
}

setup_nvim() {
    log "Setting up Neovim configuration..."
    
    local nvim_dir="$SCRIPT_DIR/nvim"
    
    if [[ ! -d "$nvim_dir" ]]; then
        warn "Neovim directory not found: $nvim_dir"
        return
    fi
    
    # Create nvim config directory if it doesn't exist
    mkdir -p "$HOME/.config/nvim"
    
    find "$nvim_dir" -type f -printf "%P\n" | while read -r file; do
        target_file="$HOME/.config/nvim/$file"
        create_symlink "$nvim_dir/$file" "$target_file"
    done
    
    success "Neovim configuration completed!"
}

show_post_install_info() {
    echo
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}         ✨ OMARCHY Setup Complete! ✨${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    warn "IMPORTANT: Before starting services, complete these steps:"
    echo
    echo -e "${YELLOW}1. Activate Docker group membership${NC}"
    echo "   You need to be in the docker group to run docker commands."
    echo "   Choose one of these options:"
    echo
    echo "   Option A (Quick - works in current terminal only):"
    echo "     newgrp docker"
    echo
    echo "   Option B (Permanent - requires logout/login):"
    echo "     exit"
    echo "     # Then log back in to your session"
    echo
    
    echo -e "${YELLOW}2. Configure Cloudflare Tunnel Public Hostnames${NC}"
    echo "   Go to: https://one.dash.cloudflare.com/"
    echo "   Navigate to: Zero Trust → Networks → Tunnels"
    echo "   Select your tunnel → Configure → Public Hostnames → Add a public hostname"
    echo "   Add these routes (all pointing to Service: https://traefik:443):"
    echo
    if [[ -n "$VAULTWARDEN_DOMAIN" ]]; then
        echo "   • Subdomain: $(echo $VAULTWARDEN_DOMAIN | cut -d'.' -f1)  Domain: ${VAULTWARDEN_DOMAIN#*.}  Service: https://traefik:443"
    fi
    if [[ -n "$TRAEFIK_DOMAIN" ]]; then
        echo "   • Subdomain: $(echo $TRAEFIK_DOMAIN | cut -d'.' -f1)  Domain: ${TRAEFIK_DOMAIN#*.}  Service: https://traefik:443"
    fi
    echo "   • Subdomain: status      Domain: $DOMAIN  Service: https://traefik:443"
    echo "   • Subdomain: docker      Domain: $DOMAIN  Service: https://traefik:443"
    echo "   • Subdomain: db          Domain: $DOMAIN  Service: https://traefik:443"
    echo
    
    echo -e "${GREEN}3. Start your services${NC}"
    echo "   cd $SCRIPT_DIR/docker"
    echo "   ./up.sh up -d"
    echo
    
    echo -e "${GREEN}4. Monitor service startup${NC}"
    echo "   cd $SCRIPT_DIR/docker"
    echo "   ./up.sh logs -f"
    echo "   (Press Ctrl+C to exit logs)"
    echo
    
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    info "Your services will be available at:"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [[ -n "$VAULTWARDEN_DOMAIN" ]]; then
        echo "  🔐 Vaultwarden:       https://$VAULTWARDEN_DOMAIN"
    fi
    if [[ -n "$TRAEFIK_DOMAIN" ]]; then
        echo "  🌐 Traefik Dashboard: https://$TRAEFIK_DOMAIN"
    fi
    echo "  📊 Uptime Kuma:       https://status.$DOMAIN"
    echo "  🐳 Portainer:         https://docker.$DOMAIN"
    echo "  🗄️  PgAdmin:           https://db.$DOMAIN"
    echo
    
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    info "Useful Commands:"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Service Management (user services, no sudo needed):"
    echo "  systemctl --user status docker-compose-apps.service"
    echo "  systemctl --user start docker-compose-apps.service"
    echo "  systemctl --user stop docker-compose-apps.service"
    echo "  systemctl --user restart docker-compose-apps.service"
    echo
    echo "Docker Commands (from docker/ directory):"
    echo "  ./up.sh up -d          # Start all services"
    echo "  ./up.sh down           # Stop all services"
    echo "  ./up.sh ps             # List running containers"
    echo "  ./up.sh logs -f        # Follow logs"
    echo
    echo "Backup Commands (from docker/ directory):"
    echo "  systemctl --user status docker-backup.timer"
    echo "  systemctl --user list-timers              # Check next backup time"
    echo "  systemctl --user start docker-backup.service  # Manual backup"
    echo "  journalctl --user -u docker-backup.service -f # View backup logs"
    echo "  ./backup.sh force                             # Force backup"
    echo
    echo "Configuration:"
    echo "  Configuration file: $SCRIPT_DIR/docker/.env"
    echo "  Edit anytime and restart services to apply changes"
    echo
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    success "Enjoy your self-hosted server setup! 🚀"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

## Main Execution Flow

main() {
    local options=("setup_bash" "setup_docker" "setup_docker_environment" "setup_nvim")
    local descriptions=("Bash Configuration" "Docker Service" "Docker Environment" "Neovim")
    local selected=("false" "false" "false" "false")

    # System checks
    check_arch_linux
    check_hyprland

    while true; do
        clear
        echo -e "${PURPLE}=====================================${NC}"
        echo -e "${PURPLE}  OMARCHY - Arch + Hyprland Setup${NC}"
        echo -e "${PURPLE}=====================================${NC}"
        echo "Select which steps to run. Dependencies will always be installed."
        echo ""
        for i in "${!options[@]}"; do
            if [[ "${selected[$i]}" == "true" ]]; then
                echo -e "  $((i + 1))) ${GREEN}[x]${NC} ${descriptions[$i]}"
            else
                echo -e "  $((i + 1))) ${RED}[ ]${NC} ${descriptions[$i]}"
            fi
        done
        echo ""
        echo "Enter a number to toggle, (a)ll, (n)one, or (d)one to continue."
        read -rp "Choice: " choice

        case "$choice" in
        [1-4])
            local index=$((choice - 1))
            if [[ "${selected[$index]}" == "true" ]]; then
                selected[$index]="false"
            else
                selected[$index]="true"
            fi
            ;;
        a | A) for i in "${!options[@]}"; do selected[$i]="true"; done ;;
        n | N) for i in "${!options[@]}"; do selected[$i]="false"; done ;;
        d | D | "") break ;;
        *) echo "Invalid input. Please try again." && sleep 1 ;;
        esac
    done

    log "Starting OMARCHY setup..."
    
    # Ensure we have sudo access
    sudo -v

    install_dependencies

    for i in "${!options[@]}"; do
        if [[ "${selected[$i]}" == "true" ]]; then
            ${options[$i]}
        fi
    done

    show_post_install_info
}

main
