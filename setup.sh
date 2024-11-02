#!/bin/bash

# Exit on any error
set -e

echo "Starting system setup..."

# Function to create a symlink with backup if target exists
create_symlink() {
  local source=$1
  local target=$2

  if [ -e "$target" ]; then
    echo "Backing up existing $target to ${target}.backup"
    mv "$target" "${target}.backup"
  fi

  echo "Creating symlink: $target -> $source"
  ln -sf "$(pwd)/$source" "$target"
}

# Function to create directory if it doesn't exist
create_directory() {
  local dir=$1
  if [ ! -d "$dir" ]; then
    echo "Creating directory: $dir"
    mkdir -p "$dir"
  fi
}

# 1. Create symlink for .bashrc
create_symlink ".bashrc" "$HOME/.bashrc"

# 2. Create symlink for .bashrc.env.example
create_symlink ".bashrc.env.example" "$HOME/.bashrc.env.example"

# 3. Rename .bashrc.env.example to .bashrc.env if it doesn't exist
if [ ! -f "$HOME/.bashrc.env" ]; then
  echo "Creating .bashrc.env from .bashrc.env.example"
  cp "$HOME/.bashrc.env.example" "$HOME/.bashrc.env"
fi

# 4. Create symlink for kanata.service
echo "Setting up kanata.service (requires sudo)"
sudo ln -sf "$(pwd)/kanata/kanata.service" "/etc/systemd/system/kanata.service"

# 5. Create kanata config directory
create_directory "$HOME/.config/kanata"

# 6. Create symlink for kanata.kbd
create_symlink "kanata/kanata.kbd" "$HOME/.config/kanata/kanata.kbd"

# 7. Enable and start kanata.service
echo "Enabling and starting kanata.service"
sudo systemctl daemon-reload
sudo systemctl enable kanata.service
sudo systemctl start kanata.service

# 8. Install xclip
echo "Installing xclip (requires sudo)"
sudo apt-get update
sudo apt-get install -y xclip

# 9. Create symlinks for nvim configuration
echo "Setting up neovim configuration"
create_directory "$HOME/.config/nvim"

# Find and symlink all files from nvim directory
find "$(pwd)/nvim" -type f -printf "%P\n" | while read -r file; do
  target_dir="$HOME/.config/nvim/$(dirname "$file")"
  create_directory "$target_dir"
  create_symlink "nvim/$file" "$target_dir/$(basename "$file")"
done

echo "Setup completed successfully!"
