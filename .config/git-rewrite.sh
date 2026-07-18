#!/bin/bash

# Git History Rewriter - Clean start with git init
# Usage: ./rewrite_history.sh <username> <email> <start_date> <end_date> <repo_path>

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Help function
show_help() {
    cat << EOF
Git History Rewriter - Clean start with realistic timeline

Usage: $0 <username> <email> <start_date> <end_date> <repo_path>

Arguments:
    username    Git username for commits
    email       Git email for commits
    start_date  Start date (YYYY-MM-DD format)
    end_date    End date (YYYY-MM-DD format)
    repo_path   Path to the Git repository

Example:
    $0 "John Doe" "john@example.com" "2024-01-01" "2024-12-31" "/path/to/repo"

Features:
    - Completely removes .git and starts fresh with git init
    - Preserves and restores remote URLs
    - Uses existing files from the repository
    - Generates commitlint-compliant commit messages
    - Realistic commit timeline with business-hour bias
EOF
}

# Validate arguments
if [ $# -lt 5 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

USERNAME="$1"
EMAIL="$2"
START_DATE="$3"
END_DATE="$4"
REPO_PATH="$5"

# Validate date format
validate_date() {
    if ! date -d "$1" >/dev/null 2>&1; then
        error "Invalid date format: $1. Use YYYY-MM-DD format."
        exit 1
    fi
}

validate_date "$START_DATE"
validate_date "$END_DATE"

# Check repository
if [ ! -d "$REPO_PATH" ]; then
    error "Repository path does not exist: $REPO_PATH"
    exit 1
fi

if [ ! -d "$REPO_PATH/.git" ]; then
    error "Not a Git repository: $REPO_PATH"
    exit 1
fi

# Generate commitlint-compliant messages based on file types
generate_commit_message() {
    local files=("$@")
    local primary_file="${files[0]}"
    local file_count=${#files[@]}
    
    # Get file extension and determine type
    local extension="${primary_file##*.}"
    local basename_file=$(basename "$primary_file")
    local dirname_file=$(dirname "$primary_file")
    
    # Determine commit type based on file characteristics
    local commit_type="feat"
    local scope=""
    local description=""
    
    # Analyze file extension for commit type
    case "$extension" in
        "md"|"txt"|"rst"|"adoc")
            commit_type="docs"
            if [[ "$basename_file" =~ ^[Rr][Ee][Aa][Dd][Mm][Ee] ]]; then
                description="add project documentation"
            else
                description="add documentation"
            fi
            ;;
        "test.js"|"spec.js"|"test.py"|"spec.py"|*"test"*|*"spec"*)
            commit_type="test"
            description="add test suite"
            ;;
        "json"|"yml"|"yaml"|"toml"|"ini"|"cfg"|"conf")
            commit_type="chore"
            if [[ "$basename_file" =~ package\.json|composer\.json|requirements\.txt|Gemfile|pom\.xml|setup\.py ]]; then
                description="add project dependencies"
            else
                description="add configuration"
            fi
            ;;
        "dockerfile"|"Dockerfile"|"docker-compose"*)
            commit_type="build"
            description="add containerization"
            ;;
        "css"|"scss"|"sass"|"less"|"styl")
            commit_type="style"
            description="add styles"
            ;;
        "js"|"ts"|"jsx"|"tsx")
            if [[ "$dirname_file" =~ component|ui|view ]]; then
                commit_type="feat"
                description="add components"
            elif [[ "$dirname_file" =~ util|helper|lib ]]; then
                commit_type="feat"
                description="add utilities"
            else
                commit_type="feat"
                description="add functionality"
            fi
            ;;
        "py")
            if [[ "$basename_file" =~ __init__|setup ]]; then
                commit_type="chore"
                description="add package structure"
            else
                commit_type="feat"
                description="add functionality"
            fi
            ;;
        "java"|"kt"|"scala"|"go"|"rs"|"cpp"|"c"|"h")
            commit_type="feat"
            description="add core logic"
            ;;
        "html"|"htm")
            commit_type="feat"
            description="add web interface"
            ;;
        "sql")
            commit_type="feat"
            description="add database schema"
            ;;
        "sh"|"bash"|"zsh"|"fish"|"ps1"|"bat")
            commit_type="chore"
            description="add scripts"
            ;;
        "png"|"jpg"|"jpeg"|"gif"|"svg"|"ico"|"webp")
            commit_type="feat"
            description="add assets"
            ;;
        "gitignore")
            commit_type="chore"
            description="add git configuration"
            ;;
        *)
            # Default based on directory structure
            if [[ "$dirname_file" =~ src|lib ]]; then
                commit_type="feat"
                description="add source code"
            elif [[ "$dirname_file" =~ doc ]]; then
                commit_type="docs"
                description="add documentation"
            elif [[ "$dirname_file" =~ test ]]; then
                commit_type="test"
                description="add tests"
            elif [[ "$dirname_file" =~ config|conf ]]; then
                commit_type="chore"
                description="add configuration"
            else
                commit_type="feat"
                description="add files"
            fi
            ;;
    esac
    
    # Determine scope from directory structure
    if [[ "$dirname_file" =~ ^\.?/?$ ]]; then
        scope=""  # Root directory, no scope
    else
        # Use first meaningful directory as scope
        local first_dir=$(echo "$dirname_file" | sed 's|^\.||' | sed 's|^/||' | cut -d'/' -f1)
        case "$first_dir" in
            "src"|"lib"|"app")
                scope="core"
                ;;
            "test"|"tests"|"spec"|"__tests__")
                scope="test"
                ;;
            "doc"|"docs"|"documentation")
                scope="docs"
                ;;
            "config"|"conf"|"settings")
                scope="config"
                ;;
            "api"|"server"|"backend")
                scope="api"
                ;;
            "ui"|"frontend"|"client"|"components")
                scope="ui"
                ;;
            "utils"|"utilities"|"helpers")
                scope="utils"
                ;;
            "assets"|"static"|"public")
                scope="assets"
                ;;
            *)
                scope="$first_dir"
                ;;
        esac
    fi
    
    # Adjust description for multiple files
    if [ $file_count -gt 1 ]; then
        case "$commit_type" in
            "feat") description="add features" ;;
            "docs") description="add documentation" ;;
            "test") description="add tests" ;;
            "style") description="add styles" ;;
            "chore") description="add configuration" ;;
            *) description="add files" ;;
        esac
    fi
    
    # Format commit message
    local message="$commit_type"
    if [ -n "$scope" ]; then
        message="$message($scope)"
    fi
    message="$message: $description"
    
    echo "$message"
}

# Generate realistic commit dates
generate_commit_dates() {
    local start_date="$1"
    local end_date="$2"
    local num_commits="$3"
    
    # Try to get timestamps with error checking
    local start_timestamp
    local end_timestamp
    
    if start_timestamp=$(date -d "$start_date" +%s 2>/dev/null); then
        : # Success, no debug output
    else
        # Fallback: try without -d flag (different date implementations)  
        if start_timestamp=$(date --date="$start_date" +%s 2>/dev/null); then
            : # Success with fallback
        else
            error "Cannot parse start date: $start_date"
            return 1
        fi
    fi
    
    if end_timestamp=$(date -d "$end_date" +%s 2>/dev/null); then
        : # Success, no debug output
    else
        # Fallback: try without -d flag
        if end_timestamp=$(date --date="$end_date" +%s 2>/dev/null); then
            : # Success with fallback
        else
            error "Cannot parse end date: $end_date"
            return 1
        fi
    fi
    
    local total_seconds=$((end_timestamp - start_timestamp))
    
    if [ $total_seconds -le 0 ]; then
        error "Invalid date range: start date must be before end date"
        return 1
    fi
    
    # Simple even distribution as fallback if complex logic fails
    local dates=()
    local interval=$((total_seconds / (num_commits + 1)))
    
    for ((i=1; i<=num_commits; i++)); do
        local timestamp=$((start_timestamp + i * interval + RANDOM % 3600))
        if [ $timestamp -le $end_timestamp ]; then
            dates+=("$timestamp")
        fi
    done
    
    # Ensure we have at least some dates
    if [ ${#dates[@]} -eq 0 ]; then
        # Emergency fallback: just use start date + some hours
        for ((i=0; i<num_commits; i++)); do
            local timestamp=$((start_timestamp + i * 3600 + RANDOM % 3600))
            dates+=("$timestamp")
        done
    fi
    
    printf '%s\n' "${dates[@]}" | sort -n
}

# Fixed shuffle array function - simpler and more reliable
shuffle_array() {
    local -a array=("$@")
    local i tmp size rand
    
    size=${#array[@]}
    if [ $size -eq 0 ]; then
        return
    fi
    
    # Simple shuffle using modulo - more reliable than the complex version
    for ((i=size-1; i>0; i--)); do
        rand=$((RANDOM % (i+1)))
        tmp=${array[i]}
        array[i]=${array[rand]}
        array[rand]=$tmp
    done
    
    printf '%s\n' "${array[@]}"
}

# Prioritize important files that should be committed first
prioritize_files() {
    local -a all_files=("$@")
    local -a priority_files=()
    local -a regular_files=()
    local -a remaining_files=()
    
    # Define priority patterns (order matters - higher priority first)
    local -a priority_patterns=(
        "package.json"
        "package-lock.json"
        "composer.json"
        "composer.lock" 
        "requirements.txt"
        "Pipfile"
        "Pipfile.lock"
        "pom.xml"
        "build.gradle"
        "Cargo.toml"
        "Cargo.lock"
        ".gitignore"
        ".gitattributes"
        "README.md"
        "readme.md"
        "README.txt"
        "LICENSE"
        "license"
        "LICENSE.txt"
        "MIT-LICENSE"
        ".editorconfig"
        ".eslintrc*"
        ".prettierrc*"
        "tsconfig.json"
        "webpack.config.js"
        "vite.config.js"
        "next.config.js"
        "nuxt.config.js"
    )
    
    # First, find priority files in order
    for pattern in "${priority_patterns[@]}"; do
        for file in "${all_files[@]}"; do
            local basename_file=$(basename "$file")
            if [[ "$basename_file" == $pattern ]] || [[ "$file" == $pattern ]]; then
                # Check if not already added
                local already_added=false
                for pf in "${priority_files[@]}"; do
                    if [[ "$pf" == "$file" ]]; then
                        already_added=true
                        break
                    fi
                done
                if [[ "$already_added" == false ]]; then
                    priority_files+=("$file")
                fi
            fi
        done
    done
    
    # Then add all other files
    for file in "${all_files[@]}"; do
        local is_priority=false
        for pf in "${priority_files[@]}"; do
            if [[ "$pf" == "$file" ]]; then
                is_priority=true
                break
            fi
        done
        if [[ "$is_priority" == false ]]; then
            regular_files+=("$file")
        fi
    done
    
    # Shuffle the regular files but keep priority files at the beginning
    local -a shuffled_regular=()
    readarray -t shuffled_regular < <(shuffle_array "${regular_files[@]}")
    
    # Combine priority files first, then shuffled regular files
    printf '%s\n' "${priority_files[@]}" "${shuffled_regular[@]}"
}

# Main rewrite function
rewrite_history() {
    cd "$REPO_PATH"
    
    log "Starting clean Git history rewrite..."
    log "Repository: $REPO_PATH"
    log "Author: $USERNAME <$EMAIL>"
    log "Date range: $START_DATE to $END_DATE"
    
    # Store remote URLs before removing .git
    local remotes=()
    if git remote -v >/dev/null 2>&1; then
        while IFS= read -r line; do
            remotes+=("$line")
        done < <(git remote -v | grep "(fetch)" | awk '{print $1 " " $2}')
        log "Stored ${#remotes[@]} remote(s)"
    fi
    
    # Get all files before removing .git (exclude .git directory)
    local all_files=()
    while IFS= read -r -d '' file; do
        # Convert absolute path to relative and remove leading ./
        local rel_file="${file#./}"
        if [[ "$rel_file" != ".git"* && "$rel_file" != "__pycache__"* && "$rel_file" != "node_modules"* && "$rel_file" != ".DS_Store" ]]; then
            all_files+=("$rel_file")
        fi
    done < <(find . -type f -not -path "./.git/*" -print0)
    
    if [ ${#all_files[@]} -eq 0 ]; then
        error "No files found in repository"
        exit 1
    fi
    
    log "Found ${#all_files[@]} files to commit"
    
    # Remove .git directory and start fresh
    warning "Removing .git directory..."
    rm -rf .git
    
    # Initialize new git repository
    git init
    git config user.name "$USERNAME"
    git config user.email "$EMAIL"
    git config commit.gpgsign false
    git config user.signingkey ""
    success "Initialized new Git repository"
    
    # Restore remotes
    for remote in "${remotes[@]}"; do
        local name=$(echo "$remote" | awk '{print $1}')
        local url=$(echo "$remote" | awk '{print $2}')
        git remote add "$name" "$url"
        log "Restored remote: $name -> $url"
    done
    
    # Prioritize and shuffle files for realistic development order
    log "Prioritizing and shuffling files..."
    local prioritized_files=()
    readarray -t prioritized_files < <(prioritize_files "${all_files[@]}")
    log "Files prioritized and shuffled successfully"
    
    # Calculate number of commits (realistic distribution)
    local days_diff=$(( ($(date -d "$END_DATE" +%s) - $(date -d "$START_DATE" +%s)) / 86400 ))
    local num_commits=$((days_diff / 3 + RANDOM % (days_diff / 2) + 5))
    
    # Ensure reasonable bounds
    if [ $num_commits -gt ${#prioritized_files[@]} ]; then
        num_commits=${#prioritized_files[@]}
    fi
    if [ $num_commits -lt 5 ]; then
        num_commits=5
    fi
    
    log "Generating $num_commits commits over $days_diff days"
    
    # Generate commit dates
    local commit_dates=()
    readarray -t commit_dates < <(generate_commit_dates "$START_DATE" "$END_DATE" "$num_commits")
    # Calculate files per commit (with some variation)
    local total_files=${#prioritized_files[@]}
    local base_files_per_commit=$((total_files / num_commits))
    local remaining_files=$((total_files % num_commits))
    
    # Debug: Check if we have commit dates
    if [ ${#commit_dates[@]} -eq 0 ]; then
        error "No commit dates generated"
        exit 1
    fi
    
    log "Generated ${#commit_dates[@]} commit dates"
    
    # Create commits with detailed logging
    local file_index=0
    local actual_commits=0
    
    echo
    log "Starting commit creation process..."
    log "Files to distribute: $total_files files across $num_commits commits"
    log "Base files per commit: $base_files_per_commit"
    
    for ((i=0; i<num_commits; i++)); do
        echo
        log "=== COMMIT $((i+1))/$num_commits ==="
        
        # Check if we have a commit date for this index
        if [ $i -ge ${#commit_dates[@]} ]; then
            log "No more commit dates available, stopping at $actual_commits commits"
            break
        fi
        
        local timestamp="${commit_dates[$i]}"
        local commit_date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')
        log "Commit date: $commit_date (timestamp: $timestamp)"
        
        # Calculate files for this commit (with variation)
        local files_this_commit=$base_files_per_commit
        if [ $i -lt $remaining_files ]; then
            files_this_commit=$((files_this_commit + 1))
        fi
        
        # Add some randomness to file count (±1-2 files)
        local variation=$((RANDOM % 3 - 1))  # -1, 0, or 1
        files_this_commit=$((files_this_commit + variation))
        
        # Ensure we don't exceed available files
        local remaining_files_count=$((total_files - file_index))
        if [ $files_this_commit -gt $remaining_files_count ]; then
            files_this_commit=$remaining_files_count
        fi
        if [ $files_this_commit -lt 1 ]; then
            files_this_commit=1
        fi
        
        log "Files to commit: $files_this_commit (remaining: $remaining_files_count)"
        
        # Check if we've processed all files
        if [ $file_index -ge $total_files ]; then
            log "All files have been processed, stopping early"
            break
        fi
        
        # Select files for this commit
        local commit_files=()
        for ((j=0; j<files_this_commit && file_index<total_files; j++)); do
            commit_files+=("${prioritized_files[$file_index]}")
            file_index=$((file_index + 1))
        done
        
        if [ ${#commit_files[@]} -eq 0 ]; then
            log "ERROR: No files selected for commit $((i+1)), skipping"
            continue
        fi
        
        log "Selected files (${#commit_files[@]}):"
        for file in "${commit_files[@]}"; do
            if [ -f "$file" ]; then
                log "  ✓ $file (exists)"
            else
                log "  ✗ $file (missing)"
            fi
        done
        
        # Add files to git
        local files_added=0
        for file in "${commit_files[@]}"; do
            if [ -f "$file" ]; then
                if git add "$file" 2>/dev/null; then
                    files_added=$((files_added + 1))
                    log "  Added: $file"
                else
                    log "  Failed to add: $file"
                fi
            else
                warning "File not found: $file"
            fi
        done
        
        log "Files successfully added to staging: $files_added"
        
        # Check if we have anything to commit
        if git diff --cached --quiet; then
            warning "Nothing staged for commit $((i+1)) - git diff --cached is empty"
            continue
        fi
        
        log "Staged files for commit:"
        git diff --cached --name-only | while read file; do log "  - $file"; done
        
        # Generate commit message
        local commit_msg=$(generate_commit_message "${commit_files[@]}")
        log "Generated commit message: '$commit_msg'"
        
        # Set commit date and author
        export GIT_AUTHOR_DATE="$commit_date"
        export GIT_COMMITTER_DATE="$commit_date"
        
        log "Attempting git commit..."
        if git commit -m "$commit_msg" >/dev/null 2>&1; then
            actual_commits=$((actual_commits + 1))
            success "Commit $actual_commits created successfully!"
            
            # Show commit info
            git log -1 --oneline
            
        else
            error "Failed to create commit $((i+1))"
            log "Git error output:"
            git status
        fi
    done
    
    echo  # New line after progress
    
    # Handle any remaining files that weren't committed
    if [ $file_index -lt $total_files ]; then
        local actual_remaining=$((total_files - file_index))
        warning "Found $actual_remaining remaining files that weren't committed yet"
        log "Creating final commit(s) for remaining files..."
        
        # Create additional commits for remaining files
        local remaining_count=$((total_files - file_index))
        local max_additional_commits=3
        local files_per_final_commit=$((remaining_count / max_additional_commits + 1))
        
        local final_commit_index=1
        while [ $file_index -lt $total_files ]; do
            log "=== FINAL COMMIT $final_commit_index ==="
            
            # Select remaining files for this final commit
            local final_commit_files=()
            local files_to_add=$files_per_final_commit
            if [ $((file_index + files_to_add)) -gt $total_files ]; then
                files_to_add=$((total_files - file_index))
            fi
            
            for ((k=0; k<files_to_add && file_index<total_files; k++)); do
                final_commit_files+=("${prioritized_files[$file_index]}")
                file_index=$((file_index + 1))
            done
            
            log "Adding ${#final_commit_files[@]} remaining files"
            
            # Add files to git
            local files_added=0
            for file in "${final_commit_files[@]}"; do
                if [ -f "$file" ]; then
                    if git add "$file" 2>/dev/null; then
                        files_added=$((files_added + 1))
                    fi
                fi
            done
            
            # Create commit if we have files
            if [ $files_added -gt 0 ] && ! git diff --cached --quiet; then
                local final_commit_msg=$(generate_commit_message "${final_commit_files[@]}")
                
                # Use the last commit date plus some time
                local last_timestamp="${commit_dates[-1]}"
                local final_timestamp=$((last_timestamp + 3600 * final_commit_index))
                local final_commit_date=$(date -d "@$final_timestamp" '+%Y-%m-%d %H:%M:%S')
                
                export GIT_AUTHOR_DATE="$final_commit_date"
                export GIT_COMMITTER_DATE="$final_commit_date"
                
                if git commit -m "$final_commit_msg" >/dev/null 2>&1; then
                    actual_commits=$((actual_commits + 1))
                    success "Final commit $final_commit_index created successfully!"
                    git log -1 --oneline
                fi
            fi
            
            final_commit_index=$((final_commit_index + 1))
        done
    fi
    
    # Unset environment variables
    unset GIT_AUTHOR_DATE GIT_COMMITTER_DATE
    
    success "Git history rewrite completed!"
    
    # Comprehensive verification
    echo
    log "=== VERIFICATION ==="
    
    # Check if we actually have commits
    local commit_count=0
    if git rev-parse HEAD >/dev/null 2>&1; then
        commit_count=$(git rev-list --count HEAD)
        success "Repository now contains $commit_count commits from $START_DATE to $END_DATE"
        log "Files processed: $file_index out of $total_files total files"
    else
        error "No commits were created!"
        log "Debug info:"
        log "  - Total files found: $total_files"
        log "  - Commit dates generated: ${#commit_dates[@]}"
        log "  - Files processed: $file_index"
        return 1
    fi
    
    # Verify all files are actually tracked in git
    local committed_files=($(git ls-tree -r --name-only HEAD 2>/dev/null))
    local committed_count=${#committed_files[@]}
    
    log "Files in git repository: $committed_count"
    log "Original files found: $total_files"
    
    # Find missing files
    local missing_files=()
    for original_file in "${prioritized_files[@]}"; do
        local found=false
        for committed_file in "${committed_files[@]}"; do
            if [[ "$original_file" == "$committed_file" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == false ]] && [[ -f "$original_file" ]]; then
            missing_files+=("$original_file")
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        success "✅ ALL FILES SUCCESSFULLY COMMITTED!"
        success "Verification complete: $committed_count/$total_files files are tracked in git"
    else
        warning "⚠️  Found ${#missing_files[@]} files that weren't committed:"
        for missing_file in "${missing_files[@]}"; do
            warning "  - $missing_file"
        done
        
        # Attempt to add the missing files in one final commit
        log "Attempting to add missing files in a final cleanup commit..."
        local cleanup_added=0
        for missing_file in "${missing_files[@]}"; do
            if [ -f "$missing_file" ] && git add "$missing_file" 2>/dev/null; then
                cleanup_added=$((cleanup_added + 1))
            fi
        done
        
        if [ $cleanup_added -gt 0 ] && ! git diff --cached --quiet; then
            local cleanup_msg="chore: add remaining files"
            # Use end date + 1 hour for cleanup commit
            local cleanup_timestamp=$(($(date -d "$END_DATE" +%s) + 3600))
            local cleanup_date=$(date -d "@$cleanup_timestamp" '+%Y-%m-%d %H:%M:%S')
            
            export GIT_AUTHOR_DATE="$cleanup_date"
            export GIT_COMMITTER_DATE="$cleanup_date"
            
            if git commit -m "$cleanup_msg" >/dev/null 2>&1; then
                success "✅ Cleanup commit created with $cleanup_added missing files!"
                git log -1 --oneline
                
                # Re-verify
                local final_committed_files=($(git ls-tree -r --name-only HEAD 2>/dev/null))
                success "Final verification: ${#final_committed_files[@]}/$total_files files are now tracked in git"
            else
                error "Failed to create cleanup commit"
            fi
            
            unset GIT_AUTHOR_DATE GIT_COMMITTER_DATE
        fi
    fi
    
    # Show remotes
    if [ ${#remotes[@]} -gt 0 ]; then
        echo
        log "Remote URLs restored:"
        git remote -v
    fi
}

# Main execution
log "Clean Git History Rewriter Starting..."

rewrite_history

success "Script completed successfully!"
echo
log "Next steps:"
log "1. Review the generated history: git log --oneline"
log "2. Check file distribution: git log --stat --oneline"
log "3. Force push to remote: git push --force-with-lease origin main"