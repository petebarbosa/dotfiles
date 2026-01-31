#!/usr/bin/env bash
# Install gitingest for OpenCode gitingest tool

set -e

echo "Installing gitingest for OpenCode custom tool..."
echo ""

# Check if pipx is available (recommended)
if command -v pipx &> /dev/null; then
    echo "✓ Found pipx - using isolated installation"
    pipx install gitingest
elif command -v pip &> /dev/null; then
    echo "⚠ pipx not found - using pip (may conflict with other packages)"
    echo "  Consider installing pipx: https://pipx.pypa.io/"
    pip install --user gitingest
elif command -v pip3 &> /dev/null; then
    echo "⚠ pipx not found - using pip3 (may conflict with other packages)"
    echo "  Consider installing pipx: https://pipx.pypa.io/"
    pip3 install --user gitingest
else
    echo "✗ ERROR: Neither pipx nor pip found"
    echo ""
    echo "Please install Python and pip first:"
    echo "  - Arch: sudo pacman -S python-pip"
    echo "  - Ubuntu/Debian: sudo apt install python3-pip"
    echo "  - macOS: brew install python"
    echo ""
    echo "Then install pipx (recommended):"
    echo "  pip install --user pipx"
    echo "  pipx ensurepath"
    exit 1
fi

echo ""
echo "Verifying installation..."
if gitingest --version &> /dev/null; then
    echo "✓ GitIngest installed successfully!"
    echo ""
    gitingest --version
    echo ""
    echo "The gitingest tool is now ready to use in OpenCode."
else
    echo "✗ Installation completed but gitingest not found in PATH"
    echo ""
    echo "You may need to:"
    echo "  1. Close and reopen your terminal"
    echo "  2. Add pipx bin directory to PATH"
    echo "  3. Run: pipx ensurepath"
fi
