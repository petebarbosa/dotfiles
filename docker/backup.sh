#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backups"
DATE=$(date +%Y%m%d_%H%M%S)
TODAY=$(date +%Y%m%d)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[BACKUP]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[BACKUP] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[BACKUP] ERROR:${NC} $1"
    exit 1
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if backup already exists for today
check_daily_backup() {
    if ls "$BACKUP_DIR"/*_${TODAY}_* >/dev/null 2>&1; then
        log "Backup already exists for today ($TODAY)"
        log "Existing backups:"
        ls -la "$BACKUP_DIR"/*_${TODAY}_* 2>/dev/null || true
        return 0
    fi
    return 1
}

# Clean up old backups (keep only 2 weeks = 14 days)
cleanup_old_backups() {
    log "Cleaning up backups older than 2 weeks..."
    
    # Calculate date 14 days ago
    if command -v date >/dev/null 2>&1; then
        # Linux date command
        CUTOFF_DATE=$(date -d "14 days ago" +%Y%m%d 2>/dev/null || date -d "-14 days" +%Y%m%d 2>/dev/null)
    else
        # Fallback for systems without GNU date
        CUTOFF_DATE=$(python3 -c "import datetime; print((datetime.datetime.now() - datetime.timedelta(days=14)).strftime('%Y%m%d'))" 2>/dev/null || echo "$(date +%Y%m%d)")
    fi
    
    log "Removing backups older than $CUTOFF_DATE..."
    
    # Find and remove old backup files
    find "$BACKUP_DIR" -name "*.tar.gz" -o -name "*.sql.gz" | while read -r file; do
        # Extract date from filename (format: service_YYYYMMDD_HHMMSS.ext)
        filename=$(basename "$file")
        file_date=$(echo "$filename" | grep -oE '[0-9]{8}' | head -1)
        
        if [[ -n "$file_date" ]] && [[ "$file_date" -lt "$CUTOFF_DATE" ]]; then
            log "Removing old backup: $filename"
            rm -f "$file"
        fi
    done
    
    # Also clean up any empty directories
    find "$BACKUP_DIR" -type d -empty -delete 2>/dev/null || true
}

# Check if this is a manual run or automated run
MANUAL_RUN=${1:-"auto"}

if [[ "$MANUAL_RUN" != "force" ]] && check_daily_backup; then
    log "Skipping backup - already completed today"
    log "Use './backup.sh force' to create additional backup"
    exit 0
fi

log "Starting backup process for $TODAY..."

# Backup Vaultwarden data
if [ -d "$SCRIPT_DIR/vaultwarden/vw-data" ]; then
    log "Backing up Vaultwarden data..."
    tar -czf "$BACKUP_DIR/vaultwarden_$DATE.tar.gz" -C "$SCRIPT_DIR/vaultwarden" vw-data
else
    warn "Vaultwarden data directory not found, skipping..."
fi

# Backup PostgreSQL database
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^postgres$"; then
    log "Backing up PostgreSQL database..."
    
    # Check if .env file exists and source it
    if [ -f "$SCRIPT_DIR/.env" ]; then
        set -a
        source "$SCRIPT_DIR/.env"
        set +a
        
        # Verify required variables are set
        if [[ -n "$POSTGRES_USER" ]] && [[ -n "$POSTGRES_DB" ]]; then
            docker exec postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$BACKUP_DIR/postgres_$DATE.sql.gz" || warn "PostgreSQL backup failed"
        else
            warn "PostgreSQL credentials not found in .env file, skipping database backup"
        fi
    else
        warn ".env file not found, skipping PostgreSQL backup"
    fi
else
    warn "PostgreSQL container not running, skipping database backup"
fi

# Backup Traefik certificates
if [ -d "$SCRIPT_DIR/traefik/letsencrypt" ]; then
    log "Backing up Traefik certificates..."
    tar -czf "$BACKUP_DIR/traefik_certs_$DATE.tar.gz" -C "$SCRIPT_DIR/traefik" letsencrypt
fi

# Backup configuration files
log "Backing up configuration files..."
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" \
    --exclude="*/postgres-data/*" \
    --exclude="*/vw-data/*" \
    --exclude="*/letsencrypt/*" \
    --exclude="*/uptime-kuma-data/*" \
    --exclude="*/portainer-data/*" \
    --exclude="*/pgadmin-data/*" \
    -C "$SCRIPT_DIR/.." docker

# Clean up old backups (2 weeks retention)
cleanup_old_backups

log "Backup completed successfully!"
log "Backup files stored in: $BACKUP_DIR"
log "Today's backups:"
ls -la "$BACKUP_DIR"/*_${TODAY}_* 2>/dev/null || log "No backups found for today"
