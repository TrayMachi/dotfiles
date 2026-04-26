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
	@printf "\n"
	@printf "\033[1;33mPreview of changes for %s:\033[0m\n" "$(1)"
	@printf "\033[2m(repo → system)\033[0m\n"
	@printf "\n"
	@diff --color=auto -ruN $(3) $(2) || true
	@printf "\n"
	@read -p "Apply these changes to $(1)? [y/N] " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		printf "\033[1;31mSkipped %s.\033[0m\n" "$(1)"; \
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
	@printf "\033[1;36m=== Fish Config Differences ===\033[0m\n"
	@diff --color=auto -ruN ./fish/ ~/.config/fish/ || true

# Diff hypr config  
diff-hypr:
	@printf "\033[1;36m=== Hypr Config Differences ===\033[0m\n"
	@diff --color=auto -ruN ./hypr/ ~/.config/hypr/ || true