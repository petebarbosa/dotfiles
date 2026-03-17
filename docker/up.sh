#!/bin/bash
set -euo pipefail

NETWORK_NAME="traefik_network"
PROJECT_NAME="dotfiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MISSING_ENV=0
MISSING_CONFIGS=()

# ── Network ───────────────────────────────────────────────────────────────────

if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
  echo "Network '${NETWORK_NAME}' not found. Creating it now..."
  docker network create "${NETWORK_NAME}"
else
  echo "Network '${NETWORK_NAME}' already exists."
fi

# ── Environment variables ─────────────────────────────────────────────────────
# Load all .env files. Variable names must be globally unique across services.
# See each service's .env.example for the list of expected variables.

for env_file in $(find "${SCRIPT_DIR}" -mindepth 2 -name '.env' | sort); do
  echo "Loading environment variables from ${env_file}"
  set -a
  # shellcheck source=/dev/null
  source "${env_file}"
  set +a
done

# ── Pre-flight checks ─────────────────────────────────────────────────────────
# Warn if any service's .env is missing (copied from .env.example).

for example_file in $(find "${SCRIPT_DIR}" -mindepth 2 -name '.env.example' | sort); do
  env_file="${example_file%.example}"
  if [[ ! -f "${env_file}" ]]; then
    echo "WARNING: Missing .env file for $(dirname "${example_file}" | xargs basename)"
    echo "         Expected: ${env_file}"
    echo "         Copy and fill in: cp ${example_file} ${env_file}"
    MISSING_ENV=1
  fi
done

# Warn if cloudflared config.yml is missing (required for tunnel to start).
CF_CONFIG="${SCRIPT_DIR}/cloudflared/config.yml"
if [[ ! -f "${CF_CONFIG}" ]]; then
  echo "WARNING: Missing cloudflared/config.yml (tunnel will not start)"
  echo "         Copy and fill in: cp ${SCRIPT_DIR}/cloudflared/config.yml.example ${CF_CONFIG}"
  MISSING_CONFIGS+=("cloudflared/config.yml")
fi

if [[ ${MISSING_ENV} -eq 1 ]] || [[ ${#MISSING_CONFIGS[@]} -gt 0 ]]; then
  echo ""
  echo "One or more configuration files are missing. Services may fail to start."
  echo "See AGENT.md for setup instructions."
  echo ""
fi

# ── Compose command ───────────────────────────────────────────────────────────
# Uses the root docker-compose.yml with `include:` directives so each service
# resolves relative paths (volumes, env_file, etc.) against its own directory.

COMMAND="docker compose --project-name ${PROJECT_NAME} -f ${SCRIPT_DIR}/docker-compose.yml $*"

echo "Running: ${COMMAND}"
eval "${COMMAND}"
