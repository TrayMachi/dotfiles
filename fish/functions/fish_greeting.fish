function fish_greeting
    set -l arch_logos \
        "arch" \
        "arch2" \
        "arch3" \

    set random_logo (random choice $arch_logos)

    # Run fastfetch with your custom config but random logo
    fastfetch --logo $random_logo
end
