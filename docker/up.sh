#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_NAME="traefik_network"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

# Check if .env file exists
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    error ".env file not found! Please run the setup script first: cd $SCRIPT_DIR/.. && ./install_omarchy.sh"
fi

# Create Docker network if it doesn't exist
if ! docker network ls | grep -q "$NETWORK_NAME"; then
    log "Network '$NETWORK_NAME' not found. Creating it now..."
    docker network create "$NETWORK_NAME"
else
    log "Network '$NETWORK_NAME' already exists."
fi

# Load environment variables from all .env files
for env_file in $(find . -mindepth 2 -name '.env'); do
  echo "Loading environment variables from $env_file"
  set -a
  source "$env_file"
  set +a
done

# Build Docker Compose command
COMPOSE_FILES=""
for f in $(find . -mindepth 2 -name 'docker-compose.yml'); do
  COMPOSE_FILES+=" -f $f"
done

COMMAND="docker compose$COMPOSE_FILES $@"

echo "Running command: $COMMAND"
eval "$COMMAND"
