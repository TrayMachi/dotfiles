.PHONY: backup restore backup-fish backup-hypr restore-fish restore-hypr diff diff-fish diff-hypr confirm-restore-fish confirm-restore-hypr
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

# Restore all configs from repo to system (with confirmation)
restore: restore-fish restore-hypr
	@echo "All configs restored!"

# Helper: confirm before restoring
define CONFIRM_RESTORE
	@echo ""
	@echo "\033[1;33mPreview of changes for $(1):\033[0m"
	@echo "\033[2m(repo → system)\033[0m"
	@echo ""
	@diff --color=auto -ruN $(2) $(3) || true
	@echo ""
	@read -p "Apply these changes to $(1)? [y/N] " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "\033[1;31mSkipped $(1).\033[0m"; \
		exit 1; \
	fi
endef

# Restore fish config (with confirmation)
restore-fish:
	$(call CONFIRM_RESTORE,fish,./fish/,~/.config/fish/)
	@echo "Restoring fish config..."
	@mkdir -p ~/.config/fish
	@rsync -av --delete ./fish/ ~/.config/fish/
	@echo "Fish config restored."

# Restore hypr config (with confirmation)
restore-hypr:
	$(call CONFIRM_RESTORE,hypr,./hypr/,~/.config/hypr/)
	@echo "Restoring hypr config..."
	@mkdir -p ~/.config/hypr
	@rsync -av --delete ./hypr/ ~/.config/hypr/
	@echo "Hypr config restored."

# Force restore without confirmation
confirm-restore-fish:
	@echo "Restoring fish config..."
	@mkdir -p ~/.config/fish
	@rsync -av --delete ./fish/ ~/.config/fish/
	@echo "Fish config restored."

confirm-restore-hypr:
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