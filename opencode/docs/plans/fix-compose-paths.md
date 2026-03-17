---
plan name: fix-compose-paths
plan description: Compose include directive migration
plan status: done
---

## Idea
Fix the Docker Compose multi-file setup where all relative volume paths resolve to the cloudflared directory. The root cause is that `up.sh` passes multiple `-f` flags to a single `docker compose` command, which resolves all `./` paths relative to the first compose file's directory (cloudflared, alphabetically). The fix is to replace the multi `-f` approach with a root `docker-compose.yml` that uses the `include:` directive (Docker Compose v2.20+), which correctly resolves each included file's relative paths against its own directory. After restructuring, the misplaced data directories inside cloudflared must be moved back to their correct service directories, and any stale duplicates cleaned up.

## Implementation
- Create a root docker-compose.yml at ~/.dotfiles/docker/ that uses the `include:` directive to pull in each service's docker-compose.yml (cloudflared, traefik, homeassistant, postgres, uptimekuma, vaultwarden)
- Update up.sh to use the new root docker-compose.yml instead of dynamically collecting compose files with find and multiple -f flags — the compose command becomes simply `docker compose -f docker-compose.yml --project-name dotfiles $*`
- Stop all running containers via the current up.sh (up.sh down) so data directories can be safely moved
- Move misplaced data directories from cloudflared/ back to their correct service directories: cloudflared/vw-data -> vaultwarden/vw-data, cloudflared/data -> uptimekuma/data, cloudflared/config -> homeassistant/config, cloudflared/certs -> traefik/certs (verify each to avoid overwriting existing correct data)
- Bring services back up with the new root compose file (up.sh up -d) and verify each service's volumes resolve to the correct directories
- Update the .gitignore if needed to ensure the new root docker-compose.yml is tracked and data directories remain ignored

## Required Specs
<!-- SPECS_START -->
<!-- SPECS_END -->