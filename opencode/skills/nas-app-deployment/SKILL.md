---
name: nas-app-deployment
description: >
  Deploy applications to the NAS Docker stack at ~/.dotfiles/docker/. Use when
  adding a new service, creating a docker-compose.yml for the NAS, configuring
  Traefik routing, adding a subdomain, setting up Cloudflare tunnel ingress, or
  exposing an application publicly or on the local network. Do NOT use for general
  Docker questions unrelated to the NAS stack.
---

# NAS App Deployment

Deploy applications to the NAS Docker stack at `~/.dotfiles/docker/`.

## Stack Overview

```
Internet -> Cloudflare Edge -> Cloudflared tunnel -> Traefik (:443) -> Services
                                                         ^
                                               LAN users connect here directly
```

All HTTP(S) services route through Traefik. Cloudflared provides public access
via an outbound-only tunnel (no inbound ports on the router). Services join
dedicated per-app Docker networks for complete isolation.

Existing infrastructure: Traefik, Cloudflared.

## Decision Tree

Before creating any files, determine the deployment pattern by asking:

1. **What is the application?**
   - Off-the-shelf Docker image (e.g., Paperless-ngx, Miniflux) -> Pattern A
   - Custom full-stack app (frontend + backend + database) -> Pattern B
   - Custom single-service app -> Pattern D

2. **Who will use this application?**
   - Personal/owner only -> Pattern A or B with random subdomain
   - External users will access it -> Pattern D (enhanced isolation considerations)

3. **Does it need a database?**
   - Yes -> Include PostgreSQL and/or Redis in the service's docker-compose.yml
   - Every app has its own dedicated database(s)

4. **Should it be publicly accessible?**
   - Yes, via Cloudflare tunnel -> add ingress rule + DNS route
   - No, LAN-only -> ask if the user wants a `.local` domain with mkcert TLS
   - Both -> do both

5. **Is it a full-stack app with separate frontend and backend?**
   - Yes -> Pattern B (frontend exposed, backend internal)
   - No -> Pattern A or D

6. **If public: subdomain preference?**
   - The convention is random 3-8 character alphanumeric slugs for security
   - Inform the user of this convention, but let them choose
   - Named subdomains (e.g., `app.domain.com`) are acceptable if the user prefers

## Network Strategy

All services use dedicated per-app Docker networks for complete isolation.
There is no shared network; every app gets its own `<service>_network`.

### Per-App Isolated Network

Each application receives its own dedicated network. Traefik bridges to it
without exposing the app's services to each other.

```
cloudflared → Traefik ─── myapp_network (myapp-frontend + myapp-backend + myapp-db)
                      └── otherapp_network (otherapp + otherapp-db)
```

**Rules for all apps:**
- Create a dedicated `<service>_network` in the service's `docker-compose.yml`
- The app and its database container(s) join only `<service>_network`
- Traefik must be added to the new network so it can proxy to the service
  (add the network entry to `~/.dotfiles/docker/traefik/docker-compose.yml`)
- Each app has its own dedicated PostgreSQL and/or Redis - no sharing
- If the app is compromised, the attacker cannot reach any other service

See [patterns.md](references/patterns.md) for the complete templates.

## Deployment Patterns

### Pattern A: Off-the-shelf Docker Image

For pre-built images from Docker Hub / GHCR. Examples: vaultwarden, uptimekuma.

**Files to create:**
- `~/.dotfiles/docker/<service>/docker-compose.yml` (includes dedicated database)
- `~/.dotfiles/docker/<service>/.env.example`

**Routing:** Docker labels in `docker-compose.yml`.

### Pattern B: Full-Stack Custom App (Isolated)

For user-built apps with frontend, backend API, and database.
Only the frontend is exposed publicly via Traefik labels. The backend has
zero Traefik labels and is only accessible internally via Docker DNS.

**Files to create:**
- `~/.dotfiles/docker/<service>/docker-compose.yml` (frontend + backend + database)
- `~/.dotfiles/docker/<service>/.env.example`

**Routing:** Docker labels for the frontend only. Backend is internal-only.

**Architecture:**
- Frontend: Exposed via Traefik (public subdomain)
- Backend: Internal only (no Traefik labels, accessible only via Docker network)
- Database: Internal only (accessible only by backend)

### Pattern D: Custom Single-Service App

For user-built apps that are a single service (not full-stack).

**Files to create:**
- `~/.dotfiles/docker/<service>/docker-compose.yml` (includes dedicated database)
- `~/.dotfiles/docker/<service>/.env.example`

**Routing:** Docker labels in `docker-compose.yml`.

## Step-by-Step Workflow

Follow these steps in order. See [patterns.md](references/patterns.md) for
concrete file templates.

### Step 1: Create the Service Directory

```bash
mkdir -p ~/.dotfiles/docker/<service>
```

### Step 2: Create docker-compose.yml

Use the appropriate template from [patterns.md](references/patterns.md).

Key rules:
- Create dedicated `<service>_network` (not external, defined in file)
- Include dedicated database(s) in the same compose file
- For Pattern B: only frontend gets Traefik labels; backend has none
- Set `restart: unless-stopped`
- Set `container_name` for easy identification
- Use `${VAR}` syntax for environment variables (sourced from `.env` by `up.sh`)

### Step 3: Create .env.example

Document every expected variable with placeholder values and comments.
Variable names MUST be globally unique across all services because `up.sh`
sources all `.env` files into a flat namespace. Prefix with service name when
in doubt (e.g., `MYAPP_HOSTNAME`, `MYAPP_DB_PASSWORD`).

Tell the user to:
```bash
cp ~/.dotfiles/docker/<service>/.env.example ~/.dotfiles/docker/<service>/.env
```
Then fill in real values. `.env` files are gitignored automatically.

### Step 4: Configure Traefik Network Bridge

Edit `~/.dotfiles/docker/traefik/docker-compose.yml`:

```yaml
networks:
  traefik_network:
    external: true
  <service>_network:
    external: true

services:
  traefik:
    # ... existing config ...
    networks:
      - traefik_network
      - <service>_network
```

Restart Traefik to pick up the new network:
```bash
cd ~/.dotfiles/docker
./up.sh restart traefik
```

### Step 5: Configure Public Access (if applicable)

#### Add ingress rule to cloudflared/config.yml

Add before the catch-all `- service: http_status:404` line:

```yaml
  - hostname: <subdomain>.<domain>
    service: https://traefik:443
    originRequest:
      noTLSVerify: true
```

`noTLSVerify: true` is required because Traefik uses self-signed local certs.

#### Create DNS route

```bash
cd ~/.dotfiles/docker/cloudflared
TUNNEL_UUID=$(grep CF_TUNNEL_ID .env | cut -d= -f2)
docker run --rm \
  -v $(pwd):/home/nonroot/.cloudflared \
  cloudflare/cloudflared:latest \
  tunnel route dns $TUNNEL_UUID <subdomain>.<domain>
```

#### Restart cloudflared to pick up config changes

```bash
cd ~/.dotfiles/docker
./up.sh restart cloudflared
```

### Step 6: Configure Local Access (if applicable)

If the user wants a `.local` domain for LAN access:

#### Generate mkcert certificates

```bash
mkcert -cert-file ~/.dotfiles/docker/traefik/certs/<service>.local.pem \
       -key-file ~/.dotfiles/docker/traefik/certs/<service>.local-key.pem \
       <service>.local
```

#### Add to tls.yml

Append to `~/.dotfiles/docker/traefik/certs/tls.yml`:

```yaml
    - certFile: /etc/traefik/dynamic/<service>.local.pem
      keyFile: /etc/traefik/dynamic/<service>.local-key.pem
```

#### Add DNS entry on the LAN

The user must add `<NAS_IP> <service>.local` to their client's `/etc/hosts`
or configure it in their local DNS server.

#### Docker labels for local routing

Add to the service's `docker-compose.yml` labels (in addition to public router):

```yaml
      - traefik.http.routers.<service>-local.rule=Host(`<service>.local`)
      - traefik.http.routers.<service>-local.entrypoints=websecure
      - traefik.http.routers.<service>-local.tls=true
      - traefik.http.routers.<service>-local.service=<service>-svc
```

### Step 7: Set Up Database

Every application includes its own database(s) in its docker-compose.yml.
No shared database infrastructure exists.

For PostgreSQL:
```yaml
  <service>-db:
    image: postgres:16-alpine
    container_name: <service>-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=<service>
      - POSTGRES_PASSWORD=${<SERVICE>_DB_PASSWORD}
      - POSTGRES_DB=<service>
    volumes:
      - <service>_db_data:/var/lib/postgresql/data
    networks:
      - <service>_network
```

Connection string from app:
```
postgresql://<service>:${<SERVICE>_DB_PASSWORD}@<service>-db:5432/<service>
```

For Redis (optional):
```yaml
  <service>-redis:
    image: redis:7-alpine
    container_name: <service>-redis
    restart: unless-stopped
    command: redis-server --requirepass ${<SERVICE>_REDIS_PASSWORD}
    volumes:
      - <service>_redis_data:/data
    networks:
      - <service>_network
```

### Step 8: Register in Root Compose File

Add to `~/.dotfiles/docker/docker-compose.yml`:

```yaml
include:
  # ... existing entries ...
  - path: <service>/docker-compose.yml
```

### Step 9: Start and Verify

```bash
cd ~/.dotfiles/docker
./up.sh up -d
```

Verify:
```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep <service>
```

If public, test the URL:
```bash
curl -s -w "%{http_code}" -o /dev/null https://<subdomain>.<domain>
```

For Pattern B apps, verify backend is NOT accessible externally:
```bash
# Should fail/timeout - backend has no Traefik route
curl http://<NAS_IP>:<backend_port>
```

## Labels Conventions

### Pattern A & D (Single Service)

Full Traefik label set:
```yaml
      - traefik.enable=true
      - traefik.docker.network=<service>_network
      - traefik.http.routers.<service>.rule=Host(`${<SERVICE>_HOSTNAME}`)
      - traefik.http.routers.<service>.entrypoints=websecure
      - traefik.http.routers.<service>.tls=true
      - traefik.http.services.<service>-svc.loadbalancer.server.port=<INTERNAL_PORT>
```

### Pattern B (Full-Stack)

**Frontend** (exposed):
```yaml
      - traefik.enable=true
      - traefik.docker.network=<service>_network
      - traefik.http.routers.<service>.rule=Host(`${<SERVICE>_HOSTNAME}`)
      - traefik.http.routers.<service>.entrypoints=websecure
      - traefik.http.routers.<service>.tls=true
      - traefik.http.services.<service>-svc.loadbalancer.server.port=<FRONTEND_PORT>
```

**Backend** (internal, NO Traefik labels):
```yaml
    # No labels - backend is internal only
```

The backend is accessible only via Docker internal DNS:
- From frontend: `http://<service>-backend:<BACKEND_PORT>`
- From backend to database: `http://<service>-db:5432`

## Security Conventions

1. **Random subdomain slugs**: Public subdomains should use non-obvious random
   slugs (3-8 alphanumeric chars) instead of descriptive names. This reduces
   discoverability. Inform the user of this convention and let them choose.

2. **Never generate secrets**: Always ask the user to run
   `openssl rand -base64 32` and provide the output. Never invent passwords.

3. **Unique variable names**: All `.env` variable names must be unique across
   the entire stack. Use service-name prefixes.

4. **Gitignored by default**: `.env` files, `**/data/` directories, and
   `*-key.pem` files are all gitignored. `.env.example` files are committed.

5. **No inbound ports on router**: All public access goes through the
   Cloudflare tunnel. Never instruct the user to open ports on their router.

6. **Internal backend exposure (Pattern B)**: Backend containers must have
   zero Traefik labels. They are only reachable via the isolated Docker network.

7. **Per-app databases**: Every application includes its own PostgreSQL and/or
   Redis. There are no shared database instances.

## File Locations Quick Reference

| File | Purpose |
|------|---------|
| `~/.dotfiles/docker/<service>/docker-compose.yml` | Service definition (includes database) |
| `~/.dotfiles/docker/<service>/.env.example` | Variable documentation |
| `~/.dotfiles/docker/<service>/.env` | Actual secrets (gitignored) |
| `~/.dotfiles/docker/traefik/certs/tls.yml` | TLS cert registry for local domains |
| `~/.dotfiles/docker/traefik/certs/<service>.local.pem` | mkcert TLS cert |
| `~/.dotfiles/docker/cloudflared/config.yml` | Tunnel ingress rules (gitignored) |
| `~/.dotfiles/docker/docker-compose.yml` | Root compose with `include:` list |

## Detailed Templates

See [patterns.md](references/patterns.md) for ready-to-use file templates
for every pattern and component.

Base directory for this skill: file:///home/petebarbosa/.config/opencode/skills/nas-app-deployment
Relative paths in this skill (e.g., scripts/, reference/) are relative to this base directory.
Note: file list is sampled.
