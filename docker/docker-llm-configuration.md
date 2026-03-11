# docker-llm-configuration.md — NAS Docker Stack Setup Guide

This file is written for AI agents (LLMs) that will configure this stack for a new user.
Read this entire file before making any changes. It describes the architecture, every
service, every secret, and the exact steps to go from a fresh clone to a running system.

---

## Architecture Overview

```
Internet
    │
    ▼
Cloudflare Edge (DNS + DDoS protection)
    │  (outbound-only tunnel — no open ports on the router)
    ▼
Cloudflared (Docker container) ─────────────────────────────────────────┐
    │                                                                   │
    │  HTTP/HTTPS traffic                     SSH traffic               │
    ▼                                                ▼                  │
Traefik (:80/:443)                        Host SSH server (:22)         │
    │                                                                   │
    ├─→ subdomain.DOMAIN     → Vaultwarden (:80)                        │
    ├─→ subdomain.DOMAIN     → Home Assistant (:8123)                   │
    └─→ subdomain.DOMAIN     → Uptime Kuma (:3001)                      │
                                                                        │
LAN users ──────────────────────────────────────────────────────────────┘
    └─→ Access Traefik directly (no tunnel required on the local network)

PostgreSQL (shared, available on Docker network + localhost:5432 for dev)
    ├─→ Docker apps: hostname "postgres" on port 5432
    └─→ Host apps (Rails dev): localhost:5432 (127.0.0.1 only)
```

**Key principle**: Cloudflared establishes an outbound-only tunnel — no inbound ports
need to be opened on the router or firewall. Cloudflare's edge receives public traffic
and forwards it through the tunnel to Traefik, which then routes to the correct service.

---

## Repository Structure

```
docker/
├── docker-llm-configuration.md       ← You are here
├── up.sh                             ← Orchestration script (run this to start everything)
├── docker-compose-apps.service       ← Systemd unit for auto-start on boot
├── .gitignore (at repo root)         ← Excludes .env files, credentials, data dirs
│
├── traefik/                          ← Reverse proxy (existing, always running)
│   ├── docker-compose.yml
│   ├── .env.example                  ← Copy to .env and fill in
│   └── certs/
│       └── tls.yml                   ← TLS certificate definitions
│
├── vaultwarden/                      ← Password manager (existing, SQLite)
│   ├── docker-compose.yml
│   ├── .env.example
│   └── vw-data/                      ← Gitignored: SQLite DB + RSA key
│
├── cloudflared/                      ← Cloudflare tunnel client
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── config.yml.example            ← Copy to config.yml and fill in
│   └── <TUNNEL_UUID>.json            ← Gitignored: tunnel credentials
│
├── postgres/                         ← Shared PostgreSQL instance
│   ├── docker-compose.yml
│   └── .env.example
│
├── homeassistant/                    ← Home automation
│   ├── docker-compose.yml
│   ├── .env.example
│   └── config/                       ← Gitignored: HA config and secrets
│
└── uptimekuma/                       ← Service uptime monitoring
    ├── docker-compose.yml
    ├── .env.example
    └── data/                         ← Gitignored: SQLite DB
```

---

## Environment Variable Reference

All `.env` files are gitignored. Each service directory has a `.env.example` that
documents the expected variables. When configuring for a new user, create each `.env`
by copying the `.env.example` and ask the user for the real values.

> **Variable name collisions**: `up.sh` sources all `.env` files into a flat namespace.
> All variable names across all services are intentionally unique. Do not reuse names.

### `traefik/.env`

| Variable | Description | Example |
|---|---|---|
| `TRAEFIK_AUTH_USERS` | Basic auth for Traefik dashboard (htpasswd format, `$` doubled) | `admin:$$2y$$05$$...` |

### `vaultwarden/.env`

| Variable | Description | Example |
|---|---|---|
| `DOMAIN` | Full HTTPS URL used by Vaultwarden internally (in emails, links) | `https://subdomain.yourdomain.com` |
| `VW_HOSTNAME` | Hostname for Traefik routing (no `https://`) | `vault.yourdomain.com` |

### `cloudflared/.env`

| Variable | Description | Example |
|---|---|---|
| `CF_TUNNEL_ID` | UUID of the Cloudflare tunnel | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| `CF_DOMAIN` | Root domain managed in Cloudflare DNS | `yourdomain.com` |
| `CF_SSH_SUBDOMAIN` | Non-obvious random slug for SSH access | `t3rm` |

### `postgres/.env`

| Variable | Description | Example |
|---|---|---|
| `POSTGRES_USER` | PostgreSQL superuser name | `postgres` |
| `POSTGRES_PASSWORD` | Superuser password (use a long random string) | `openssl rand -base64 32` |
| `POSTGRES_DB` | Default database name (admin DB, not for apps) | `postgres` |

### `homeassistant/.env`

| Variable | Description | Example |
|---|---|---|
| `HA_HOSTNAME` | Hostname for Traefik routing | `ha.yourdomain.com` |
| `HA_TZ` | Timezone for HA (tz database name) | `America/New_York` |

### `uptimekuma/.env`

| Variable | Description | Example |
|---|---|---|
| `UK_HOSTNAME` | Hostname for Traefik routing | `status.yourdomain.com` |

--- ## Step-by-Step Setup for a New User

Follow these steps in order. Steps marked **[Cloudflare Dashboard]** require browser
access to https://one.dash.cloudflare.com.

### Prerequisites

- Before installing verify if it's not already
- Docker and Docker Compose installed
- A domain managed in Cloudflare DNS
- A Cloudflare account (free tier is sufficient)
- `git clone` of this repository

### 1. Create `.env` files

For each service, copy the example and fill in values:

```bash
cp traefik/.env.example traefik/.env
cp vaultwarden/.env.example vaultwarden/.env
cp cloudflared/.env.example cloudflared/.env
cp postgres/.env.example postgres/.env
cp homeassistant/.env.example homeassistant/.env
cp uptimekuma/.env.example uptimekuma/.env
```

Then edit each `.env` file with the user's real values. Refer to the
"Environment Variable Reference" section above for guidance on each variable.

### 2. Set up the Cloudflare Tunnel

**[Cloudflare Dashboard]**

1. Ask the user to go to https://one.dash.cloudflare.com → **Networks** → **Tunnels**
2. Click **Create a tunnel** → choose **Cloudflared**
3. Name the tunnel (e.g. `nas-tunnel`)
4. Click **Next** — you'll see a connector token. **Skip the automatic install** — we're running cloudflared in Docker.
5. After saving, open the tunnel and copy the **Tunnel ID** (UUID format)
6. Go to **Configure** → **Credentials** → download the credentials JSON file
7. Place the JSON file at: `docker/cloudflared/<TUNNEL_UUID>.json`
8. Set `CF_TUNNEL_ID` in `cloudflared/.env` to the tunnel UUID

### 3. Create `cloudflared/config.yml`

Copy the example and fill in placeholders:

```bash
cp cloudflared/config.yml.example cloudflared/config.yml
```

Edit `config.yml` and replace:
- `<TUNNEL_UUID>` → the UUID from step 2
- `<YOUR_DOMAIN>` → the user's domain (e.g. `yourdomain.com`)
- `<YOUR_SSH_SLUG>` → the value of `CF_SSH_SUBDOMAIN` from `cloudflared/.env`

The final `config.yml` should look like:
```yaml
tunnel: a1b2c3d4-e5f6-7890-abcd-ef1234567890
credentials-file: /etc/cloudflared/a1b2c3d4-e5f6-7890-abcd-ef1234567890.json

ingress:
  - hostname: sudomain.yourdomain.com
    service: https://traefik:443
    originRequest:
      noTLSVerify: true
  - hostname: sudomain.yourdomain.com
    service: https://traefik:443
    originRequest:
      noTLSVerify: true
  - hostname: sudomain.yourdomain.com
    service: https://traefik:443
    originRequest:
      noTLSVerify: true
  - hostname: sudomain.yourdomain.com
    service: ssh://localhost:22
  - service: http_status:404
```

### 4. Configure TLS certificates for local access

The `traefik/certs/` directory contains locally-generated TLS certificates
(generated with `mkcert`) for `.local` domains. These are used for LAN access.

If the user needs to regenerate them:
```bash
# Install mkcert: https://github.com/FiloSottile/mkcert
mkcert -install
mkcert -cert-file traefik/certs/vault.local.pem -key-file traefik/certs/vault.local-key.pem vault.local
mkcert -cert-file traefik/certs/traefik.local.pem -key-file traefik/certs/traefik.local-key.pem traefik.local
```

The `.pem` certificate files are tracked in git. The `*-key.pem` private key files are gitignored.
If they are missing (fresh clone), regenerate them with the commands above.

### 5. Configure systemd auto-start

The `docker-compose-apps.service` file uses `YOUR_USER_NAME` as a placeholder.

```bash
# Substitute the placeholder with the actual username
sed "s/YOUR_USER_NAME/$(whoami)/g" docker/docker-compose-apps.service \
  > /tmp/docker-compose-apps.service

# Install and enable the unit
sudo cp /tmp/docker-compose-apps.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable docker-compose-apps
sudo systemctl start docker-compose-apps
```

### 6. Start the stack

```bash
cd ~/.dotfiles/docker
./up.sh up -d
```

The script will:
- Create the `traefik_network` Docker network if it doesn't exist
- Load all `.env` files
- Warn about any missing `.env` or `cloudflared/config.yml`
- Start all services

### 7. Verify services are running

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

Expected containers: `traefik`, `vaultwarden`, `cloudflared`, `postgres`, `homeassistant`, `uptimekuma`

Check Cloudflare tunnel status:
```bash
docker logs cloudflared --tail 20
```

You should see: `Registered tunnel connection` (repeated 4 times for 4 Cloudflare PoPs).

---

## SSH Remote Access

### How it works

SSH traffic goes through the Cloudflare tunnel directly to the host's SSH server (port 22).
It does **not** go through Traefik (SSH is not HTTP). The subdomain is intentionally
non-obvious (`CF_SSH_SUBDOMAIN`) and protected by Cloudflare Access (identity auth).

### **[Cloudflare Dashboard]** — Set up Cloudflare Access for SSH

1. Go to https://one.dash.cloudflare.com → **Access** → **Applications**
2. Click **Add an application** → **Self-hosted**
3. Fill in:
   - **Application name**: `NAS SSH`
   - **Application domain**: `<CF_SSH_SUBDOMAIN>.<CF_DOMAIN>` (e.g. `t3rm.yourdomain.com`)
   - **Session duration**: `24h` (or as preferred)
4. Click **Next** → configure a policy:
   - **Policy name**: `Owner only`
   - **Action**: Allow
   - **Include rule**: Emails → add the user's email address
5. Click **Next** → under **Additional settings**, enable **Browser rendering** → set to **SSH**
6. Save the application

### Browser terminal (mobile/tablet access)

Visit `https://<CF_SSH_SUBDOMAIN>.<CF_DOMAIN>` in any browser.
Cloudflare will prompt for identity authentication, then render a full SSH terminal.
No app installation required — works on iOS, Android, any device.

### Native terminal (desktop/laptop access)

Install `cloudflared` on the client machine:
- macOS: `brew install cloudflared`
- Linux: https://pkg.cloudflare.com/index.html
- Windows: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/

Add to `~/.ssh/config` on the client:
```
Host <CF_SSH_SUBDOMAIN>.<CF_DOMAIN>
  ProxyCommand cloudflared access ssh --hostname %h
```

Then connect normally:
```bash
ssh username@<CF_SSH_SUBDOMAIN>.<CF_DOMAIN>
```

On first connection, `cloudflared` opens a browser window for identity authentication.
Subsequent connections use a cached token (valid for the session duration set in Access).

---

## Adding a New Service

Follow this pattern to add any new service:

### 1. Create the service directory and files

```bash
mkdir docker/myservice
touch docker/myservice/docker-compose.yml
touch docker/myservice/.env.example
```

### 2. `docker-compose.yml` template

```yaml
services:
  myservice:
    image: vendor/myservice:latest
    container_name: myservice
    restart: unless-stopped
    environment:
      - MY_VAR=${MY_VAR}        # Sourced from myservice/.env
    volumes:
      - ./data:/app/data         # Gitignored via **/data/ rule
    labels:
      - traefik.enable=true
      - traefik.http.routers.myservice.rule=Host(`${MY_HOSTNAME}`)
      - traefik.http.routers.myservice.entrypoints=websecure
      - traefik.http.routers.myservice.tls=true
      - traefik.http.services.myservice-svc.loadbalancer.server.port=8080
    networks:
      - traefik_network

networks:
  traefik_network:
    external: true
```

### 3. `.env.example` template

```bash
# MY_HOSTNAME: Public hostname for Traefik routing.
# Add a matching ingress rule in cloudflared/config.yml.
MY_HOSTNAME=myservice.yourdomain.com

# MY_VAR: Description of what this variable does.
MY_VAR=placeholder_value
```

### 4. Add ingress rule to `cloudflared/config.yml`

Add before the catch-all line:
```yaml
  - hostname: myservice.yourdomain.com
    service: https://traefik:443
    originRequest:
      noTLSVerify: true
```

### 5. Using the shared PostgreSQL instance

If the service needs PostgreSQL:

```bash
# Create a database for the new service
docker exec -it postgres psql -U postgres -c "CREATE DATABASE myservice;"
```

Connection string for the service:
```
postgresql://postgres:POSTGRES_PASSWORD@postgres:5432/myservice
```

### 6. Restart the stack

```bash
./up.sh up -d
```

`up.sh` automatically discovers all `docker-compose.yml` files under `docker/`.
No manual registration is needed.

---

## PostgreSQL Development Access

### Architecture

PostgreSQL is configured for dual access:
- **Docker containers**: Connect via hostname `postgres:5432` on `traefik_network`
- **Host development**: Connect via `localhost:5432` (bound to 127.0.0.1 only)

```
┌─────────────────────────────────────────────────────────┐
│                      Your Host Machine                  │
│                                                         │
│  ┌─────────────────┐      ┌─────────────────────────┐   │
│  │   Rails (host)  │      │    Docker Network       │   │
│  │   development   │      │   (traefik_network)     │   │
│  │                 │      │                         │   │
│  │  Rails server   │◄────►│  ┌─────────────────┐    │   │
│  │  (localhost)    │      │  │   PostgreSQL    │    │   │
│  │                 │      │  │   (postgres)    │    │   │
│  │  Connection:    │      │  │                 │    │   │
│  │  localhost:5432 │◄────►│  │  Port 5432      │    │   │
│  │                 │      │  │  (127.0.0.1)    │    │   │
│  └─────────────────┘      │  └─────────────────┘    │   │
│                           └─────────────────────────┘   │
│                                    │                    │
│                           ┌────────┴────────┐           │
│                           ▼                 ▼           │
│                    ┌────────────┐    ┌────────────┐     │
│                    │  Docker    │    │  Docker    │     │
│                    │   App 1    │    │   App 2    │     │
│                    │  (hostname:│    │  (hostname:│     │
│                    │  postgres) │    │  postgres) │     │
│                    └────────────┘    └────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### Database Isolation Strategy

Each application gets **dedicated databases and users** within the single PostgreSQL instance:

```sql
-- Create user for myapp1 (superuser creates this)
CREATE USER myapp1 WITH PASSWORD 'secure_random_password';

-- Create databases for myapp1
CREATE DATABASE myapp1_development OWNER myapp1;
CREATE DATABASE myapp1_test OWNER myapp1;

-- Create user for myapp2
CREATE USER myapp2 WITH PASSWORD 'another_secure_password';

-- Create databases for myapp2
CREATE DATABASE myapp2_development OWNER myapp2;
CREATE DATABASE myapp2_test OWNER myapp2;
```

**Benefits:**
- Users cannot access other users' databases
- Applications are isolated at the database level
- Single PostgreSQL instance (less resource overhead)

### Development Setup

**Create databases and user**

```bash
# Replace 'myapp' with your application name
# Replace 'secure_password' with a generated password

docker exec -it postgres psql -U postgres -c "CREATE USER myapp WITH PASSWORD 'secure_password';"
docker exec -it postgres psql -U postgres -c "CREATE DATABASE myapp_development OWNER myapp;"
docker exec -it postgres psql -U postgres -c "CREATE DATABASE myapp_test OWNER myapp;"

# Grant privileges (optional, owner has full access by default)
docker exec -it postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE myapp_development TO myapp;"
docker exec -it postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE myapp_test TO myapp;"
```

### PostgreSQL Commands Reference

```bash
# Connect to PostgreSQL as superuser
docker exec -it postgres psql -U postgres

# List all databases
\l

# List all users
\du

# Create database
create database myapp_development;

# Create user with password
create user myapp with password 'password';

# Grant ownership
alter database myapp_development owner to myapp;

# Drop database (careful!)
drop database myapp_development;

# Connect to specific database
\c myapp_development

# List tables in current database
\dt

# Exit psql
\q
```

### Security Notes

- Port 5432 is bound to `127.0.0.1` only (localhost), not exposed to LAN or internet
- Each application should use its own database user
- Never share database users between applications
- Store passwords in environment variables, not in code
- `.env` files are gitignored by default

---

## Networking Reference

| Network | Purpose |
|---|---|
| `traefik_network` (external Docker network) | Shared network all services join. Traefik discovers containers on this network via Docker socket. |
| `localhost` (host network) | Cloudflared's SSH ingress (`ssh://localhost:22`) connects to the host's SSH server directly. |

## Service Port Reference

| Service | Internal port | Host port | Access |
|---|---|---|---|
| Traefik | 80, 443 | 80, 443 | Host-published; LAN + tunnel |
| Vaultwarden | 80 | — | Via Traefik only |
| Home Assistant | 8123 | — | Via Traefik only |
| Uptime Kuma | 3001 | — | Via Traefik only |
| PostgreSQL | 5432 | 5432 (127.0.0.1 only) | Docker network + localhost |
| Cloudflared | — | — | Outbound tunnel only |

## Troubleshooting

### Tunnel not connecting
```bash
docker logs cloudflared --tail 50
```
Common causes: wrong `CF_TUNNEL_ID` in `config.yml`, missing credentials JSON,
or credentials JSON filename doesn't match the tunnel UUID.

### Service not reachable via public URL
1. Check tunnel is active: `docker logs cloudflared | grep "Registered tunnel"`
2. Check Traefik has picked up the service: visit `http://traefik.local` on LAN
3. Verify the hostname in `config.yml` matches the `traefik.http.routers.*.rule` label
4. Check service is running: `docker ps`

### Restarting a single service
```bash
docker compose -f docker/servicename/docker-compose.yml restart
```

### Viewing logs for all services
```bash
./up.sh logs -f --tail 100
```
