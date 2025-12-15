set shell := ["bash", "-c"]

# List available commands
default:
    @just --list

# Create a new orphan library branch with shared files and templates
new-lib name:
    #!/usr/bin/env bash
    set -e
    SOURCE_BRANCH=$(git branch --show-current)
    
    if git show-ref --verify --quiet "refs/heads/{{name}}"; then
        echo "Error: Branch '{{name}}' already exists."
        exit 1
    fi

    echo "Creating new library branch: {{name}}..."
    # Create orphan branch (disconnected history)
    git checkout --orphan "{{name}}"
    
    # Remove all files from the previous branch context to start fresh
    git rm -rf . > /dev/null

    git checkout "$SOURCE_BRANCH" -- .gitignore justfile README.md .gitattributes
    
    # Create standard directory structure
    mkdir -p -
    
    # Generate a catalog file
    echo "{{name}}:" > "{{name}}@.rhy"
    echo "    👤: Jake Russo # author" >> "README_{{name}}.md"
    echo "    🪪: MIT # license" >> "README_{{name}}.md"
    echo "    📦: https://github.com/user/repo" >> "README_{{name}}.md"
    echo "    📝: >" >> "README_{{name}}.md"
    echo "        This is the initial description of the {{name}} Base Library and it can span" >> "README_{{name}}.md"
    echo "        multiple lines using thr yaml \">\" operator" >> "README_{{name}}.md"
    echo "" >> "README_{{name}}.md"
    echo "-: ~" >> "README_{{name}}.md"

    # Generate an entry point source file
    echo "hello .= [] -> (" > "-/+{{name}}.rh"
    echo "    'Hello from the {{name}} Base Library!'" >> "-/+{{name}}.rh"
    echo ")" >> "-/+{{name}}.rh"

    # ---------------------------

    # Stage and commit
    git add .
    git commit -m "Initialize library: {{name}}"
    
    echo "✅ Successfully created library '{{name}}' and switched to it."

# Update shared files (.gitignore, justfile, README.md) across all other branches
sync-shared source_branch="main":
    #!/usr/bin/env bash
    set -e
    CURRENT_BRANCH=$(git branch --show-current)
    
    # Ensure we are on the source branch (or getting files from it is valid)
    if [ "$CURRENT_BRANCH" != "{{source_branch}}" ]; then
        echo "⚠️  Warning: You are running this from '$CURRENT_BRANCH', but syncing files FROM '{{source_branch}}'."
        read -p "Continue? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
    fi

    # Get all local branches except the source branch
    BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -v "^{{source_branch}}$")

    echo "Syncing shared files from '{{source_branch}}' to all other branches..."

    for branch in $BRANCHES; do
        echo "--------------------------------"
        echo "🔄 Processing branch: $branch"
        
        # Switch to the branch
        git checkout "$branch" > /dev/null 2>&1
        
        # Force checkout the shared files from the source branch
        # This overwrites the local versions with the source versions
        git checkout "{{source_branch}}" -- justfile README.md .gitattributes
        
        # Check if there are changes to commit
        if ! git diff --quiet --cached; then
            git commit -m "Maintenance: Sync shared infrastructure from {{source_branch}}"
            echo "✅ Updated shared files."
        else
            echo "zzz No changes needed."
        fi
    done

    # Return to original branch
    git checkout "$CURRENT_BRANCH" > /dev/null 2>&1
    echo "--------------------------------"
    echo "✨ Sync complete."
