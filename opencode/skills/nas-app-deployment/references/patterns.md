# Deployment Pattern Templates

Concrete file templates for each deployment pattern. Replace all `<placeholders>`
with actual values.

---

## Pattern A: Off-the-shelf Docker Image

For pre-built images from Docker Hub / GHCR. Examples: vaultwarden, uptimekuma.

### docker-compose.yml

```yaml
services:
  <service>:
    image: <vendor>/<image>:latest
    container_name: <service>
    restart: unless-stopped
    environment:
      - <SERVICE_VAR>=${<SERVICE_VAR>}
    volumes:
      - ./data:/app/data
    labels:
      - traefik.enable=true
      - traefik.http.routers.<service>.rule=Host(`${<SERVICE>_HOSTNAME}`)
      - traefik.http.routers.<service>.entrypoints=websecure
      - traefik.http.routers.<service>.tls=true
      - traefik.http.services.<service>-svc.loadbalancer.server.port=<INTERNAL_PORT>
    networks:
      - <service>_network

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

networks:
  <service>_network:
    name: <service>_network

volumes:
  <service>_db_data:
```

### .env.example

```bash
# <SERVICE>_HOSTNAME: Public hostname for Traefik routing.
# Add a matching ingress rule in cloudflared/config.yml.
# Convention: use a random 3-8 char slug for security (e.g., x7k9.yourdomain.com)
<SERVICE>_HOSTNAME=<service>.yourdomain.com

# <SERVICE>_DB_PASSWORD: PostgreSQL password for the dedicated database.
# Generate with: openssl rand -base64 32
<SERVICE>_DB_PASSWORD=change_me

# <SERVICE_VAR>: Description of what this variable does.
<SERVICE_VAR>=change_me
```

### Traefik Network Bridge

Edit `~/.dotfiles/docker/traefik/docker-compose.yml` and add the new network:

```yaml
networks:
  traefik_network:
    external: true
  <service>_network:
    external: true
```

And add it to the Traefik service's networks list:

```yaml
services:
  traefik:
    # ... existing config ...
    networks:
      - traefik_network
      - <service>_network
```

---

## Pattern B: Full-Stack Custom App (Isolated)

For custom-built applications with frontend, backend API, and database. Only the
frontend is exposed publicly; backend and database are internal-only.

**Architecture:**
```
Internet → Cloudflare → Cloudflared → Traefik → Frontend (exposed)
                                                  │
                                                  └─→ <service>_network (isolated)
                                                      ├── Backend (internal, no Traefik labels)
                                                      └── Database (PostgreSQL)
```

### docker-compose.yml

```yaml
services:
  <service>-frontend:
    image: dotfiles-<service>-frontend:latest
    container_name: <service>-frontend
    restart: unless-stopped
    environment:
      - API_URL=http://<service>-backend:<BACKEND_PORT>
      - <SERVICE_VAR>=${<SERVICE_VAR>}
    labels:
      - traefik.enable=true
      - traefik.docker.network=<service>_network
      - traefik.http.routers.<service>.rule=Host(`${<SERVICE>_HOSTNAME}`)
      - traefik.http.routers.<service>.entrypoints=websecure
      - traefik.http.routers.<service>.tls=true
      - traefik.http.services.<service>-svc.loadbalancer.server.port=<FRONTEND_PORT>
    networks:
      - <service>_network

  <service>-backend:
    image: dotfiles-<service>-backend:latest
    container_name: <service>-backend
    restart: unless-stopped
    environment:
      - DATABASE_URL=postgresql://<service>:${<SERVICE>_DB_PASSWORD}@<service>-db:5432/<service>
      - <SERVICE_BACKEND_VAR>=${<SERVICE_BACKEND_VAR>}
    # No traefik labels - backend is internal only
    networks:
      - <service>_network

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

networks:
  <service>_network:
    name: <service>_network

volumes:
  <service>_db_data:
```

**Key points:**
- Frontend joins `<service>_network` and has Traefik labels for public access
- Backend has **zero Traefik labels** - completely unreachable from outside
- Backend connects to database via internal Docker DNS (`<service>-db:5432`)
- Frontend connects to backend via internal Docker DNS (`http://<service>-backend:<port>`)
- `traefik.docker.network=<service>_network` label tells Traefik which network to use

### .env.example

```bash
# <SERVICE>_HOSTNAME: Public hostname for the frontend.
# Only the frontend is exposed; backend remains internal.
# Convention: use a random 3-8 char slug for security (e.g., x7k9.yourdomain.com)
<SERVICE>_HOSTNAME=<service>.yourdomain.com

# <SERVICE>_DB_PASSWORD: PostgreSQL password for the dedicated database.
# Generate with: openssl rand -base64 32
<SERVICE>_DB_PASSWORD=change_me

# <SERVICE_VAR>: Frontend-specific variable.
<SERVICE_VAR>=change_me

# <SERVICE_BACKEND_VAR>: Backend-specific variable.
<SERVICE_BACKEND_VAR>=change_me
```

### Traefik Network Bridge

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

Restart Traefik:
```bash
cd ~/.dotfiles/docker
./up.sh restart traefik
```

### Cloudflared Ingress

Add to `~/.dotfiles/docker/cloudflared/config.yml`:

```yaml
  - hostname: <subdomain>.<domain>
    service: https://traefik:443
    originRequest:
      noTLSVerify: true
```

Create DNS route:
```bash
cd ~/.dotfiles/docker/cloudflared
TUNNEL_UUID=$(grep CF_TUNNEL_ID .env | cut -d= -f2)
docker run --rm \
  -v $(pwd):/home/nonroot/.cloudflared \
  cloudflare/cloudflared:latest \
  tunnel route dns $TUNNEL_UUID <subdomain>.<domain>
```

---

## Pattern D: Public Multi-Service App (Full Isolation)

For public-facing applications with external users. Complete network isolation
with dedicated database per service.

### docker-compose.yml

```yaml
services:
  <service>:
    image: dotfiles-<service>:latest
    container_name: <service>
    restart: unless-stopped
    environment:
      - DATABASE_URL=postgresql://<service>:${<SERVICE>_DB_PASSWORD}@<service>-db:5432/<service>
      - <SERVICE_VAR>=${<SERVICE_VAR>}
    labels:
      - traefik.enable=true
      - traefik.docker.network=<service>_network
      - traefik.http.routers.<service>.rule=Host(`${<SERVICE>_HOSTNAME}`)
      - traefik.http.routers.<service>.entrypoints=websecure
      - traefik.http.routers.<service>.tls=true
      - traefik.http.services.<service>-svc.loadbalancer.server.port=<INTERNAL_PORT>
    networks:
      - <service>_network

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

networks:
  <service>_network:
    name: <service>_network

volumes:
  <service>_db_data:
```

### .env.example

```bash
# <SERVICE>_HOSTNAME: Public hostname for Traefik routing.
# Convention: use a random 3-8 char slug for security (e.g., x7k9.yourdomain.com)
<SERVICE>_HOSTNAME=<service>.yourdomain.com

# <SERVICE>_DB_PASSWORD: PostgreSQL password for the dedicated database.
# Generate: openssl rand -base64 32
<SERVICE>_DB_PASSWORD=change_me

# <SERVICE_VAR>: Description of what this variable does.
<SERVICE_VAR>=change_me
```

### Traefik Network Bridge

Edit `~/.dotfiles/docker/traefik/docker-compose.yml`:

```yaml
networks:
  traefik_network:
    external: true
  <service>_network:
    external: true

services:
  traefik:
    networks:
      - traefik_network
      - <service>_network
```

Restart Traefik:
```bash
cd ~/.dotfiles/docker
./up.sh restart traefik
```

---

## Cloudflare Tunnel Ingress Rule

Add this block to `~/.dotfiles/docker/cloudflared/config.yml`, before the
catch-all `- service: http_status:404` line:

```yaml
  - hostname: <subdomain>.<domain>
    service: https://traefik:443
    originRequest:
      noTLSVerify: true
```

Every public service gets its own hostname entry. All point to Traefik.
`noTLSVerify: true` is required because Traefik uses self-signed/mkcert
certificates internally.

### Creating the DNS Route

```bash
cd ~/.dotfiles/docker/cloudflared
TUNNEL_UUID=$(grep CF_TUNNEL_ID .env | cut -d= -f2)
docker run --rm \
  -v $(pwd):/home/nonroot/.cloudflared \
  cloudflare/cloudflared:latest \
  tunnel route dns $TUNNEL_UUID <subdomain>.<domain>
```

Expected output: `Added CNAME <subdomain>.<domain> which will route to this tunnel`

---

## Local Access with mkcert TLS

For LAN-only `.local` domain access with trusted TLS certificates.

### Generate certificates

```bash
# Install mkcert if not already: https://github.com/FiloSottile/mkcert
# Run once per machine: mkcert -install

mkcert -cert-file ~/.dotfiles/docker/traefik/certs/<service>.local.pem \
       -key-file ~/.dotfiles/docker/traefik/certs/<service>.local-key.pem \
       <service>.local
```

The `.pem` certificate files can be committed to git. The `*-key.pem` private
key files are gitignored automatically.

### Register in tls.yml

Append to `~/.dotfiles/docker/traefik/certs/tls.yml` under the
`tls.certificates` list:

```yaml
    - certFile: /etc/traefik/dynamic/<service>.local.pem
      keyFile: /etc/traefik/dynamic/<service>.local-key.pem
```

### Client-side DNS

The user must resolve `<service>.local` to the NAS IP on each client:

- `/etc/hosts` entry: `<NAS_IP>  <service>.local`
- Or configure in local DNS server (Pi-hole, Unbound, etc.)

### Docker labels for local routing

Add to the service's `docker-compose.yml` labels:

```yaml
      - traefik.http.routers.<service>-local.rule=Host(`<service>.local`)
      - traefik.http.routers.<service>-local.entrypoints=websecure
      - traefik.http.routers.<service>-local.tls=true
      - traefik.http.routers.<service>-local.service=<service>-svc
```

This creates a second router for the `.local` domain pointing to the same
backend service.

---

## Service Needing Redis

Add a Redis service to the docker-compose.yml:

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

volumes:
  <service>_db_data:
  <service>_redis_data:
```

Add to .env.example:

```bash
# <SERVICE>_REDIS_PASSWORD: Redis password.
# Generate: openssl rand -base64 32
<SERVICE>_REDIS_PASSWORD=change_me
```

Connect from application:
```
redis://:${<SERVICE>_REDIS_PASSWORD}@<service>-redis:6379/0
```

---

## Complete Example: Adding Pattern B Full-Stack App

Deploying a custom app with React frontend + Node backend + PostgreSQL.

### 1. Create directory and files

```bash
mkdir -p ~/.dotfiles/docker/myapp
```

`docker-compose.yml`:
```yaml
services:
  myapp-frontend:
    image: dotfiles-myapp-frontend:latest
    container_name: myapp-frontend
    restart: unless-stopped
    environment:
      - API_URL=http://myapp-backend:3000
    labels:
      - traefik.enable=true
      - traefik.docker.network=myapp_network
      - traefik.http.routers.myapp.rule=Host(`${MYAPP_HOSTNAME}`)
      - traefik.http.routers.myapp.entrypoints=websecure
      - traefik.http.routers.myapp.tls=true
      - traefik.http.services.myapp-svc.loadbalancer.server.port=80
    networks:
      - myapp_network

  myapp-backend:
    image: dotfiles-myapp-backend:latest
    container_name: myapp-backend
    restart: unless-stopped
    environment:
      - DATABASE_URL=postgresql://myapp:${MYAPP_DB_PASSWORD}@myapp-db:5432/myapp
      - NODE_ENV=production
    networks:
      - myapp_network

  myapp-db:
    image: postgres:16-alpine
    container_name: myapp-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=myapp
      - POSTGRES_PASSWORD=${MYAPP_DB_PASSWORD}
      - POSTGRES_DB=myapp
    volumes:
      - myapp_db_data:/var/lib/postgresql/data
    networks:
      - myapp_network

networks:
  myapp_network:
    name: myapp_network

volumes:
  myapp_db_data:
```

`.env.example`:
```bash
# MYAPP_HOSTNAME: Public hostname for the frontend only.
# Backend is internal and not accessible from outside.
MYAPP_HOSTNAME=myapp.yourdomain.com

# MYAPP_DB_PASSWORD: PostgreSQL password for the dedicated database.
# Generate: openssl rand -base64 32
MYAPP_DB_PASSWORD=change_me
```

### 2. Add Traefik network bridge

Edit `~/.dotfiles/docker/traefik/docker-compose.yml`:

```yaml
networks:
  traefik_network:
    external: true
  myapp_network:
    external: true

services:
  traefik:
    networks:
      - traefik_network
      - myapp_network
```

Restart Traefik:
```bash
cd ~/.dotfiles/docker
./up.sh restart traefik
```

### 3. Add to cloudflared/config.yml

```yaml
  - hostname: myapp.yourdomain.com
    service: https://traefik:443
    originRequest:
      noTLSVerify: true
```

### 4. Create DNS route

```bash
cd ~/.dotfiles/docker/cloudflared
TUNNEL_UUID=$(grep CF_TUNNEL_ID .env | cut -d= -f2)
docker run --rm \
  -v $(pwd):/home/nonroot/.cloudflared \
  cloudflare/cloudflared:latest \
  tunnel route dns $TUNNEL_UUID myapp.yourdomain.com
```

### 5. Register and start

Add to `~/.dotfiles/docker/docker-compose.yml`:
```yaml
include:
  - path: myapp/docker-compose.yml
```

```bash
cd ~/.dotfiles/docker
cp myapp/.env.example myapp/.env
# Edit myapp/.env with real values
./up.sh up -d
```

### 6. Verify

```bash
docker ps | grep myapp
curl -s -w "%{http_code}" -o /dev/null https://myapp.yourdomain.com
```

Backend is NOT accessible externally (no Traefik labels):
```bash
# This will fail/timeout - backend has no route
curl http://<NAS_IP>:3000
```

---

## Summary of Patterns

| Pattern | Use Case | Network | Database | Exposure |
|---------|----------|---------|----------|----------|
| **A** | Off-the-shelf images (Vaultwarden, etc.) | Per-app isolated | Included in compose | Public |
| **B** | Custom full-stack apps (frontend+backend+DB) | Per-app isolated | Included in compose | Frontend only |
| **D** | Public multi-user apps | Per-app isolated | Included in compose | Full app |

**All patterns include:**
- Dedicated database(s) in the compose file
- Isolated per-app network
- Traefik network bridge configuration
- Zero shared infrastructure
