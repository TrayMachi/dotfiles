#!/usr/bin/env fish

echo "==> Arch Linux Cleanup Script شروع"

# 1. Remove orphan packages
echo "\n[1/6] Removing orphan packages..."
set orphans (pacman -Qtdq 2>/dev/null)
if test -n "$orphans"
    sudo pacman -Rns $orphans
else
    echo "No orphan packages found."
end

# 2. Clean package cache (keep last 2 versions)
echo "\n[2/6] Cleaning package cache (keeping last 2 versions)..."
sudo paccache -r

# Optional: aggressive cache clean (uncomment if needed)
# sudo paccache -ruk0

# 3. Remove uninstalled package cache
echo "\n[3/6] Removing unused cached packages..."
sudo paccache -ruk1

# 4. Clear journal logs (keep last 7 days)
echo "\n[4/6] Cleaning journal logs..."
sudo journalctl --vacuum-time=7d

# 5. Clean user cache
echo "\n[5/6] Cleaning user cache (~/.cache)..."
rm -rf ~/.cache/*

# 6. Clean trash
echo "\n[6/6] Cleaning trash..."
rm -rf ~/.local/share/Trash/*

echo "\n==> Cleanup complete 🎉"
