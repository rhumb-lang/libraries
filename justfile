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
    SOURCE_TIP_DIR="{{name}}/-"
    mkdir -p $SOURCE_TIP_DIR
    
    # Generate a catalog file
    echo "{{name}}:" > "{{name}}@.rhy"
    echo "    👤: Jake Russo # author" >> "{{name}}@.rhy"
    echo "    🪪: MIT" >> "{{name}}@.rhy"
    echo "    📦: https://github.com/rhumb-lang/libraries" >> "{{name}}@.rhy"
    echo "    📝: >" >> "{{name}}@.rhy"
    echo "        This is the initial description of the {{name}} Base Library and it can span" >> "{{name}}@.rhy"
    echo "        multiple lines using thr yaml \">\" operator" >> "{{name}}@.rhy"
    echo "    📂: {{name}}" >> "{{name}}@.rhy"
    echo "" >> "{{name}}@.rhy"
    echo "-: ~" >> "{{name}}@.rhy"

    # Generate an entry point source file
    echo "hello .= [] -> (" > "$SOURCE_TIP_DIR/+{{name}}.rh"
    echo "    'Hello from the {{name}} Base Library!'" >> "$SOURCE_TIP_DIR/+{{name}}.rh"
    echo ")" >> "$SOURCE_TIP_DIR/+{{name}}.rh"

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

# Generate a catalog of libraries in the main README.md                                                                                                                                     │ 
generate-readme source_branch="main":
    #!/usr/bin/env bash
    set -e
    CURRENT_BRANCH=$(git branch --show-current)

    if [ "$CURRENT_BRANCH" != "{{source_branch}}" ]; then
        echo "Error: Please run this command from the '{{source_branch}}' branch."
        exit 1
    fi

    echo "Generating catalog README..."

    TMP=$(mktemp)

    # Capture text before HEADER (inclusive)
    sed '/<!-- HEADER -->/q' README.md > "$TMP"

    # Generate Table
    echo "" >> "$TMP"
    echo "| Library Name |" >> "$TMP"
    echo "| :--- |" >> "$TMP"

    # Determine base URL for links (handling SSH and HTTPS forms for GitHub)
    REMOTE_URL=$(git remote get-url origin | sed -e 's/^git@github.com:/https:\/\/github.com\//' -e 's/\.git$//')

    # Get list of branches, sort them
    git for-each-ref --format='%(refname:short)' refs/heads/ | grep -v "^{{source_branch}}$" | sort | while read -r branch; do
        # We rely on Markdown/Browser to handle URL encoding of unicode branch names
        echo "| [$branch]($REMOTE_URL/tree/$branch) |" >> "$TMP"
    done

    echo "" >> "$TMP"

    # Capture text from FOOTER (inclusive) to end
    sed -n '/<!-- FOOTER -->/,$p' README.md >> "$TMP"

    mv "$TMP" README.md

    echo "✅ README.md updated with library catalog."  