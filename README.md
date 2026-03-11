# dotfiles

Personal dotfiles for development environment and self-hosted services.
Compatible with Ubuntu/Omakub and Arch/Hyprland setups.

## Contents

### Infrastructure (docker/)
- **Traefik** - Reverse proxy with automatic TLS
- **PostgreSQL** - Shared database (Docker network only)
- **Cloudflared** - Secure Cloudflare tunnel (no open ports)

### Applications (docker/)
- **Vaultwarden** - Bitwarden-compatible password manager
- **Home Assistant** - Home automation platform
- **Uptime Kuma** - Service uptime monitoring

### Development (opencode/)
- **OpenCode Configuration** - AI agent configs, custom commands, skills, and tools

### System
- **Keyboard Compositions** - Caps Lock remapping guide for Hyprland/keyd

## Installation

### With an AI Assistant (Recommended)

Open this repository with an AI coding assistant (e.g., OpenCode, Claude) and ask:

> Set up my dotfiles

The assistant will use `AGENTS.md` to guide you through selecting which components to install.

### Manual Installation

See the documentation for each component:
- [Docker Stack Setup](docker/AGENTS.md)
- [OpenCode Tools](opencode/tools/README.md)
- [Keyboard Compositions](keyboard-compositions.md)

## Documentation

- `docker/AGENTS.md` - Complete NAS stack architecture and setup guide
- `docker/docs/specs/` - Technical specifications
- `opencode/tools/README.md` - Custom OpenCode tools documentation
- `keyboard-compositions.md` - Keyboard remapping guide

## License

MIT License - Copyright 2024 Pedro Barbosa
