#!/bin/bash

set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

## Helper Functions

create_symlink() {
  local source_path="$1"
  local target_path="$2"
  mkdir -p "$(dirname "$target_path")"
  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    echo "Backing up existing '$target_path' to '${target_path}.backup'"
    mv "$target_path" "${target_path}.backup"
  fi
  echo "Creating symlink: $target_path -> $source_path"
  ln -s "$source_path" "$target_path"
}

update_file_placeholder() {
  local file_path="$1"
  local placeholder="YOUR_USER_NAME"
  local current_user
  current_user=$(whoami)

  if [[ -f "$file_path" ]]; then
    sed -i "s#$placeholder#$current_user#g" "$file_path"
  fi
}

## Setup Functions

setup_bash() {
  echo "Setting up bash configuration..."
  
  if [[ -f "$SCRIPT_DIR/.bashrc" ]]; then
    create_symlink "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
  else
    echo "⚠️  .bashrc not found in $SCRIPT_DIR"
  fi
  
  if [[ -f "$SCRIPT_DIR/.bashrc.env.example" ]]; then
    create_symlink "$SCRIPT_DIR/.bashrc.env.example" "$HOME/.bashrc.env.example"
    if [[ ! -f "$HOME/.bashrc.env" ]]; then
      echo "Creating .bashrc.env from example"
      cp "$HOME/.bashrc.env.example" "$HOME/.bashrc.env"
    fi
  else
    echo "⚠️  .bashrc.env.example not found in $SCRIPT_DIR"
  fi
  
  echo "✅ Bash configuration completed!"
}

setup_docker() {
  echo "Setting up systemd user services..."
  
  # Create user systemd directory
  mkdir -p "$HOME/.config/systemd/user"
  
  # Copy service files from examples
  local docker_dir="$SCRIPT_DIR/docker"
  
  if [[ ! -f "$docker_dir/docker-compose-apps.service.example" ]]; then
    echo "ERROR: Service template not found: $docker_dir/docker-compose-apps.service.example"
    return 1
  fi
  
  echo "--> Creating service files from templates..."
  cp "$docker_dir/docker-compose-apps.service.example" "$docker_dir/docker-compose-apps.service"
  cp "$docker_dir/docker-backup.service.example" "$docker_dir/docker-backup.service"
  cp "$docker_dir/docker-backup.timer.example" "$docker_dir/docker-backup.timer"
  
  # If dotfiles are not in the default location, update the service files
  if [[ "$SCRIPT_DIR" != "$HOME/.dotfiles" ]]; then
    echo "--> Updating service files with custom dotfiles path: $SCRIPT_DIR"
    sed -i "s|%h/.dotfiles|$SCRIPT_DIR|g" "$docker_dir/docker-compose-apps.service"
    sed -i "s|%h/.dotfiles|$SCRIPT_DIR|g" "$docker_dir/docker-backup.service"
  fi
  
  # Install user services
  echo "--> Installing systemd user services..."
  cp "$docker_dir/docker-compose-apps.service" "$HOME/.config/systemd/user/"
  cp "$docker_dir/docker-backup.service" "$HOME/.config/systemd/user/"
  cp "$docker_dir/docker-backup.timer" "$HOME/.config/systemd/user/"
  
  # Reload and enable user services
  systemctl --user daemon-reload
  systemctl --user enable docker-compose-apps.service
  systemctl --user enable docker-backup.timer
  
  # Start the backup timer
  systemctl --user start docker-backup.timer
  
  echo "✅ Docker user services configured and enabled!"
  echo "⚠️  You'll need to log out and back in for Docker group membership to take effect."
}

install_dependencies() {
  echo "Installing Ubuntu dependencies..."
  sudo apt-get update
  sudo apt-get install -y \
    curl \
    wget \
    git \
    xclip \
    htop \
    tree \
    unzip \
    zip \
    jq \
    apache2-utils \
    build-essential
}

collect_configuration() {
  echo "🔧 Collecting configuration information..."
  
  echo
  echo "Please provide the following configuration details:"
  echo "Press Enter to use default values where available."
  echo
  
  # Domain configuration
  read -p "Enter your domain name (e.g., example.com): " DOMAIN
  while [[ -z "$DOMAIN" ]]; do
    echo "⚠️  Domain name is required!"
    read -p "Enter your domain name (e.g., example.com): " DOMAIN
  done
  
  # Subdomain configuration with defaults
  read -p "Vaultwarden subdomain [vault.$DOMAIN]: " VAULTWARDEN_DOMAIN
  VAULTWARDEN_DOMAIN=${VAULTWARDEN_DOMAIN:-"vault.$DOMAIN"}
  
  read -p "Traefik dashboard subdomain [traefik.$DOMAIN]: " TRAEFIK_DOMAIN
  TRAEFIK_DOMAIN=${TRAEFIK_DOMAIN:-"traefik.$DOMAIN"}
  
  # Cloudflare configuration
  echo
  echo "🌤️  Cloudflare Configuration:"
  echo "You need a Cloudflare Tunnel token and API credentials."
  echo "Get tunnel token from: Cloudflare Zero Trust → Access → Tunnels"
  echo "Get API key from: Cloudflare Dashboard → My Profile → API Tokens"
  echo
  
  read -p "Cloudflare Tunnel Token: " CLOUDFLARE_TUNNEL_TOKEN
  while [[ -z "$CLOUDFLARE_TUNNEL_TOKEN" ]]; do
    echo "⚠️  Cloudflare Tunnel Token is required!"
    read -p "Cloudflare Tunnel Token: " CLOUDFLARE_TUNNEL_TOKEN
  done
  
  read -p "Cloudflare API Email: " CF_API_EMAIL
  while [[ -z "$CF_API_EMAIL" ]]; do
    echo "⚠️  Cloudflare API Email is required!"
    read -p "Cloudflare API Email: " CF_API_EMAIL
  done
  
  read -p "Cloudflare API Key: " CF_API_KEY
  while [[ -z "$CF_API_KEY" ]]; do
    echo "⚠️  Cloudflare API Key is required!"
    read -p "Cloudflare API Key: " CF_API_KEY
  done
  
  
  # Authentication configuration
  echo
  echo "🔐 Authentication Configuration:"
  echo "Creating Traefik dashboard authentication..."
  
  read -p "Admin username [admin]: " ADMIN_USERNAME
  ADMIN_USERNAME=${ADMIN_USERNAME:-"admin"}
  
  read -s -p "Admin password: " ADMIN_PASSWORD
  echo
  while [[ -z "$ADMIN_PASSWORD" ]]; do
    echo "⚠️  Admin password is required!"
    read -s -p "Admin password: " ADMIN_PASSWORD
    echo
  done
  
  # Generate Traefik auth hash
  if command -v htpasswd &> /dev/null; then
    TRAEFIK_AUTH_USERS=$(htpasswd -nb "$ADMIN_USERNAME" "$ADMIN_PASSWORD")
  else
    echo "⚠️  htpasswd not found. You'll need to generate the hash manually."
    TRAEFIK_AUTH_USERS="$ADMIN_USERNAME:\$2y\$10\$placeholder_hash_here"
  fi
  
  # Generate Vaultwarden admin token
  if command -v openssl &> /dev/null; then
    VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 48)
    echo "✅ Generated Vaultwarden admin token"
  else
    echo "⚠️  openssl not found. Using default token."
    VAULTWARDEN_ADMIN_TOKEN="your_admin_token_here"
  fi
  
  # Email configuration for Vaultwarden
  echo
  echo "📧 Email Configuration for Vaultwarden (optional but recommended):"
  
  read -p "SMTP Host (e.g., smtp.gmail.com) [skip]: " VAULTWARDEN_SMTP_HOST
  if [[ -n "$VAULTWARDEN_SMTP_HOST" ]]; then
    read -p "SMTP From Email: " VAULTWARDEN_SMTP_FROM
    read -p "SMTP Username: " VAULTWARDEN_SMTP_USERNAME
    read -s -p "SMTP Password/App Password: " VAULTWARDEN_SMTP_PASSWORD
    echo
  else
    VAULTWARDEN_SMTP_HOST=""
    VAULTWARDEN_SMTP_FROM=""
    VAULTWARDEN_SMTP_USERNAME=""
    VAULTWARDEN_SMTP_PASSWORD=""
  fi
  
  # Database configuration
  echo
  echo "🗄️  Database Configuration:"
  
  read -s -p "PostgreSQL password: " POSTGRES_PASSWORD
  echo
  while [[ -z "$POSTGRES_PASSWORD" ]]; do
    echo "⚠️  Database password is required!"
    read -s -p "PostgreSQL password: " POSTGRES_PASSWORD
    echo
  done
  
  # Timezone
  local current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "UTC")
  read -p "Timezone [$current_tz]: " TZ
  TZ=${TZ:-"$current_tz"}
  
  echo "✅ Configuration collection completed!"
}

write_env_file() {
  local docker_dir="$1"
  local env_file="$docker_dir/.env"
  
  echo "📝 Writing configuration to $env_file..."
  
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
  
  echo "✅ Configuration file created successfully!"
}

setup_docker_environment() {
  echo "Setting up Docker environment..."
  
  local docker_dir="$SCRIPT_DIR/docker"
  
  if [[ ! -d "$docker_dir" ]]; then
    echo "ERROR: Docker directory not found: $docker_dir"
    return 1
  fi
  
  # Interactive configuration collection
  if [[ ! -f "$docker_dir/.env" ]]; then
    collect_configuration
    write_env_file "$docker_dir"
  else
    echo "⚠️  Configuration file already exists at $docker_dir/.env"
    read -p "Do you want to reconfigure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      collect_configuration
      write_env_file "$docker_dir"
    fi
  fi
  
  # Make scripts executable
  chmod +x "$docker_dir/up.sh" 2>/dev/null || echo "⚠️  up.sh not found"
  chmod +x "$docker_dir/setup.sh" 2>/dev/null || echo "⚠️  setup.sh not found"
  chmod +x "$docker_dir/backup.sh" 2>/dev/null || echo "⚠️  backup.sh not found"
  
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
    echo "Created directory: $dir"
  done
  
  # Set proper ownership
  local current_user=$(whoami)
  sudo chown -R "$current_user:$current_user" "$docker_dir"
  
  echo "✅ Docker environment configured!"
}

setup_nvim() {
  echo "Setting up Neovim configuration..."
  
  local nvim_dir="$SCRIPT_DIR/nvim"
  
  if [[ ! -d "$nvim_dir" ]]; then
    echo "⚠️  Neovim directory not found: $nvim_dir"
    return
  fi
  
  # Create nvim config directory if it doesn't exist
  mkdir -p "$HOME/.config/nvim"
  
  find "$nvim_dir" -type f -printf "%P\n" | while read -r file; do
    target_file="$HOME/.config/nvim/$file"
    create_symlink "$nvim_dir/$file" "$target_file"
  done
  
  echo "✅ Neovim configuration completed!"
}

## Main Execution Flow

main() {
  local options=("setup_bash" "setup_docker" "setup_docker_environment" "setup_nvim")
  local descriptions=("Bash Configuration" "Docker Service" "Docker Environment" "Neovim")
  local selected=("false" "false" "false" "false")

  while true; do
    clear
    echo "-------------------------------------"
    echo "  System Setup Selector"
    echo "-------------------------------------"
    echo "Select which steps to run. Dependencies will always be installed."
    echo ""
    for i in "${!options[@]}"; do
      if [[ "${selected[$i]}" == "true" ]]; then
        echo "  $((i + 1))) [x] ${descriptions[$i]}"
      else
        echo "  $((i + 1))) [ ] ${descriptions[$i]}"
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

  echo "Starting system setup..."
  sudo -v

  install_dependencies

  for i in "${!options[@]}"; do
    if [[ "${selected[$i]}" == "true" ]]; then
      ${options[$i]}
    fi
  done

  echo "✅ Setup completed successfully!"
  echo ""
  echo "Next steps:"
  echo "  1. Log out and back in for Docker group membership"
  echo "  2. Set up Cloudflare Tunnel routes in your dashboard:"
  echo "     • Add DNS records (CNAME) pointing to your tunnel"
  echo "     • Configure tunnel routes to point to https://traefik:443"
  echo "  3. Start services:"
  echo "     cd $SCRIPT_DIR/docker && ./up.sh up -d"
  echo "  4. Check service status:"
  echo "     ./up.sh logs -f"
  echo "  5. Access your services at the configured domains"
  echo ""
  echo "Service commands (user services, no sudo needed):"
  echo "  • systemctl --user status docker-compose-apps.service"
  echo "  • systemctl --user start docker-compose-apps.service"
  echo "  • systemctl --user stop docker-compose-apps.service"
  echo ""
  echo "Backup system commands:"
  echo "  • systemctl --user status docker-backup.timer"
  echo "  • systemctl --user list-timers  # Check next backup time"
  echo "  • systemctl --user start docker-backup.service  # Manual backup"
  echo "  • journalctl --user -u docker-backup.service  # View backup logs"
  echo "  • ./backup.sh force  # Force backup (ignore daily limit)"
}

main
