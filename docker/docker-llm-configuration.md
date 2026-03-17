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
│   ├── cert.pem                      ← Gitignored: Cloudflare origin cert (created by tunnel login)
│   └── <TUNNEL_UUID>.json            ← Gitignored: tunnel credentials
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
by copying the `.env.example` and **ask the user to provide or generate** the real values.

> **Important for LLM agents:** Never generate secrets (passwords, tokens) yourself.
> Always ask the user to generate them using the commands provided in `.env.example` files.
> This ensures the user has control over their credentials and you don't accidentally
> expose secrets in conversation logs or tool outputs.

> **Variable name collisions**: `up.sh` sources all `.env` files into a flat namespace.
> All variable names across all services are intentionally unique. Do not reuse names.

### Subdomain Naming Convention

All public-facing subdomains should use **non-obvious random slugs** instead of descriptive names (e.g., `v4u1t2` instead of `vault`). This reduces discoverability and makes automated scanning less effective.

**Why?**
- While Cloudflare Access provides strong identity-based authentication, using random slugs adds defense in depth
- Reduces noise from automated scanners
- Makes service enumeration and social engineering harder

**Guidelines:**
- Use 3-8 character random alphanumeric strings
- Avoid dictionary words or service names
- Each service gets a unique, unrelated slug
- Cloudflare Access policies provide authentication regardless of subdomain obscurity

**Example mapping:**
| Service | Slug | Full Domain |
|---------|------|-------------|
| Vaultwarden | `x7k9` | `x7k9.yourdomain.com` |
| Home Assistant | `m3p2` | `m3p2.yourdomain.com` |
| Uptime Kuma | `q8n4` | `q8n4.yourdomain.com` |
| SSH Access | `t3rm` | `t3rm.yourdomain.com` |

**Note:** The SSH slug is configured in `cloudflared/.env` as `CF_SSH_SUBDOMAIN`. All other service hostnames are defined in their respective `.env` files. Each user should generate their own unique random slugs.

### `traefik/.env`

| Variable | Description | Example |
|---|---|---|
| `TRAEFIK_AUTH_USERS` | Basic auth for Traefik dashboard (htpasswd format, `$` doubled) | `admin:$$2y$$05$$...` |

**Generating the password hash:** Since `htpasswd` is not available on all systems (e.g., Arch Linux), use Docker:

```bash
# Ask the user to run this and provide the output
docker run --rm httpd:alpine htpasswd -nbB username password | sed -e 's/\$/\$\$/g'
```

The `sed` command doubles all `$` characters, which is required for Docker Compose environment variable escaping.

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

### `homeassistant/.env`

| Variable | Description | Example |
|---|---|---|
| `HA_HOSTNAME` | Hostname for Traefik routing | `ha.yourdomain.com` |
| `HA_TZ` | Timezone for HA (tz database name) | `America/New_York` |

**Important:** Home Assistant requires explicit configuration to accept requests from a reverse proxy. After the first startup, add this to `homeassistant/config/configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.18.0.0/16  # traefik_network subnet (verify with: docker network inspect traefik_network)
```

Then restart Home Assistant: `docker restart homeassistant`

Without this configuration, Home Assistant will reject all requests from Traefik with HTTP 400/403.

### `uptimekuma/.env`

| Variable | Description | Example |
|---|---|---|
| `UK_HOSTNAME` | Hostname for Traefik routing | `status.yourdomain.com` |

---

## Step-by-Step Setup for a New User

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
cp homeassistant/.env.example homeassistant/.env
cp uptimekuma/.env.example uptimekuma/.env
```

Then edit each `.env` file with the user's real values. Refer to the
"Environment Variable Reference" section above for guidance on each variable.

### 2. Set up the Cloudflare Tunnel

**Create credentials using Docker:**

```bash
cd docker/cloudflared

# The cloudflared container runs as user 'nonroot' (uid 65532).
# Grant write permissions so it can save credentials:
chmod 777 .

# Authenticate with Cloudflare (opens browser)
docker run --rm -it \
  -v $(pwd):/home/nonroot/.cloudflared \
  cloudflare/cloudflared:latest tunnel login

# Create the tunnel
docker run --rm -it \
  -v $(pwd):/home/nonroot/.cloudflared \
  cloudflare/cloudflared:latest tunnel create nas-tunnel

# The tunnel UUID file will be saved in current directory
```

> **Note:** The volume mount uses `/home/nonroot/.cloudflared` (not `/root/.cloudflared`)
> because the cloudflared Docker image runs as a non-root user.

**Set up credentials file:**

```bash
# Find the credentials JSON file (UUID format)
JSON_FILE=$(ls -1 *.json 2>/dev/null | grep -E '^[0-9a-f-]{36}\.json$' | head -1)
TUNNEL_UUID=$(echo "$JSON_FILE" | sed 's/\.json$//')

# Set the tunnel ID in .env
sed -i "s/CF_TUNNEL_ID=.*/CF_TUNNEL_ID=${TUNNEL_UUID}/" .env
```

**Important:** The JSON credentials file is required. Dashboard-created tunnels provide a base64 token (starting with `eyJ...`) which cannot be used directly. The `cloudflared tunnel create` command generates the required JSON file.

### 3. Create `cloudflared/config.yml`

Copy the example and fill in placeholders:

```bash
cp cloudflared/config.yml.example cloudflared/config.yml
```

Edit `config.yml` and replace:
- `<TUNNEL_UUID>` → the UUID from step 2 (appears twice: tunnel ID and credentials-file path)
- `<YOUR_DOMAIN>` → the user's domain (e.g. `yourdomain.com`)
- Each `<YOUR_*_SLUG>` → the corresponding random subdomain from each service's `.env`

The final `config.yml` should look like:
```yaml
tunnel: a1b2c3d4-e5f6-7890-abcd-ef1234567890
credentials-file: /etc/cloudflared/a1b2c3d4-e5f6-7890-abcd-ef1234567890.json

ingress:
  - hostname: x7k9.yourdomain.com      # Vaultwarden (matches VW_HOSTNAME)
    service: https://traefik:443
    originRequest:
      noTLSVerify: true
  - hostname: m3p2.yourdomain.com      # Home Assistant (matches HA_HOSTNAME)
    service: https://traefik:443
    originRequest:
      noTLSVerify: true
  - hostname: q8n4.yourdomain.com      # Uptime Kuma (matches UK_HOSTNAME)
    service: https://traefik:443
    originRequest:
      noTLSVerify: true
  - hostname: t3rm.yourdomain.com      # SSH (matches CF_SSH_SUBDOMAIN)
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

Expected containers: `traefik`, `vaultwarden`, `cloudflared`, `homeassistant`, `uptimekuma`

Check Cloudflare tunnel status:
```bash
docker logs cloudflared --tail 20
```

You should see: `Registered tunnel connection` (repeated 4 times for 4 Cloudflare PoPs).

### 8. Create DNS routes for each hostname

The tunnel is running, but Cloudflare DNS doesn't know about it yet. Create CNAME records for each hostname:

```bash
cd docker/cloudflared

# Get tunnel UUID from .env
TUNNEL_UUID=$(grep CF_TUNNEL_ID .env | cut -d= -f2)

# Create DNS routes for each hostname (replace with actual hostnames from .env files)
docker run --rm \
  -v $(pwd):/home/nonroot/.cloudflared \
  cloudflare/cloudflared:latest tunnel route dns $TUNNEL_UUID <VW_HOSTNAME>

docker run --rm \
  -v $(pwd):/home/nonroot/.cloudflared \
  cloudflare/cloudflared:latest tunnel route dns $TUNNEL_UUID <HA_HOSTNAME>

docker run --rm \
  -v $(pwd):/home/nonroot/.cloudflared \
  cloudflare/cloudflared:latest tunnel route dns $TUNNEL_UUID <UK_HOSTNAME>

docker run --rm \
  -v $(pwd):/home/nonroot/.cloudflared \
  cloudflare/cloudflared:latest tunnel route dns $TUNNEL_UUID <CF_SSH_SUBDOMAIN>.<CF_DOMAIN>
```

Each command should respond with: `<hostname> is now configured to route to your tunnel`

**Note:** DNS propagation is usually instant for Cloudflare-managed domains, but local DNS resolvers may cache negative lookups. See the Troubleshooting section for testing with `--resolve`.

### 9. Verify services are accessible via public URLs

Test each service through the Cloudflare tunnel:

```bash
# Get Cloudflare proxy IPs for your domain
curl -sH "accept: application/dns-json" \
  "https://cloudflare-dns.com/dns-query?name=<VW_HOSTNAME>&type=A" | \
  grep -o '"data":"[^"]*"' | head -1

# Test with resolved IP (bypasses local DNS cache)
CF_IP="<IP_FROM_ABOVE>"
curl -s -w "%{http_code}" -o /dev/null --resolve "<VW_HOSTNAME>:443:$CF_IP" "https://<VW_HOSTNAME>"
```

Expected responses:
- Vaultwarden: `200`
- Home Assistant: `302` (redirect to onboarding)
- Uptime Kuma: `200` or `302` (redirect to setup)

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

### 5. Restart the stack

```bash
./up.sh up -d
```

`up.sh` automatically discovers all `docker-compose.yml` files under `docker/`.
No manual registration is needed.

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
| Cloudflared | — | — | Outbound tunnel only |

## Troubleshooting

### Home Assistant returns 400 or 403
Home Assistant blocks requests from reverse proxies by default. Check the logs:
```bash
docker logs homeassistant 2>&1 | grep -i "reverse proxy"
```
If you see "A request from a reverse proxy was received... but your HTTP integration is not set-up for reverse proxies", add the `http:` configuration block to `homeassistant/config/configuration.yaml` as described in the Environment Variable Reference section above.

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

**DNS cache issues:** Local DNS resolvers may cache negative lookups. To bypass local DNS and test directly against Cloudflare:
```bash
# Get the current Cloudflare IPs for your domain
curl -sH "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=subdomain.yourdomain.com&type=A"

# Test with --resolve to bypass local DNS
curl -s -w "%{http_code}" -o /dev/null --resolve "subdomain.yourdomain.com:443:CLOUDFLARE_IP" "https://subdomain.yourdomain.com"
```

### Restarting a single service
```bash
docker compose -f docker/servicename/docker-compose.yml restart
```

### Viewing logs for all services
```bash
./up.sh logs -f --tail 100
```
