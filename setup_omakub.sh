#!/bin/bash

set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

## Helper Functions

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

update_file_placeholder() {
  local file_path="$1"
  local placeholder="YOUR_USER_NAME"
  local current_user
  current_user=$(whoami)

  if [[ -f "$file_path" ]]; then
    sed -i "s#$placeholder#$current_user#g" "$file_path"
  fi
}

## Setup Functions

setup_bash() {
  echo "Setting up bash..."
  create_symlink "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
  create_symlink "$SCRIPT_DIR/.bashrc.env.example" "$HOME/.bashrc.env.example"
  if [ ! -f "$HOME/.bashrc.env" ]; then
    echo "Creating .bashrc.env from example"
    cp "$HOME/.bashrc.env.example" "$HOME/.bashrc.env"
  fi
}

setup_docker() {
  echo "Setting up Docker auto-start service..."
  local service_file="$SCRIPT_DIR/docker/docker-compose-apps.service"

  echo "--> Updating user placeholder in Docker service file..."
  update_file_placeholder "$service_file"

  sudo ln -sf "$service_file" "/etc/systemd/system/docker-compose-apps.service"
  echo "Enabling Docker Compose service..."
  sudo systemctl daemon-reload
  sudo systemctl enable --now docker-compose-apps.service
}

install_dependencies() {
  echo "Installing dependencies..."
  sudo apt-get update
  sudo apt-get install -y xclip
}

setup_nvim() {
  echo "Setting up Neovim..."
  find "$SCRIPT_DIR/nvim" -type f -printf "%P\n" | while read -r file; do
    target_file="$HOME/.config/nvim/$file"
    create_symlink "$SCRIPT_DIR/nvim/$file" "$target_file"
  done
}

## Main Execution Flow

main() {
  local options=("setup_bash" "setup_docker" "setup_nvim")
  local descriptions=("Bash" "Docker Service" "Neovim")
  local selected=("true" "true" "true")

  while true; do
    clear
    echo "-------------------------------------"
    echo "  System Setup Selector"
    echo "-------------------------------------"
    echo "Select which steps to run. Dependencies will always be installed."
    echo ""
    for i in "${!options[@]}"; do
      if [[ "${selected[$i]}" == "true" ]]; then
        echo "  $((i + 1))) [x] ${descriptions[$i]}"
      else
        echo "  $((i + 1))) [ ] ${descriptions[$i]}"
      fi
    done
    echo ""
    echo "Enter a number to toggle, (a)ll, (n)one, or (d)one to continue."
    read -rp "Choice: " choice

    case "$choice" in
    [1-4])
      local index=$((choice - 1))
      if [[ "${selected[$index]}" == "true" ]]; then
        selected[$index]="false"
      else
        selected[$index]="true"
      fi
      ;;
    a | A) for i in "${!options[@]}"; do selected[$i]="true"; done ;;
    n | N) for i in "${!options[@]}"; do selected[$i]="false"; done ;;
    d | D | "") break ;;
    *) echo "Invalid input. Please try again." && sleep 1 ;;
    esac
  done

  echo "Starting system setup..."
  sudo -v

  install_dependencies

  for i in "${!options[@]}"; do
    if [[ "${selected[$i]}" == "true" ]]; then
      ${options[$i]}
    fi
  done

  echo "✅ Setup completed successfully!"
}

main
