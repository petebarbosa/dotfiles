# Caps Lock: Escape on Tap, Arrow Keys on Hold, Caps Lock on Shift+Caps

A step-by-step guide to making Caps Lock send Escape when tapped alone, act as arrow keys when held with HJKL, and act as Caps Lock when pressed with Shift.

## Prerequisites

- **Hyprland** (Wayland compositor)
- **keyd** (key remapping daemon)
- Root access via `pkexec` (Polkit)

## Steps

### 1. Install keyd, if not installed

```bash
sudo pacman -S keyd
```

If not found:
```bash
yay -S keyd
```

### 2. Configure keyd

Create `/etc/keyd/default.conf`:

```bash
pkexec tee /etc/keyd/default.conf > /dev/null << 'EOF'
[ids]
*

[main]
capslock = overload(arrows, esc)

[arrows]
h = left
j = down
k = up
l = right

[shift]
capslock = capslock
EOF
```

**Explanation:**
- `[main]` section: Uses `overload(arrows, esc)` - tap sends Escape, hold activates arrow layer
- `[arrows]` section: When Caps is held, HJKL become arrow keys
- `[shift]` section: When Shift is held, Caps sends Caps Lock (toggle)

**How `overload` works:**
- `overload(arrows, esc)` means:
  - **Hold** Caps → activates `arrows` layer
  - **Tap** (quick press/release) → sends Escape

### 3. Remove conflicting Hyprland options

Edit `~/.config/hypr/input.conf` and set `kb_options`:

```bash
kb_options = caps:escape
```

Set to empty.

### 4. Start keyd service

```bash
pkexec systemctl enable --now keyd
```

Or if already enabled, just restart:

```bash
pkexec systemctl restart keyd
```

### 5. Reload Hyprland

```bash
hyprctl reload
```

### 6. Test

- **Tap Caps** → Escape (e.g., exits insert mode in Vim)
- **Hold Caps + H** → Left arrow
- **Hold Caps + J** → Down arrow
- **Hold Caps + K** → Up arrow
- **Hold Caps + L** → Right arrow
- **Shift+Caps** → Caps Lock (toggles capital letters)

## Verification Commands

Check keyd status:
```bash
pkexec systemctl status keyd
```

Monitor key events:
```bash
keyd monitor
```

## Troubleshooting

- If not working, check service status: `pkexec systemctl status keyd`
- View keyd logs: `journalctl -u keyd -f`
- Ensure no conflicting Hyprland `kb_options` are set
- Restart keyd after config changes: `pkexec systemctl restart keyd`

## References

- [keyd GitHub](https://github.com/rvaiya/keyd)
- [Hyprland Wiki - Uncommon tips](https://wiki.hypr.land/Configuring/Uncommon-tips--tricks/)
