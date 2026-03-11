# Dotfiles Setup Guide for AI Assistants

## Overview

This repository contains personal dotfiles for:
- Self-hosted NAS services (Traefik, PostgreSQL, Home Assistant, etc.)
- OpenCode AI agent configurations with custom tools and skills
- Keyboard remapping configurations for Hyprland

## Setup Workflow

When a user asks to "set up my dotfiles", follow this structured workflow:

### 1. System Assessment

Ask the user which system they're on:
- **Ubuntu/Omakub** - Standard setup
- **Arch/Hyprland** - Includes keyboard composition options
- **Other** - Proceed with compatible components only

### 2. Component Selection

Present the following categories and let the user select which components to install:

#### Infrastructure Components
```
☐ Traefik          - Reverse proxy with automatic TLS
☐ PostgreSQL       - Shared database (Docker network only, no host port)
☐ Cloudflared      - Secure Cloudflare tunnel (outbound-only, no open ports)
```

#### Application Components
```
☐ Vaultwarden      - Bitwarden-compatible password manager
☐ Home Assistant   - Home automation platform
☐ Uptime Kuma      - Service uptime monitoring
```

#### Development Components
```
☐ OpenCode Config  - Symlink ~/.config/opencode to opencode/ directory
☐ gitingest Tool   - Repository analysis tool for AI context
```

#### System Components (Arch/Hyprland only)
```
☐ Keyboard Remap   - Caps Lock as Escape/Arrow keys via keyd
```

### 3. Prerequisites Check

For each selected component, verify and install prerequisites:

| Component | Prerequisites |
|-----------|--------------|
| Docker services | Docker, Docker Compose |
| gitingest | pipx or pip |
| Keyboard remapping | keyd, hyprland |
| OpenCode config | OpenCode CLI installed |

### 4. Installation Steps

#### Docker Services

1. Navigate to `docker/` directory
2. For each selected service:
   - Copy `.env.example` to `.env` and prompt user for values
   - Note: Services are interdependent (Traefik is required for others)
3. Run `./up.sh up -d` to start services
4. Run `./up.sh logs -f` to verify startup

**Important Notes:**
- PostgreSQL has no host port exposed (Docker network only)
- Cloudflared requires `config.yml` (see `config.yml.example`)

#### OpenCode Configuration

1. Check if OpenCode CLI is installed
2. Ask user if they want to symlink `~/.config/opencode` to `opencode/`
3. If yes, backup existing config first
4. Create symlink: `ln -s /path/to/dotfiles/opencode ~/.config/opencode`

#### gitingest Tool

1. Install gitingest: `pipx install gitingest` (or `pip install gitingest`)
2. Configure in OpenCode via `opencode.json` plugins

#### Keyboard Remapping (keyd)

1. Install keyd: `sudo pacman -S keyd` (Arch) or compile from source
2. Copy configuration from `keyboard-compositions.md`
3. Enable service: `sudo systemctl enable --now keyd`

### 5. Post-Installation Verification

**Docker Stack:**
- Verify all containers are running: `docker ps`
- Check Traefik dashboard: http://traefik.local (from LAN)
- Test service access via Cloudflare tunnel (if configured)

**Keyboard:**
- Test Caps Lock functionality
- Verify Escape key works in applications

### 6. Common Issues

**Docker services won't start:**
- Check if `.env` files exist in each service directory
- Verify `traefik_network` was created: `docker network ls`
- Check logs: `./up.sh logs [service]`

**Cloudflared connection fails:**
- Verify `config.yml` is properly formatted
- Check Cloudflare tunnel token is valid
- Ensure `cloudflared_network` has proper labels for Traefik discovery

**PostgreSQL connection issues:**
- Remember: No host port exposed, access only via Docker network
- Applications must be on `traefik_network` to reach PostgreSQL

**keyd not working:**
- Verify keyd service is running: `sudo systemctl status keyd`
- Check config syntax: `sudo keyd -m` for debug mode
- May need to logout/login for changes to take effect

### 7. Next Steps

After successful setup:

1. **Docker stack:** Review `docker/docker-llm-confiugration.md` for:
   - Architecture overview
   - Security considerations
   - Backup strategies

2. **OpenCode:** Explore available:
   - Custom commands in `opencode/command/`
   - Skills in `opencode/skill/`
   - Subagents in `opencode/agent/subagents/`

3. **Documentation:** Bookmark these resources:
   - `keyboard-compositions.md` - Keyboard customization guide

## Architecture Notes

### Docker Stack
```
Internet → Cloudflare Edge → Cloudflared (tunnel) → Traefik → Services
                                      ↓
                              SSH → Host SSH server (port 22)

LAN users → Direct access to Traefik (no tunnel needed)
```

**Security Features:**
- Outbound-only tunnel (no open ports)
- Identity-based SSH access via Cloudflare Access
- PostgreSQL isolated to Docker network
- Traefik dashboard restricted to LAN

## Emergency Procedures

**Reset Docker stack:**
```bash
cd docker
./up.sh down
# Remove volumes if needed: docker volume rm [volume_name]
./up.sh up -d
```

**Rollback OpenCode config:**
```bash
# Remove symlink
rm ~/.config/opencode
# Restore backup
mv ~/.config/opencode.backup ~/.config/opencode
```

**Disable keyd:**
```bash
sudo systemctl stop keyd
sudo systemctl disable keyd
```
