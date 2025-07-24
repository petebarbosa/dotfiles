#!/bin/bash

set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

echo "This script requires sudo. Your password may be required."
sudo -v

create_symlink() {
  local source_path="$1"
  local target_path="$2"

  mkdir -p "$(dirname "$target_path")"

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    echo "Backing up existing '$target_path' to '${target_path}.backup'"
    mv "$target_path" "${target_path}.backup"
  fi

  echo "Creating symlink: $target_path -> $source_path"
  ln -s "$source_path" "$target_path"
}

install_dependencies() {
  echo "Installing dependencies..."
  sudo apt-get update
  sudo apt-get install -y xclip
}

setup_bash() {
  echo "Setting up bash..."
  create_symlink "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
  create_symlink "$SCRIPT_DIR/.bashrc.env.example" "$HOME/.bashrc.env.example"
  if [ ! -f "$HOME/.bashrc.env" ]; then
    echo "Creating .bashrc.env from example"
    cp "$HOME/.bashrc.env.example" "$HOME/.bashrc.env"
  fi
}

setup_kanata() {
  echo "Setting up Kanata..."
  create_symlink "$SCRIPT_DIR/kanata/kanata.kbd" "$HOME/.config/kanata/kanata.kbd"
  sudo ln -sf "$SCRIPT_DIR/kanata/kanata.service" "/etc/systemd/system/kanata.service"
  echo "Enabling and starting Kanata service..."
  sudo systemctl daemon-reload
  sudo systemctl enable --now kanata.service
}

setup_docker() {
  echo "Setting up Docker auto-start service..."
  sudo ln -sf "$SCRIPT_DIR/docker/docker-compose-apps.service" "/etc/systemd/system/docker-compose-apps.service"
  echo "Enabling Docker Compose service..."
  sudo systemctl daemon-reload
  sudo systemctl enable --now docker-compose-apps.service
}

setup_nvim() {
  echo "Setting up Neovim..."
  find "$SCRIPT_DIR/nvim" -type f -printf "%P\n" | while read -r file; do
    target_file="$HOME/.config/nvim/$file"
    create_symlink "$SCRIPT_DIR/nvim/$file" "$target_file"
  done
}

main() {
  echo "Starting system setup..."

  install_dependencies
  setup_bash
  setup_kanata
  setup_docker
  setup_nvim

  echo "✅ Setup completed successfully!"
}

main
