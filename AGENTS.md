# Agent Guidelines for .dotfiles Repository
Source `./.agents/general.md`

## Build/Test Commands
- No traditional build/test (infrastructure repo: bash scripts + Docker configs)
- Run service: `cd docker && ./up.sh up -d <service-name>` | View logs: `./up.sh logs -f [service]`
- Run backup: `cd docker && ./backup.sh` | Validate YAML: `docker compose -f <file> config`
- Test pre-commit: `pre-commit run --all-files` (secrets + YAML validation)

## Code Style Guidelines
**Shell scripts**: `set -e` at top, use log/warn/error functions (color-coded), check exit codes, require .env file
**YAML**: 2-space indentation, env vars with `${VAR:-default}` syntax, service-specific docker-compose.yml per subdirectory
**Environment**: Never commit `.env` (use `.env.example`), don't expose ports 80/DB, HTTPS-only via Traefik
**Permissions**: Scripts executable (`chmod +x`), data dirs owned by user:group, no hardcoded secrets
**Security**: Gitleaks + detect-secrets pre-commit hooks, `.example` suffix for templates with sensitive data

## Repository Context
Infrastructure-as-code: Docker services (Vaultwarden, PostgreSQL, Uptime Kuma, Portainer) via Traefik reverse proxy + Cloudflare Tunnel. All services in `docker/*/docker-compose.yml`. User systemd services only (use `systemctl --user`). Security-first: no HTTP, no exposed DB ports, DNS-challenge SSL certificates.

## Planning Phase Rules
Never code during planning—only ask questions and analyze codebase. Follow existing patterns strictly. Write elegant, minimal, modular code. Always update documentation continuously.
Source `./.agents/planning_phase.md`

## Implementation Phase Rules
Source `./.agents/planning_phase.md`
