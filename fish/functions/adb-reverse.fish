function adb-reverse --description "Reverse ADB TCP ports from a named config file"
    if test (count $argv) -eq 0
        echo "Usage: adb-reverse <config-name>" >&2
        return 1
    end

    set config_file /home/tray/.config/adb-reverse/$argv[1]

    if not test -f $config_file
        echo "Error: config file not found: $config_file" >&2
        return 1
    end

    # Get active reverse list once; output format: (reverse) tcp:<remote> tcp:<local>
    set active_list (adb reverse --list 2>/dev/null)

    for port in (cat $config_file)
        # Skip empty lines or comments
        if string match -qr '^\s*$|^#' -- $port
            continue
        end

        # Check if this port already appears in the active reverse list
        if string match -q -- "*tcp:$port*" $active_list
            echo "skipped  tcp:$port (already active)"
        else
            adb reverse tcp:$port tcp:$port
            and echo "reversed tcp:$port ↔ tcp:$port"
            or echo "failed   tcp:$port" >&2
        end
    end
end
