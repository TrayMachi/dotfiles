function worktree
    if test (count $argv) -lt 1
        echo "Usage: gwt <branch-name> [base-branch]"
        echo "Example: gwt feature/navbar origin/main"
        return 1
    end

    set branch $argv[1]
    set base origin/main

    if test (count $argv) -ge 2
        set base $argv[2]
    end

    # Convert feature/navbar -> feature-navbar for folder name
    set folder (string replace -a "/" "-" $branch)
    set path "../$folder"

    if test -e $path
        echo "Path already exists: $path"
        return 1
    end

    echo "Creating worktree..."
    git worktree add -b $branch $path $base
    or return 1

    if test -d node_modules
        echo "Copying node_modules..."
        rsync -a --info=progress2 node_modules/ "$path/node_modules/"
    else
        echo "No node_modules found. Skipping copy."
    end

    echo "Done:"
    echo "  branch: $branch"
    echo "  path:   $path"
end
