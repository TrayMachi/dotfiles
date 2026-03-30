function fish_greeting
    # Arch variants (weighted heavily - 60% chance combined)
    set -l arch_logos \
        "arch" \
        "arch2" \
        "arch3" \
        "arch_small" \
        "arch_old" \
        "ArchBox" \
        "Archcraft" \
        "Archcraft2" \
        "ARCHlabs" \
        "ArchStrike"

    # Artix variants (Arch-based, 15% chance)
    set -l artix_logos \
        "artix" \
        "artix_small" \
        "artix2_small"

    # Manjaro variants (Arch-based, 10% chance)
    set -l manjaro_logos \
        "manjaro" \
        "manjaro_small"

    # Other distros (15% chance)
    set -l other_logos \
        "debian" \
        "ubuntu" \
        "fedora" \
        "alpine" \
        "Alpine2" \
        "void" \
        "gentoo" \
        "nixos" \
        "opensuse" \
        "slackware" \
        "linux" \
        "tux"

    # Weighted random selection
    set -l rand (random 1 100)
    set -l random_logo

    if test $rand -le 60
        # 60% chance: Arch variants
        set random_logo (random choice $arch_logos)
    else if test $rand -le 75
        # 15% chance: Artix variants
        set random_logo (random choice $artix_logos)
    else if test $rand -le 85
        # 10% chance: Manjaro variants
        set random_logo (random choice $manjaro_logos)
    else
        # 15% chance: Other distros
        set random_logo (random choice $other_logos)
    end

    # Run fastfetch with your custom config but random logo
    fastfetch --logo $random_logo
end
