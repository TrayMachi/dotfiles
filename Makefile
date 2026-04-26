.PHONY: backup restore backup-fish backup-hypr restore-fish restore-hypr diff diff-fish diff-hypr

# Default target
all: backup

# Backup all configs from system to repo
backup: backup-fish backup-hypr
	@echo "All configs backed up!"

# Backup fish config
backup-fish:
	@echo "Backing up fish config..."
	@rsync -av --delete ~/.config/fish/ ./fish/
	@echo "Fish config backed up."

# Backup hypr config
backup-hypr:
	@echo "Backing up hypr config..."
	@rsync -av --delete ~/.config/hypr/ ./hypr/
	@echo "Hypr config backed up."

# Restore all configs from repo to system
restore: restore-fish restore-hypr
	@echo "All configs restored!"

# Restore fish config
restore-fish:
	@echo "Restoring fish config..."
	@mkdir -p ~/.config/fish
	@rsync -av --delete ./fish/ ~/.config/fish/
	@echo "Fish config restored."

# Restore hypr config
restore-hypr:
	@echo "Restoring hypr config..."
	@mkdir -p ~/.config/hypr
	@rsync -av --delete ./hypr/ ~/.config/hypr/
	@echo "Hypr config restored."

# Diff all configs (system vs repo)
diff: diff-fish diff-hypr

# Diff fish config
diff-fish:
	@echo "\033[1;36m=== Fish Config Differences ===\033[0m"
	@diff --color=auto -ruN ./fish/ ~/.config/fish/ || true

# Diff hypr config  
diff-hypr:
	@echo "\033[1;36m=== Hypr Config Differences ===\033[0m"
	@diff --color=auto -ruN ./hypr/ ~/.config/hypr/ || true
