.PHONY: backup restore backup-fish backup-hypr backup-niri backup-opencode backup-agents backup-fastfetch backup-zed backup-kitty restore-fish restore-hypr restore-niri restore-opencode restore-agents restore-fastfetch restore-zed restore-kitty diff diff-fish diff-hypr diff-niri diff-opencode diff-agents diff-fastfetch diff-zed diff-kitty confirm-restore-fish confirm-restore-hypr confirm-restore-niri confirm-restore-opencode confirm-restore-agents confirm-restore-fastfetch confirm-restore-zed confirm-restore-kitty
# Default target
all: backup

# Backup all configs from system to repo
backup: backup-fish backup-hypr backup-niri backup-opencode backup-agents backup-fastfetch backup-zed backup-kitty
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

# Backup niri config
backup-niri:
	@echo "Backing up niri config..."
	@rsync -av --delete ~/.config/niri/ ./niri/
	@echo "Niri config backed up."

# Backup opencode config
backup-opencode:
	@echo "Backing up opencode config..."
	@rsync -av --delete ~/.config/opencode/ ./opencode/
	@echo "Opencode config backed up."

# Backup agents config
backup-agents:
	@echo "Backing up agents config..."
	@rsync -av --delete ~/.agents/ ./agents/
	@echo "Agents config backed up."

# Backup fastfetch config
backup-fastfetch:
	@echo "Backing up fastfetch config..."
	@rsync -av --delete ~/.config/fastfetch/ ./fastfetch/
	@echo "Fastfetch config backed up."

# Backup zed config
backup-zed:
	@echo "Backing up zed config..."
	@rsync -av --delete ~/.config/zed/ ./zed/
	@echo "Zed config backed up."

# Backup kitty config
backup-kitty:
	@echo "Backing up kitty config..."
	@rsync -av --delete ~/.config/kitty/ ./kitty/
	@echo "Kitty config backed up."

# Restore all configs from repo to system (with confirmation)
restore: restore-fish restore-hypr restore-niri restore-opencode restore-agents restore-fastfetch restore-zed restore-kitty
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

# Restore niri config (with confirmation)
restore-niri:
	$(call CONFIRM_RESTORE,niri,./niri/,~/.config/niri/)
	@echo "Restoring niri config..."
	@mkdir -p ~/.config/niri
	@rsync -av --delete ./niri/ ~/.config/niri/
	@echo "Niri config restored."

# Restore opencode config (with confirmation)
restore-opencode:
	$(call CONFIRM_RESTORE,opencode,./opencode/,~/.config/opencode/)
	@echo "Restoring opencode config..."
	@mkdir -p ~/.config/opencode
	@rsync -av --delete ./opencode/ ~/.config/opencode/
	@echo "Opencode config restored."

# Restore agents config (with confirmation)
restore-agents:
	$(call CONFIRM_RESTORE,agents,./agents/,~/.agents/)
	@echo "Restoring agents config..."
	@mkdir -p ~/.agents
	@rsync -av --delete ./agents/ ~/.agents/
	@echo "Agents config restored."

# Restore fastfetch config (with confirmation)
restore-fastfetch:
	$(call CONFIRM_RESTORE,fastfetch,./fastfetch/,~/.config/fastfetch/)
	@echo "Restoring fastfetch config..."
	@mkdir -p ~/.config/fastfetch
	@rsync -av --delete ./fastfetch/ ~/.config/fastfetch/
	@echo "Fastfetch config restored."

# Restore zed config (with confirmation)
restore-zed:
	$(call CONFIRM_RESTORE,zed,./zed/,~/.config/zed/)
	@echo "Restoring zed config..."
	@mkdir -p ~/.config/zed
	@rsync -av --delete ./zed/ ~/.config/zed/
	@echo "Zed config restored."

# Restore kitty config (with confirmation)
restore-kitty:
	$(call CONFIRM_RESTORE,kitty,./kitty/,~/.config/kitty/)
	@echo "Restoring kitty config..."
	@mkdir -p ~/.config/kitty
	@rsync -av --delete ./kitty/ ~/.config/kitty/
	@echo "Kitty config restored."

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

confirm-restore-niri:
	@echo "Restoring niri config..."
	@mkdir -p ~/.config/niri
	@rsync -av --delete ./niri/ ~/.config/niri/
	@echo "Niri config restored."

confirm-restore-opencode:
	@echo "Restoring opencode config..."
	@mkdir -p ~/.config/opencode
	@rsync -av --delete ./opencode/ ~/.config/opencode/
	@echo "Opencode config restored."

confirm-restore-agents:
	@echo "Restoring agents config..."
	@mkdir -p ~/.agents
	@rsync -av --delete ./agents/ ~/.agents/
	@echo "Agents config restored."

confirm-restore-fastfetch:
	@echo "Restoring fastfetch config..."
	@mkdir -p ~/.config/fastfetch
	@rsync -av --delete ./fastfetch/ ~/.config/fastfetch/
	@echo "Fastfetch config restored."

confirm-restore-zed:
	@echo "Restoring zed config..."
	@mkdir -p ~/.config/zed
	@rsync -av --delete ./zed/ ~/.config/zed/
	@echo "Zed config restored."

confirm-restore-kitty:
	@echo "Restoring kitty config..."
	@mkdir -p ~/.config/kitty
	@rsync -av --delete ./kitty/ ~/.config/kitty/
	@echo "Kitty config restored."

# Diff all configs (system vs repo)
diff: diff-fish diff-hypr diff-niri diff-opencode diff-agents diff-fastfetch diff-zed diff-kitty

# Diff fish config
diff-fish:
	@printf "\033[1;36m=== Fish Config Differences ===\033[0m\n"
	@diff --color=auto -ruN ./fish/ ~/.config/fish/ || true

# Diff hypr config  
diff-hypr:
	@printf "\033[1;36m=== Hypr Config Differences ===\033[0m\n"
	@diff --color=auto -ruN ./hypr/ ~/.config/hypr/ || true

# Diff niri config
diff-niri:
	@printf "\033[1;36m=== Niri Config Differences ===\033[0m\n"
	@diff --color=auto -ruN ./niri/ ~/.config/niri/ || true

# Diff opencode config
diff-opencode:
	@printf "\033[1;36m=== Opencode Config Differences ===\033[0m\n"
	@diff --color=auto -ruN ./opencode/ ~/.config/opencode/ || true

# Diff agents config
diff-agents:
	@printf "\033[1;36m=== Agents Config Differences ===\033[0m\n"
	@diff --color=auto -ruN ./agents/ ~/.agents/ || true

# Diff fastfetch config
diff-fastfetch:
	@printf "\033[1;36m=== Fastfetch Config Differences ===\033[0m\n"
	@diff --color=auto -ruN ./fastfetch/ ~/.config/fastfetch/ || true

# Diff zed config
diff-zed:
	@printf "\033[1;36m=== Zed Config Differences ===\033[0m\n"
	@diff --color=auto -ruN ./zed/ ~/.config/zed/ || true

# Diff kitty config
diff-kitty:
	@printf "\033[1;36m=== Kitty Config Differences ===\033[0m\n"
	@diff --color=auto -ruN ./kitty/ ~/.config/kitty/ || true
