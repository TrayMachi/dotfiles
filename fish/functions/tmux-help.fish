function tmux-help
    echo ""
    echo "TMUX CHEATSHEET (Prefix: Ctrl+a)"
    echo "================================"
    echo ""

    echo Sessions
    echo --------
    echo "tmux new -s name        Create session"
    echo "tmux ls                 List sessions"
    echo "tmux attach -t name     Attach session"
    echo "Ctrl+a d                Detach session"
    echo ""

    echo Windows
    echo -------
    echo "Ctrl+a c                New window"
    echo "Ctrl+a ,                Rename window"
    echo "Ctrl+a n                Next window"
    echo "Ctrl+a p                Previous window"
    echo "Ctrl+a w                Window list"
    echo "Ctrl+a &                Close window"
    echo ""

    echo Panes
    echo -----
    echo "Ctrl+a |                Vertical split"
    echo "Ctrl+a -                Horizontal split"
    echo "Ctrl+a o                Switch pane"
    echo "Ctrl+a x                Kill pane"
    echo "Ctrl+a z                Zoom pane"
    echo ""

    echo Navigation
    echo ----------
    echo "Ctrl+a Arrow Keys       Move between panes"
    echo "Ctrl+a q                Show pane numbers"
    echo ""

    echo Resize
    echo ------
    echo "Ctrl+a Ctrl+Arrow       Resize pane"
    echo ""

    echo "Copy Mode"
    echo ---------
    echo "Ctrl+a [                Enter scroll mode"
    echo "Space                   Start selection"
    echo "Enter                   Copy selection"
    echo "q                       Exit copy mode"
    echo ""

    echo Misc
    echo ----
    echo "Ctrl+a :                Command prompt"
    echo "Ctrl+a ?                List all keybindings"
    echo "Ctrl+a r                Reload config"
    echo ""
end
