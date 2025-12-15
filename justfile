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
    mkdir -p src tests
    
    # Generate a library-specific README
    echo "# {{name}}" > "README_{{name}}.md"
    echo "" >> "README_{{name}}.md"
    echo "Documentation for the **{{name}}** library." >> "README_{{name}}.md"

    # Generate a starter source file
    echo "def hello():" > "src/lib.py"
    echo "    print('Hello from {{name}}!')" >> "src/lib.py"

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
