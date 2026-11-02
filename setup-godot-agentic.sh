#!/bin/bash
# Script name: setup-godot-agentic.sh
# Description: Sets up agentic AI workflow for Godot projects
# Usage: Run this script in the root of a Godot project directory

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
DOCS_BASE_DIR=".docs"
DOCS_DIR=""  # Set dynamically after version detection: .docs/godot-{version}
SKILLS_DIR=".copilot/skills"
DRY_RUN=false
SKIP_DOCS=false
VERBOSE=false
AGENTS_MARKER_START="<!-- setup-godot-agentic:godot-config:start -->"
AGENTS_MARKER_END="<!-- setup-godot-agentic:godot-config:end -->"
README_MARKER_START="<!-- setup-godot-agentic:readme-version:start -->"
README_MARKER_END="<!-- setup-godot-agentic:readme-version:end -->"
SCRIPT_MANAGED_MARKER="# Managed by setup-godot-agentic.sh"
EXPECTED_SKILL_FILES=(
    "godot-scene-creation.md"
    "godot-character-setup.md"
    "godot-signal-connection.md"
    "godot-resource-creation.md"
    "gdscript-patterns.md"
    "godot-state-machine.md"
    "godot-autoload-manager.md"
    "godot-ui-controls.md"
    "godot-save-load.md"
    "godot-input-handling.md"
    "godot-animation-tween.md"
    "godot-navigation-pathfinding.md"
    "godot-shader-basics.md"
    "godot-object-pooling.md"
    "godot-audio-manager.md"
)

HAS_DOCS=false
HAS_VALIDATION_SCRIPT=false
HAS_GUT_FRAMEWORK=false
HAS_GUT_PLUGIN=false
HAS_GUT_CONFIG=false
HAS_TEST_RUNNER=false
HAS_GUT_SKILL=false
MISSING_SKILLS=()

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[→]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_skip() {
    echo -e "${YELLOW}[~]${NC} $1 (already done)"
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Sets up agentic AI workflow for Godot projects. This script configures
version-aware documentation, skill templates, and validation tools to
enable AI agents to work effectively with your Godot project.

OPTIONS:
    -h, --help       Show this help message and exit
    -n, --dry-run    Show what would be done without making changes
    -s, --skip-docs  Skip downloading offline documentation
    -v, --verbose    Enable verbose output

REQUIREMENTS:
    - Must be run from a Godot project directory (containing project.godot)
    - curl or wget (for downloading documentation)
    - unzip (for extracting documentation)

WHAT THIS SCRIPT DOES:
    1. Detects Godot version from project.godot
    2. Creates/updates AGENTS.md with version-specific guidance for AI agents
    3. Downloads offline Godot documentation for the detected version
    4. Creates validation script for headless syntax checking
    5. Sets up reusable Godot skill templates in .copilot/skills/
    6. Configures .gitignore and .gdignore for proper exclusions

This script is idempotent - safe to run multiple times.

EOF
}

# -----------------------------------------------------------------------------
# Argument Parsing
# -----------------------------------------------------------------------------

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                print_warning "Dry run mode - no changes will be made"
                shift
                ;;
            -s|--skip-docs)
                SKIP_DOCS=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Godot Detection Functions
# -----------------------------------------------------------------------------

detect_godot_project() {
    if [[ ! -f "project.godot" ]]; then
        print_error "No project.godot found in current directory."
        print_error "Please run this script from the root of a Godot project."
        exit 1
    fi
    print_success "Godot project detected"
}

parse_godot_version() {
    local version_line
    local version=""
    
    # Try to extract version from config/features line (Godot 4.x format)
    if grep -q 'config/features' project.godot; then
        version=$(grep 'config/features' project.godot | grep -oP '\d+\.\d+' | head -1)
    fi
    
    # Fallback: try config_version (older format)
    if [[ -z "$version" ]] && grep -q 'config_version=' project.godot; then
        local config_ver
        config_ver=$(grep 'config_version=' project.godot | cut -d'=' -f2)
        case $config_ver in
            5) version="4.0" ;;
            4) version="3.x" ;;
            *) version="unknown" ;;
        esac
    fi
    
    if [[ -z "$version" || "$version" == "unknown" ]]; then
        print_warning "Could not auto-detect Godot version"
        read -rp "Enter Godot version (e.g., 4.2): " version
    fi
    
    GODOT_VERSION="$version"
    GODOT_MAJOR_VERSION="${version%%.*}"
    # Set dynamic docs directory based on version
    DOCS_DIR="${DOCS_BASE_DIR}/godot-${GODOT_VERSION}"
    print_success "Detected Godot version: $GODOT_VERSION"
}

file_contains_string() {
    local file="$1"
    local needle="$2"

    [[ -f "$file" ]] && grep -qF "$needle" "$file"
}

file_has_managed_block() {
    local file="$1"
    local start_marker="$2"
    local end_marker="$3"

    file_contains_string "$file" "$start_marker" && file_contains_string "$file" "$end_marker"
}

replace_managed_block() {
    local file="$1"
    local start_marker="$2"
    local end_marker="$3"
    local replacement="$4"
    local temp_file
    local in_block=false
    local replaced=false

    temp_file=$(mktemp)

    if [[ -f "$file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "$start_marker" ]]; then
                if [[ "$replaced" == false ]]; then
                    printf '%s\n' "$replacement" >> "$temp_file"
                    replaced=true
                fi
                in_block=true
                continue
            fi

            if [[ "$in_block" == true && "$line" == "$end_marker" ]]; then
                in_block=false
                continue
            fi

            if [[ "$in_block" == false ]]; then
                printf '%s\n' "$line" >> "$temp_file"
            fi
        done < "$file"

        if [[ "$replaced" == false ]]; then
            [[ -s "$temp_file" ]] && printf '\n' >> "$temp_file"
            printf '%s\n' "$replacement" >> "$temp_file"
        fi
    else
        printf '%s\n' "$replacement" > "$temp_file"
    fi

    mv "$temp_file" "$file"
}

sync_managed_block() {
    local file="$1"
    local start_marker="$2"
    local end_marker="$3"
    local replacement="$4"
    local created_message="$5"
    local updated_message="$6"
    local skip_message="$7"
    local temp_file
    local existed_before=false

    temp_file=$(mktemp)

    if [[ -f "$file" ]]; then
        existed_before=true
        cp "$file" "$temp_file"
    else
        : > "$temp_file"
    fi

    replace_managed_block "$temp_file" "$start_marker" "$end_marker" "$replacement"

    if [[ -f "$file" ]] && cmp -s "$temp_file" "$file"; then
        rm -f "$temp_file"
        print_skip "$skip_message"
        return
    fi

    mv "$temp_file" "$file"

    if [[ "$existed_before" == true ]]; then
        print_success "$updated_message"
    else
        print_success "$created_message"
    fi
}

sync_managed_file() {
    local file="$1"
    local temp_file="$2"
    local legacy_signature="$3"
    local created_message="$4"
    local updated_message="$5"
    local skip_message="$6"

    if [[ ! -f "$file" ]]; then
        mv "$temp_file" "$file"
        print_success "$created_message"
        return
    fi

    if cmp -s "$temp_file" "$file"; then
        rm -f "$temp_file"
        print_skip "$skip_message"
        return
    fi

    if file_contains_string "$file" "$SCRIPT_MANAGED_MARKER" || { [[ -n "$legacy_signature" ]] && file_contains_string "$file" "$legacy_signature"; }; then
        mv "$temp_file" "$file"
        print_success "$updated_message"
        return
    fi

    rm -f "$temp_file"
    print_warning "$file exists and is not recognized as script-managed; leaving it unchanged"
}

docs_are_available() {
    local docs_version_file="${DOCS_DIR}/.version"

    [[ -d "$DOCS_DIR" ]] || return 1

    if [[ -f "$docs_version_file" ]]; then
        local existing_version
        existing_version=$(<"$docs_version_file")
        [[ "$existing_version" == "$GODOT_VERSION" ]] || return 1
    fi

    directory_has_index_html "$DOCS_DIR"
}

directory_has_index_html() {
    local directory="$1"

    [[ -d "$directory" ]] || return 1

    [[ -f "${directory}/index.html" ]] || find "$directory" -maxdepth 2 -type f -name 'index.html' -print -quit | grep -q .
}

script_file_is_available() {
    local file="$1"
    local signature="$2"

    [[ -f "$file" && -s "$file" ]] || return 1

    if [[ -n "$signature" ]]; then
        file_contains_string "$file" "$signature"
    else
        return 0
    fi
}

gut_framework_is_available() {
    [[ -f "addons/gut/gut.gd" && -f "addons/gut/plugin.cfg" ]]
}

gut_config_is_available() {
    [[ -f ".gutconfig.json" ]] || return 1
    grep -qF 'res://test/unit/' ".gutconfig.json" && grep -qF 'res://test/integration/' ".gutconfig.json"
}

gut_plugin_is_enabled() {
    local project_file="${1:-project.godot}"
    local in_editor_plugins=false
    local line=""

    [[ -f "$project_file" ]] || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^\[.*\]$ ]]; then
            if [[ "$line" == "[editor_plugins]" ]]; then
                in_editor_plugins=true
                continue
            fi

            in_editor_plugins=false
        fi

        if [[ "$in_editor_plugins" == true && "$line" == *'res://addons/gut/plugin.cfg'* ]]; then
            return 0
        fi
    done < "$project_file"

    return 1
}

collect_missing_skills() {
    local skill_file

    MISSING_SKILLS=()
    for skill_file in "${EXPECTED_SKILL_FILES[@]}"; do
        if [[ ! -f "${SKILLS_DIR}/${skill_file}" ]]; then
            MISSING_SKILLS+=("$skill_file")
        fi
    done
}

inventory_project_setup() {
    HAS_DOCS=false
    HAS_VALIDATION_SCRIPT=false
    HAS_GUT_FRAMEWORK=false
    HAS_GUT_PLUGIN=false
    HAS_GUT_CONFIG=false
    HAS_TEST_RUNNER=false
    HAS_GUT_SKILL=false

    docs_are_available && HAS_DOCS=true
    script_file_is_available "validate-godot.sh" "# Validates Godot project syntax using headless mode" && HAS_VALIDATION_SCRIPT=true
    gut_framework_is_available && HAS_GUT_FRAMEWORK=true
    gut_plugin_is_enabled "project.godot" && HAS_GUT_PLUGIN=true
    gut_config_is_available && HAS_GUT_CONFIG=true
    script_file_is_available "run-tests.sh" "# Test Runner - Wrapper for GUT (Godot Unit Test)" && HAS_TEST_RUNNER=true
    script_file_is_available "${SKILLS_DIR}/godot-gut-testing.md" "# Godot GUT Testing Skill" && HAS_GUT_SKILL=true
    collect_missing_skills

    if [[ "$VERBOSE" == true || "$DRY_RUN" == true ]]; then
        print_info "Project setup inventory:"
        print_info "  Docs: $([[ "$HAS_DOCS" == true ]] && echo "present" || echo "missing")"
        print_info "  Validation script: $([[ "$HAS_VALIDATION_SCRIPT" == true ]] && echo "present" || echo "missing")"
        print_info "  GUT framework: $([[ "$HAS_GUT_FRAMEWORK" == true ]] && echo "present" || echo "missing")"
        print_info "  GUT plugin: $([[ "$HAS_GUT_PLUGIN" == true ]] && echo "enabled" || echo "missing")"
        print_info "  GUT config: $([[ "$HAS_GUT_CONFIG" == true ]] && echo "present" || echo "missing")"
        print_info "  Test runner: $([[ "$HAS_TEST_RUNNER" == true ]] && echo "present" || echo "missing")"
        print_info "  GUT skill: $([[ "$HAS_GUT_SKILL" == true ]] && echo "present" || echo "missing")"
        print_info "  Core skills missing: ${#MISSING_SKILLS[@]}"

        if [[ "$VERBOSE" == true && ${#MISSING_SKILLS[@]} -gt 0 ]]; then
            local skill_file
            for skill_file in "${MISSING_SKILLS[@]}"; do
                print_info "    - $skill_file"
            done
        fi
    fi
}

# -----------------------------------------------------------------------------
# Documentation Functions
# -----------------------------------------------------------------------------

create_agents_md() {
    local file="AGENTS.md"
    local managed_block=""
    
    # Build structured version block per requirements
    local version_block="PROJECT_GODOT_VERSION=${GODOT_VERSION}
GDSCRIPT_SYNTAX=GDScript 2.0
DOCS_VERSION=${GODOT_VERSION}"
    
    local directives=""
    local node_guidance=""
    if [[ "$GODOT_MAJOR_VERSION" == "4" ]]; then
        version_block="PROJECT_GODOT_VERSION=${GODOT_VERSION}
GDSCRIPT_SYNTAX=GDScript 2.0
PREFERRED_NODES=CharacterBody2D, CharacterBody3D, StaticBody2D, StaticBody3D
DEPRECATED_NODES=KinematicBody2D, KinematicBody, StaticBody (use 2D/3D variants)
DOCS_VERSION=${GODOT_VERSION}"
        directives="- Use only GDScript 2.0 syntax
- Never use Godot 3.x APIs
- Use \`@onready\` instead of \`onready\`
- Use \`@export\` instead of \`export\`
- Always verify signals and properties against official ${GODOT_VERSION} docs
- Reference local documentation in \`${DOCS_DIR}/\` when available"
        node_guidance="| Godot 3.x (Don't Use) | Godot 4.x (Use This) |
|----------------------|---------------------|
| KinematicBody2D | CharacterBody2D |
| KinematicBody | CharacterBody3D |
| Spatial | Node3D |
| Position2D | Marker2D |
| Position3D | Marker3D |
| YSort | Node2D with y_sort_enabled |
| VisibilityNotifier2D | VisibleOnScreenNotifier2D |"
    else
        version_block="PROJECT_GODOT_VERSION=${GODOT_VERSION}
GDSCRIPT_SYNTAX=GDScript 1.0
PREFERRED_NODES=KinematicBody2D, KinematicBody
DOCS_VERSION=${GODOT_VERSION}"
        directives="- Use GDScript 1.0 syntax
- Use KinematicBody2D for 2D characters
- Use KinematicBody for 3D characters
- Always verify signals and properties against official ${GODOT_VERSION} docs"
        node_guidance=""
    fi

    managed_block="${AGENTS_MARKER_START}
## Godot Project Configuration

\`\`\`
$version_block
\`\`\`

### Coding Rules

$directives
${AGENTS_MARKER_END}"
    
    if [[ -f "$file" ]]; then
        if file_has_managed_block "$file" "$AGENTS_MARKER_START" "$AGENTS_MARKER_END"; then
            if [[ "$DRY_RUN" == false ]]; then
                sync_managed_block \
                    "$file" \
                    "$AGENTS_MARKER_START" \
                    "$AGENTS_MARKER_END" \
                    "$managed_block" \
                    "Created AGENTS.md" \
                    "Updated managed Godot configuration in AGENTS.md" \
                    "Managed Godot configuration in AGENTS.md already current"
            fi
            return
        fi

        if grep -q "PROJECT_GODOT_VERSION" "$file"; then
            print_skip "AGENTS.md already has Godot project configuration"
            return
        fi

        if [[ "$DRY_RUN" == false ]]; then
            printf '\n%s\n' "$managed_block" >> "$file"
        fi
        print_success "Updated AGENTS.md with version info"
    else
        if [[ "$DRY_RUN" == false ]]; then
            cat > "$file" << EOF
# AGENTS.md - AI Coding Agent Instructions

> This file provides instructions for AI coding agents (GitHub Copilot, Claude, GPT, etc.) working on this Godot project.

$managed_block

EOF
            # Add node guidance table for Godot 4
            if [[ -n "$node_guidance" ]]; then
                cat >> "$file" << EOF
## Node Type Reference

$node_guidance

EOF
            fi
            
            cat >> "$file" << EOF
## Code Style

- Follow [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- Use type hints for all variables and function parameters
- Use meaningful variable and function names
- Keep functions focused and under 30 lines when possible

## Project Structure

| Directory | Purpose |
|-----------|---------|
| \`scenes/\` | Scene files (.tscn) |
| \`scripts/\` | GDScript files (.gd) |
| \`assets/\` | Images, audio, fonts |
| \`${SKILLS_DIR}/\` | AI skill templates |
| \`${DOCS_DIR}/\` | Offline Godot documentation |

## Before Committing Code

1. Run \`./validate-godot.sh\` to check GDScript syntax
2. Ensure no Godot 3.x APIs are used (if this is a Godot 4 project)
3. Verify signal connections use the new syntax: \`signal.connect(method)\`

## Available Resources

- **Skill Templates**: Check \`${SKILLS_DIR}/\` for patterns on scene creation, character controllers, signals, and resources
- **Offline Docs**: Search \`${DOCS_DIR}/\` for API reference (use grep/ripgrep)
- **Validation**: Run \`./validate-godot.sh\` for syntax checking

## Quick Reference

### Signal Connection (Godot 4)
\`\`\`gdscript
# Connect in code
\$Button.pressed.connect(_on_button_pressed)

# With arguments
\$Timer.timeout.connect(_on_timeout.bind(extra_arg))
\`\`\`

### Export Variables (Godot 4)
\`\`\`gdscript
@export var speed: float = 100.0
@export_range(0, 100) var health: int = 100
@onready var sprite: Sprite2D = \$Sprite2D
\`\`\`

### Physics Process
\`\`\`gdscript
func _physics_process(delta: float) -> void:
    velocity.y += gravity * delta
    move_and_slide()
\`\`\`
EOF
        fi
        print_success "Created AGENTS.md"
    fi
}

update_readme_version() {
    local file="README.md"
    local version_section="${README_MARKER_START}
## Godot Version

This project is built with **Godot ${GODOT_VERSION}**.
${README_MARKER_END}"
    
    if [[ -f "$file" ]]; then
        if file_has_managed_block "$file" "$README_MARKER_START" "$README_MARKER_END"; then
            if [[ "$DRY_RUN" == false ]]; then
                sync_managed_block \
                    "$file" \
                    "$README_MARKER_START" \
                    "$README_MARKER_END" \
                    "$version_section" \
                    "Created README.md Godot version section" \
                    "Updated managed Godot version section in README.md" \
                    "Managed Godot version section in README.md already current"
            fi
            return
        fi

        if grep -q "## Godot Version" "$file" || grep -q "Godot ${GODOT_VERSION}" "$file"; then
            print_skip "README.md already has Godot version info"
            return
        fi
        if [[ "$DRY_RUN" == false ]]; then
            printf '\n%s\n' "$version_section" >> "$file"
        fi
        print_success "Updated README.md with version info"
    else
        print_info "No README.md found - skipping README update"
    fi
}

# -----------------------------------------------------------------------------
# Documentation Download
# -----------------------------------------------------------------------------

# Helper function to validate downloaded documentation
validate_downloaded_docs() {
    local zip_file="$1"
    
    # Check file exists
    if [[ ! -f "$zip_file" ]]; then
        return 1
    fi
    
    local file_size
    file_size=$(stat -c%s "$zip_file" 2>/dev/null || stat -f%z "$zip_file" 2>/dev/null || echo "0")
    
    # Docs should be at least 10MB, if smaller it's likely an error page
    if [[ "$file_size" -lt 10000000 ]]; then
        print_warning "Downloaded file too small (${file_size} bytes) - trying next source"
        return 1
    fi
    
    # Verify it's actually a zip file
    if ! unzip -t "$zip_file" &>/dev/null; then
        print_warning "Downloaded file is not a valid zip - trying next source"
        return 1
    fi
    
    return 0
}

stable_docs_version() {
    command -v curl &> /dev/null || return 0
    # An empty result means "unknown", so a lookup failure must not trip set -e
    curl -sL --fail --max-time 10 "https://docs.godotengine.org/en/stable/" 2>/dev/null \
        | grep -oP 'Godot Docs \S+ \K[0-9]+\.[0-9]+(?= branch)' | head -1 || true
}

download_documentation() {
    local docs_version_file="${DOCS_DIR}/.version"
    local temp_dir=""
    local zip_file=""
    local backup_dir=""
    local -a extracted_entries=()
    
    if docs_are_available; then
        print_skip "Documentation for Godot $GODOT_VERSION already available"
        return
    fi

    if [[ -d "$DOCS_DIR" ]]; then
        print_info "Documentation directory exists but failed quick verification, refreshing it..."
    fi
    
    # Build list of URLs to try (in order of preference)
    local -a docs_urls=()
    local docs_branch=""
    
    # Map version to docs branch
    if [[ "$GODOT_MAJOR_VERSION" == "4" ]]; then
        docs_branch="stable"
    elif [[ "$GODOT_MAJOR_VERSION" == "3" ]]; then
        docs_branch="3.6"
    else
        docs_branch="stable"
    fi

    # Offline builds only track the current stable release, so an older 4.x project would get mismatched docs
    if [[ "$docs_branch" == "stable" ]]; then
        local stable_version
        stable_version=$(stable_docs_version)
        if [[ -n "$stable_version" && "$stable_version" != "$GODOT_VERSION" ]]; then
            print_warning "Offline docs are only published for Godot ${stable_version} (current stable), not ${GODOT_VERSION}"
            print_warning "Use the online docs instead: https://docs.godotengine.org/en/${GODOT_VERSION}/"
            return 1
        fi
    fi

    # Try multiple URL formats (Godot docs hosting has changed over time)
    # 1. GitHub Actions artifacts via nightly.link (most reliable for recent builds)
    docs_urls+=("https://nightly.link/godotengine/godot-docs/workflows/build_offline_docs/master/godot-docs-html-${docs_branch}.zip")
    # 2. Direct Read the Docs download (older format)
    docs_urls+=("https://docs.godotengine.org/en/${docs_branch}/_downloads/en.zip")
    # 3. Alternative RTD format
    docs_urls+=("https://readthedocs.org/projects/godot/downloads/htmlzip/${docs_branch}/")
    
    print_info "Downloading Godot $GODOT_VERSION documentation..."
    print_warning "This may take a few minutes (docs are ~50-350MB)"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would try downloading from multiple sources"
        return
    fi
    
    # Create temp directory for download
    temp_dir=$(mktemp -d)
    zip_file="${temp_dir}/godot-docs.zip"
    trap '[[ -n "${temp_dir:-}" && -d "${temp_dir:-}" ]] && rm -rf "$temp_dir"; trap - RETURN' RETURN
    
    # Try each URL until one succeeds
    local download_success=false
    local tried_urls=0
    
    for docs_url in "${docs_urls[@]}"; do
        tried_urls=$((tried_urls + 1))
        print_info "Trying source $tried_urls/${#docs_urls[@]}: $docs_url"
        
        # Download using curl or wget
        if command -v curl &> /dev/null; then
            if curl -L --fail --progress-bar --connect-timeout 10 -o "$zip_file" "$docs_url" 2>&1; then
                # Validate the download
                if validate_downloaded_docs "$zip_file"; then
                    download_success=true
                    break
                fi
            fi
        elif command -v wget &> /dev/null; then
            if wget --timeout=10 --progress=bar:force -O "$zip_file" "$docs_url" 2>&1; then
                if validate_downloaded_docs "$zip_file"; then
                    download_success=true
                    break
                fi
            fi
        else
            print_error "Neither curl nor wget found. Please install one to download docs."
            return 1
        fi
        
        # Clean up failed download before trying next URL
        rm -f "$zip_file"
    done
    
    if [[ "$download_success" == false ]]; then
        print_error "Failed to download documentation from all sources"
        echo ""
        print_warning "Automatic download failed. To add documentation manually:"
        echo "  1. Visit: https://docs.godotengine.org/en/${docs_branch}/"
        echo "  2. Look for a 'Download' link in the sidebar or footer"
        echo "  3. Or visit: https://github.com/godotengine/godot-docs/actions"
        echo "     and download the 'godot-docs-html-${docs_branch}' artifact"
        echo "  4. Extract the zip contents to: ${DOCS_DIR}/"
        echo "  5. Create a file: ${DOCS_DIR}/.version containing: ${GODOT_VERSION}"
        echo ""
        return 1
    fi
    
    local file_size
    file_size=$(stat -c%s "$zip_file" 2>/dev/null || stat -f%z "$zip_file" 2>/dev/null || echo "0")
    print_success "Download complete ($(numfmt --to=iec "$file_size" 2>/dev/null || echo "${file_size} bytes"))"
    
    # Extract documentation to temp location first (preserve existing on failure)
    print_info "Extracting documentation..."
    local temp_extract_dir="${temp_dir}/extracted"
    mkdir -p "$temp_extract_dir"
    
    if ! unzip -q "$zip_file" -d "$temp_extract_dir"; then
        print_error "Failed to extract documentation (zip may be corrupted or incomplete)"
        print_warning "Existing documentation (if any) has been preserved"
        print_warning "You can manually download docs from: https://docs.godotengine.org"
        return 1
    fi
    
    # Verify extraction produced files
    mapfile -t extracted_entries < <(find "$temp_extract_dir" -mindepth 1 -maxdepth 1 -print)
    if [[ ${#extracted_entries[@]} -eq 0 ]]; then
        print_error "Extraction produced no files (zip may be empty or corrupted)"
        print_warning "Existing documentation (if any) has been preserved"
        return 1
    fi
    
    local final_docs_dir="${temp_dir}/final-docs"
    mkdir -p "$final_docs_dir"

    # Stage extracted contents while preserving dotfiles and nested single-root archives.
    if [[ ${#extracted_entries[@]} -eq 1 && -d "${extracted_entries[0]}" ]]; then
        cp -a "${extracted_entries[0]}/." "$final_docs_dir/"
    else
        cp -a "${temp_extract_dir}/." "$final_docs_dir/"
    fi

    if ! directory_has_index_html "$final_docs_dir"; then
        print_error "Downloaded documentation is missing index.html after extraction"
        return 1
    fi

    printf '%s\n' "$GODOT_VERSION" > "${final_docs_dir}/.version"

    mkdir -p "$DOCS_BASE_DIR"

    if [[ -d "$DOCS_DIR" ]]; then
        backup_dir="${temp_dir}/docs-backup"
        if ! mv "$DOCS_DIR" "$backup_dir"; then
            print_error "Failed to move existing documentation out of the way"
            return 1
        fi
    fi

    if ! mv "$final_docs_dir" "$DOCS_DIR"; then
        print_error "Failed to install documentation into ${DOCS_DIR}/"
        if [[ -n "$backup_dir" && -d "$backup_dir" ]]; then
            mv "$backup_dir" "$DOCS_DIR"
        fi
        return 1
    fi

    rm -rf "$backup_dir" "$temp_dir"
    temp_dir=""
    trap - RETURN

    print_success "Documentation downloaded to $DOCS_DIR/"
}

# -----------------------------------------------------------------------------
# Validation Script
# -----------------------------------------------------------------------------

create_validation_script() {
    local file="validate-godot.sh"
    local temp_file=""
    
    if [[ "$DRY_RUN" == false ]]; then
        temp_file=$(mktemp)
        cat > "$temp_file" << 'EOF'
#!/bin/bash
# Managed by setup-godot-agentic.sh
# Validates Godot project syntax using headless mode
# Usage: ./validate-godot.sh [path/to/script.gd]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Find godot executable
GODOT_CMD="${GODOT_CMD:-}"

if [[ -z "$GODOT_CMD" ]]; then
    for cmd in godot godot4 godot-4 ~/.local/bin/godot /usr/local/bin/godot; do
        if command -v "$cmd" &> /dev/null; then
            GODOT_CMD="$cmd"
            break
        fi
    done
fi

if [[ -z "$GODOT_CMD" ]]; then
    echo -e "${RED}Error: Godot executable not found${NC}"
    echo "Please ensure Godot is installed and in your PATH"
    exit 1
fi

echo "Using: $GODOT_CMD"

if [[ $# -eq 0 ]]; then
    echo "Validating entire project..."
    if "$GODOT_CMD" --headless --check-only; then
        echo -e "${GREEN}Validation passed${NC}"
    else
        echo -e "${RED}Validation failed${NC}"
        exit 1
    fi
else
    echo "Validating: $1"
    if "$GODOT_CMD" --headless --check-only --script "$1"; then
        echo -e "${GREEN}Validation passed${NC}"
    else
        echo -e "${RED}Validation failed${NC}"
        exit 1
    fi
fi
EOF
        chmod +x "$temp_file"
        sync_managed_file \
            "$file" \
            "$temp_file" \
            "# Validates Godot project syntax using headless mode" \
            "Created validate-godot.sh" \
            "Updated validate-godot.sh" \
            "validate-godot.sh already configured"
    else
        print_info "[DRY RUN] Would create or update validate-godot.sh"
    fi
}

# -----------------------------------------------------------------------------
# GUT Testing Framework
# -----------------------------------------------------------------------------

install_gut_framework() {
    local addons_dir="addons"
    local gut_dir="${addons_dir}/gut"
    local temp_dir=""
    local zip_file=""
    local backup_dir=""
    
    # Determine appropriate GUT version based on Godot version
    local gut_version
    # Extract major.minor (e.g., "4.3" from "4.3.1" or "4.3")
    local godot_major_minor
    if [[ "$GODOT_VERSION" =~ ^([0-9]+\.[0-9]+) ]]; then
        godot_major_minor="${BASH_REMATCH[1]}"
    else
        godot_major_minor="$GODOT_VERSION"
    fi
    
    case "$godot_major_minor" in
        4.3)
            gut_version="v9.3.0"
            ;;
        4.4)
            gut_version="v9.4.0"
            ;;
        4.5)
            gut_version="v9.5.0"
            ;;
        4.6)
            gut_version="v9.6.0"
            ;;
        4.7)
            gut_version="v9.7.1"
            ;;
        4.*)
            # Default to latest for other Godot 4.x versions
            gut_version="v9.7.1"
            print_warning "No exact GUT version for Godot ${GODOT_VERSION}, using ${gut_version}"
            ;;
        *)
            print_error "GUT requires Godot 4.x (detected version: $GODOT_VERSION)"
            return 1
            ;;
    esac
    
    if gut_framework_is_available; then
        print_skip "GUT testing framework already installed"
    else
        print_info "Installing GUT ${gut_version} (compatible with Godot ${godot_major_minor})..."

        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$addons_dir"
        fi

        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY RUN] Would download and install GUT ${gut_version}"
        else
            temp_dir=$(mktemp -d)
            zip_file="${temp_dir}/gut.zip"
            local gut_url="https://github.com/bitwes/Gut/archive/refs/tags/${gut_version}.zip"
            trap '[[ -n "${temp_dir:-}" && -d "${temp_dir:-}" ]] && rm -rf "$temp_dir"; trap - RETURN' RETURN

            print_info "Downloading GUT ${gut_version}..."

            if command -v curl &> /dev/null; then
                if ! curl -L --fail --silent --show-error -o "$zip_file" "$gut_url"; then
                    print_error "Failed to download GUT framework"
                    print_warning "You can manually install GUT from: https://github.com/bitwes/Gut"
                    return 1
                fi
            elif command -v wget &> /dev/null; then
                if ! wget -q -O "$zip_file" "$gut_url"; then
                    print_error "Failed to download GUT framework"
                    print_warning "You can manually install GUT from: https://github.com/bitwes/Gut"
                    return 1
                fi
            else
                print_error "Neither curl nor wget found. Please install one to download GUT."
                return 1
            fi

            print_success "Downloaded GUT framework"

            print_info "Extracting GUT framework..."
            local temp_extract="${temp_dir}/extract"
            mkdir -p "$temp_extract"

            if ! unzip -q "$zip_file" -d "$temp_extract"; then
                print_error "Failed to extract GUT framework"
                return 1
            fi

            local extracted_gut
            extracted_gut=$(find "$temp_extract" -type d -name "gut" -path "*/addons/gut" | head -1)

            if [[ -z "$extracted_gut" ]]; then
                print_error "Could not find gut directory in extracted archive"
                return 1
            fi

            local staged_gut_dir="${temp_dir}/gut-stage"
            mkdir -p "$staged_gut_dir"
            cp -a "${extracted_gut}/." "$staged_gut_dir/"

            if [[ ! -f "${staged_gut_dir}/gut.gd" || ! -f "${staged_gut_dir}/plugin.cfg" ]]; then
                print_error "Extracted GUT framework is missing required files"
                return 1
            fi

            if [[ -e "$gut_dir" ]]; then
                backup_dir="${temp_dir}/gut-backup"
                if ! mv "$gut_dir" "$backup_dir"; then
                    print_error "Failed to move existing ${gut_dir} out of the way"
                    return 1
                fi
            fi

            if ! mv "$staged_gut_dir" "$gut_dir"; then
                print_error "Failed to install GUT framework into ${gut_dir}/"
                if [[ -n "$backup_dir" && -e "$backup_dir" ]]; then
                    mv "$backup_dir" "$gut_dir"
                fi
                return 1
            fi

            rm -rf "$backup_dir" "$temp_dir"
            temp_dir=""
            trap - RETURN

            print_success "Installed GUT framework to ${gut_dir}/"
        fi
    fi
    
    # Create test directory structure
    local test_dir="test"
    local test_unit_dir="${test_dir}/unit"
    local test_integration_dir="${test_dir}/integration"
    
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$test_unit_dir"
        mkdir -p "$test_integration_dir"
    fi
    
    # Create example test file
    if [[ ! -f "${test_unit_dir}/test_example.gd" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            cat > "${test_unit_dir}/test_example.gd" << 'EOF'
extends GutTest
# Example unit test
# Run tests via: Project -> Tools -> Gut panel (after enabling plugin)
# Or via CLI: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit

func test_example_pass():
    assert_eq(1 + 1, 2, "Basic math should work")

func test_example_string():
    var text = "Hello"
    assert_eq(text.length(), 5, "String length should be 5")

func test_vector_operations():
    var vec = Vector2(3, 4)
    assert_almost_eq(vec.length(), 5.0, 0.01, "Vector magnitude should be 5")
EOF
        fi
        print_success "Created example test: ${test_unit_dir}/test_example.gd"
    fi
    
    # Create .gutconfig.json
    if gut_config_is_available; then
        print_skip ".gutconfig.json already configured"
    elif [[ ! -f ".gutconfig.json" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            cat > ".gutconfig.json" << EOF
{
  "dirs": [
    "res://test/unit/",
    "res://test/integration/"
  ],
  "include_subdirs": true,
  "prefix": "test_",
  "suffix": ".gd"
}
EOF
        fi
        print_success "Created .gutconfig.json"
    else
        print_warning ".gutconfig.json exists but does not match the expected setup; leaving it unchanged"
    fi
    
    # Create a skill template for GUT testing
    if [[ ! -f "${SKILLS_DIR}/godot-gut-testing.md" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "${SKILLS_DIR}"
            cat > "${SKILLS_DIR}/godot-gut-testing.md" << 'EOF'
# Godot GUT Testing Skill

Unit testing with GUT (Godot Unit Test) framework for Godot 4.x.

## Test Structure

All tests extend `GutTest` and use `test_` prefix:

```gdscript
extends GutTest

func test_player_health():
    var player = Player.new()
    player.health = 100
    player.take_damage(30)
    assert_eq(player.health, 70, "Player should have 70 health")
```

## Common Assertions

| Assertion | Purpose |
|-----------|---------|
| `assert_eq(got, expected, msg)` | Values are equal |
| `assert_ne(got, not_expected, msg)` | Values are not equal |
| `assert_true(value, msg)` | Value is true |
| `assert_false(value, msg)` | Value is false |
| `assert_null(value, msg)` | Value is null |
| `assert_not_null(value, msg)` | Value is not null |
| `assert_almost_eq(got, expected, delta, msg)` | Float comparison |
| `assert_gt(got, expected, msg)` | Greater than |
| `assert_lt(got, expected, msg)` | Less than |
| `assert_has(container, element, msg)` | Container has element |
| `assert_does_not_have(container, element, msg)` | Container lacks element |

## Test Lifecycle Hooks

```gdscript
extends GutTest

func before_all():
    # Run once before all tests in this script
    pass

func before_each():
    # Run before each test
    pass

func after_each():
    # Run after each test
    pass

func after_all():
    # Run once after all tests
    pass
```

## Testing Example: Player Character

```gdscript
# test/unit/test_player.gd
extends GutTest

var player: Player

func before_each():
    player = Player.new()
    add_child_autofree(player)  # Auto-cleanup after test

func test_initial_health():
    assert_eq(player.health, 100, "Player starts with 100 health")

func test_take_damage():
    player.take_damage(25)
    assert_eq(player.health, 75, "Player health reduced by damage")

func test_death():
    player.health = 10
    player.take_damage(20)
    assert_true(player.is_dead, "Player should be dead")
    assert_eq(player.health, 0, "Health should not go below 0")

func test_heal():
    player.health = 50
    player.heal(30)
    assert_eq(player.health, 80, "Player healed by 30")
    
func test_heal_max_cap():
    player.health = 95
    player.heal(20)
    assert_eq(player.health, 100, "Healing capped at max health")
```

## Testing Signals

```gdscript
func test_health_changed_signal():
    watch_signals(player)
    player.take_damage(10)
    assert_signal_emitted(player, "health_changed", "Should emit health_changed")
    assert_signal_emit_count(player, "health_changed", 1)

func test_signal_with_parameters():
    watch_signals(player)
    player.take_damage(25)
    assert_signal_emitted_with_parameters(
        player, 
        "health_changed", 
        [75],  # Expected parameters
        "Signal should emit with correct health value"
    )
```

## Testing Scene Instantiation

```gdscript
func test_enemy_spawning():
    var enemy_scene = preload("res://entities/enemy.tscn")
    var enemy = enemy_scene.instantiate()
    add_child_autofree(enemy)
    
    assert_not_null(enemy, "Enemy should instantiate")
    assert_true(enemy is Enemy, "Should be Enemy class")
    assert_eq(enemy.health, 50, "Enemy starts with 50 health")
```

## Mocking and Doubling

```gdscript
func test_with_double():
    var double = double(Player).new()
    stub(double, "get_position").to_return(Vector2(100, 200))
    
    assert_eq(double.get_position(), Vector2(100, 200))
    assert_called(double, "get_position")
```

## Parameterized Tests (Inner Classes)

```gdscript
extends GutTest

class TestDamageCalculation:
    extends GutTest
    
    func test_normal_damage():
        var calc = DamageCalculator.new()
        assert_eq(calc.calculate(10, 1.0), 10)
    
    func test_critical_damage():
        var calc = DamageCalculator.new()
        assert_eq(calc.calculate(10, 2.0), 20)
    
    func test_reduced_damage():
        var calc = DamageCalculator.new()
        assert_eq(calc.calculate(10, 0.5), 5)
```

## Running Tests

### From Editor:
1. Enable GUT plugin: **Project → Project Settings → Plugins → Gut**
2. Open **GUT** panel at bottom of editor
3. Click **Run All** or select specific test

### From Command Line:
```bash
# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd

# Run specific directory
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/

# Run specific test file
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_player.gd

# Use config file
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```

## Best Practices

- **Test in isolation**: Use `add_child_autofree()` for automatic cleanup
- **Test one thing**: Each test should verify one specific behavior
- **Use descriptive names**: `test_player_takes_damage_reduces_health()`
- **Setup/teardown**: Use `before_each()` and `after_each()` for shared setup
- **Mock dependencies**: Use doubles to isolate the unit under test
- **Test edge cases**: Zero, negative, max values, null inputs
- **Run tests frequently**: Integrate into your development workflow
- **CI/CD integration**: Run tests automatically on commit/push

## Directory Structure

```
res://
├── addons/
│   └── gut/              # GUT framework
├── test/
│   ├── unit/             # Unit tests (isolated)
│   │   ├── test_player.gd
│   │   ├── test_enemy.gd
│   │   └── test_inventory.gd
│   └── integration/      # Integration tests (multiple systems)
│       └── test_combat_system.gd
└── .gutconfig.json       # GUT configuration
```

## Example: Testing a Weapon System

```gdscript
# test/unit/test_weapon.gd
extends GutTest

var weapon: Weapon
var target: CharacterBody2D

func before_each():
    weapon = Weapon.new()
    weapon.damage = 15
    weapon.attack_speed = 1.0
    add_child_autofree(weapon)
    
    target = CharacterBody2D.new()
    target.set_script(preload("res://scripts/damageable.gd"))
    add_child_autofree(target)

func test_weapon_deals_damage():
    var initial_health = target.health
    weapon.attack(target)
    assert_eq(target.health, initial_health - 15, "Target takes weapon damage")

func test_attack_cooldown():
    weapon.attack(target)
    var can_attack_immediately = weapon.can_attack()
    assert_false(can_attack_immediately, "Cannot attack during cooldown")
    
    await get_tree().create_timer(1.1).timeout
    assert_true(weapon.can_attack(), "Can attack after cooldown")

func test_weapon_with_no_target():
    weapon.attack(null)
    # Should not crash, verify it handles gracefully
    assert_true(true, "Weapon handles null target")
EOF
        fi
        print_success "Created GUT testing skill: ${SKILLS_DIR}/godot-gut-testing.md"
    fi
    
    # Auto-enable GUT plugin in project.godot
    enable_gut_plugin
    
    # Create test runner script
    create_test_runner_script
    
    print_info ""
    print_info "GUT testing setup is ready."
    if gut_plugin_is_enabled "project.godot"; then
        print_info "GUT plugin is enabled in project.godot"
    else
        print_warning "GUT plugin may need manual enablement in project.godot"
    fi
    if [[ -f "${test_unit_dir}/test_example.gd" ]]; then
        print_info "Example test available: ${test_unit_dir}/test_example.gd"
    fi
    print_info "Run tests: ./run-tests.sh"
}

# Enable GUT plugin in project.godot
enable_gut_plugin() {
    local project_file="project.godot"
    local temp_file=""
    
    if [[ ! -f "$project_file" ]]; then
        print_warning "project.godot not found, skipping plugin auto-enable"
        return
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would enable GUT plugin in project.godot"
        return
    fi
    
    if gut_plugin_is_enabled "$project_file"; then
        print_skip "GUT plugin already enabled in project.godot"
        return
    fi
    
    print_info "Enabling GUT plugin in project.godot..."
    
    if grep -q '^\[editor_plugins\]' "$project_file"; then
        local enabled_line=""
        local in_editor_plugins=false
        local line=""

        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^\[.*\]$ ]]; then
                if [[ "$line" == "[editor_plugins]" ]]; then
                    in_editor_plugins=true
                    continue
                fi

                if [[ "$in_editor_plugins" == true ]]; then
                    break
                fi

                in_editor_plugins=false
            fi

            if [[ "$in_editor_plugins" == true && "$line" == enabled=* ]]; then
                enabled_line="$line"
                break
            fi
        done < "$project_file"

        temp_file=$(mktemp)

        if [[ -z "$enabled_line" ]]; then
            awk '
                {
                    print
                    if ($0 == "[editor_plugins]") {
                        print "enabled=PackedStringArray(\"res://addons/gut/plugin.cfg\")"
                    }
                }
            ' "$project_file" > "$temp_file"
            mv "$temp_file" "$project_file"
        elif [[ "$enabled_line" =~ ^enabled=PackedStringArray\(.*\)$ ]]; then
            awk '
                BEGIN { in_editor_plugins = 0; updated = 0 }
                /^\[editor_plugins\]$/ {
                    in_editor_plugins = 1
                    print
                    next
                }
                /^\[.*\]$/ {
                    in_editor_plugins = 0
                }
                in_editor_plugins && /^enabled=PackedStringArray\(.*\)$/ && updated == 0 {
                    sub(/\)$/, ", \"res://addons/gut/plugin.cfg\")")
                    updated = 1
                    print
                    next
                }
                { print }
            ' "$project_file" > "$temp_file"
            mv "$temp_file" "$project_file"
        else
            rm -f "$temp_file"
            print_warning "Could not safely update [editor_plugins] in project.godot; please add res://addons/gut/plugin.cfg manually"
            return
        fi
    else
        echo "" >> "$project_file"
        echo "[editor_plugins]" >> "$project_file"
        echo "" >> "$project_file"
        echo 'enabled=PackedStringArray("res://addons/gut/plugin.cfg")' >> "$project_file"
    fi
    
    print_success "Enabled GUT plugin in project.godot"
}

# Create test runner script
create_test_runner_script() {
    local script_name="run-tests.sh"
    local temp_file=""
    
    if [[ "$DRY_RUN" == false ]]; then
        temp_file=$(mktemp)
        cat > "$temp_file" << 'EOF'
#!/bin/bash
# Managed by setup-godot-agentic.sh
# Test Runner - Wrapper for GUT (Godot Unit Test)
# Usage:
#   ./run-tests.sh                    # Run all tests
#   ./run-tests.sh test/unit/         # Run all tests in directory
#   ./run-tests.sh test/unit/test_player.gd  # Run specific test file

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Find Godot executable
GODOT_CMD="${GODOT_CMD:-}"

if [[ -z "$GODOT_CMD" ]]; then
    for cmd in godot godot4 Godot /Applications/Godot.app/Contents/MacOS/Godot; do
        if command -v "$cmd" &> /dev/null || [[ -x "$cmd" ]]; then
            GODOT_CMD="$cmd"
            break
        fi
    done
fi

if [[ -z "$GODOT_CMD" ]]; then
    echo -e "${RED}Error: Godot executable not found${NC}"
    echo "Please ensure Godot is installed and in your PATH"
    echo "Or set GODOT_CMD environment variable to the Godot executable path"
    exit 1
fi

echo -e "${BLUE}GUT Test Runner${NC}"
echo "Using: $GODOT_CMD"
echo ""

# Base GUT command
GUT_CMD=("$GODOT_CMD" --headless -s addons/gut/gut_cmdln.gd)

# Parse arguments
if [[ $# -eq 0 ]]; then
    # Run all tests using config file
    echo -e "${YELLOW}Running all tests...${NC}"
    if "${GUT_CMD[@]}" -gconfig=.gutconfig.json; then
        EXIT_CODE=0
    else
        EXIT_CODE=$?
    fi
else
    # Run specific test(s)
    ARG="$1"
    
    if [[ -d "$ARG" ]]; then
        # Directory provided
        echo -e "${YELLOW}Running tests in: $ARG${NC}"
        if "${GUT_CMD[@]}" -gdir="res://${ARG#./}"; then
            EXIT_CODE=0
        else
            EXIT_CODE=$?
        fi
    elif [[ -f "$ARG" ]]; then
        # File provided
        echo -e "${YELLOW}Running test file: $ARG${NC}"
        if "${GUT_CMD[@]}" -gtest="res://${ARG#./}"; then
            EXIT_CODE=0
        else
            EXIT_CODE=$?
        fi
    else
        echo -e "${RED}Error: '$ARG' is not a valid file or directory${NC}"
        exit 1
    fi
fi

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
else
    echo -e "${RED}✗ Some tests failed${NC}"
fi

exit $EXIT_CODE
EOF
        chmod +x "$temp_file"
        sync_managed_file \
            "$script_name" \
            "$temp_file" \
            "# Test Runner - Wrapper for GUT (Godot Unit Test)" \
            "Created test runner script: $script_name" \
            "Updated test runner script: $script_name" \
            "Test runner script already configured"
    else
        print_info "[DRY RUN] Would create or update ${script_name}"
    fi
}

# -----------------------------------------------------------------------------
# Skills Setup
# -----------------------------------------------------------------------------

setup_skills() {
    local final_skills_dir="$SKILLS_DIR"
    local temp_dir=""
    local generated_skills_dir=""
    local created_count=0
    local skill_file=""

    collect_missing_skills

    if [[ ${#MISSING_SKILLS[@]} -eq 0 ]]; then
        print_skip "Core skill templates already available"
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would create ${#MISSING_SKILLS[@]} missing skill template(s) in ${final_skills_dir}/"
        return
    fi

    temp_dir=$(mktemp -d)
    generated_skills_dir="${temp_dir}/skills"
    mkdir -p "$generated_skills_dir"
    local SKILLS_DIR="$generated_skills_dir"

        # Create scene creation skill (godot-scene-creation.md)
        cat > "${SKILLS_DIR}/godot-scene-creation.md" << 'EOF'
# Godot Scene Creation Skill

When creating a new Godot scene:

1. **Specify root node type explicitly**
   - Use Node2D for 2D scenes, Node3D for 3D scenes
   - Use Control for UI scenes
   - Use specific types like CharacterBody2D when appropriate

2. **Use only Godot 4.x node names** (no Godot 3 equivalents)
   - CharacterBody2D (not KinematicBody2D)
   - CharacterBody3D (not KinematicBody)
   - AnimationPlayer, AnimationTree
   - Use @onready and @export annotations

3. **Provide complete .tscn structure** with all child nodes and properties
   ```
   [gd_scene load_steps=2 format=3]
   
   [ext_resource type="Script" path="res://path/to/script.gd" id="1"]
   
   [node name="Root" type="Node2D"]
   script = ExtResource("1")
   
   [node name="Child" type="Sprite2D" parent="."]
   position = Vector2(100, 100)
   ```

4. **Provide attached GDScript separately** in a .gd file
   - Use class_name for reusable scripts
   - Follow GDScript style guide
   - Use type hints for all variables and functions

5. **Connect all signals using `node.signal.connect(target_method)` syntax**
   ```gdscript
   func _ready() -> void:
       $Button.pressed.connect(_on_button_pressed)
   ```

6. **Use `@export` and `@onready` decorators** for exposed properties
   ```gdscript
   @export var speed: float = 100.0
   @onready var sprite: Sprite2D = $Sprite2D
   ```
EOF
        
        # Create character setup skill (godot-character-setup.md)
        cat > "${SKILLS_DIR}/godot-character-setup.md" << 'EOF'
# Godot Character Setup Skill

CharacterBody2D implementation pattern for Godot 4.x:

## Scene Structure

```
CharacterBody2D (root)
├── CollisionShape2D
├── Sprite2D or AnimatedSprite2D
└── (optional) Camera2D
```

## Controller Script

```gdscript
extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Get the gravity from the project settings
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
    # Add gravity
    if not is_on_floor():
        velocity.y += gravity * delta

    # Handle jump
    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    # Get input direction
    var direction := Input.get_axis("ui_left", "ui_right")
    if direction:
        velocity.x = direction * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)

    move_and_slide()
```

## Key Points

- Use `CharacterBody2D` as root node (not KinematicBody2D)
- Implement `_physics_process(delta)` method
- Use `move_and_slide()` for movement (returns nothing in Godot 4)
- Store velocity as built-in property (no need to declare)
- Handle delta time correctly: `velocity.y += gravity * delta`
- Use `is_on_floor()`, `is_on_wall()`, `is_on_ceiling()` for collision checks
- Get gravity from ProjectSettings for consistency with RigidBody2D
EOF
        
        # Create signal connection skill (godot-signal-connection.md)
        cat > "${SKILLS_DIR}/godot-signal-connection.md" << 'EOF'
# Godot Signal Connection Skill

Programmatic signal binding patterns for Godot 4.x:

## Connecting Signals in Code

```gdscript
func _ready() -> void:
    # Connect to a signal with a method
    $Button.pressed.connect(_on_button_pressed)
    
    # Connect with arguments using bind()
    $Button.pressed.connect(_on_button_pressed.bind("extra_arg"))
    
    # Connect with flags
    $Timer.timeout.connect(_on_timer_timeout, CONNECT_ONE_SHOT)
```

## Defining Custom Signals

```gdscript
# Signal without parameters
signal died

# Signal with parameters (use type hints)
signal health_changed(new_health: int)
signal damage_taken(amount: int, source: Node)

# Emitting signals
func take_damage(amount: int, source: Node) -> void:
    health -= amount
    damage_taken.emit(amount, source)
    health_changed.emit(health)
    if health <= 0:
        died.emit()
```

## Awaiting Signals

```gdscript
# Wait for a timer
await get_tree().create_timer(1.0).timeout

# Wait for animation to finish
await $AnimationPlayer.animation_finished

# Wait for custom signal
await some_node.my_custom_signal
```

## Connection in Scene Files (.tscn)

```
[connection signal="pressed" from="Button" to="." method="_on_button_pressed"]
[connection signal="body_entered" from="Area2D" to="." method="_on_area_body_entered"]
```

## Disconnecting Signals

```gdscript
# Disconnect a specific connection
$Button.pressed.disconnect(_on_button_pressed)

# Check if connected before disconnecting
if $Button.pressed.is_connected(_on_button_pressed):
    $Button.pressed.disconnect(_on_button_pressed)
```

## Lambda/Callable Connections

```gdscript
# Using lambda for simple inline handlers
$Button.pressed.connect(func(): print("Button pressed!"))

# Using Callable for dynamic connections
var callable := Callable(self, "_on_button_pressed")
$Button.pressed.connect(callable)
```
EOF
        
        # Create resource creation skill (godot-resource-creation.md)
        cat > "${SKILLS_DIR}/godot-resource-creation.md" << 'EOF'
# Godot Resource Creation Skill

Creating custom resources programmatically in Godot 4.x:

## Defining a Custom Resource

```gdscript
# item_data.gd
class_name ItemData
extends Resource

@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var value: int = 0
@export var stackable: bool = true
@export var max_stack: int = 99
```

## Resource File Format (.tres)

```
[gd_resource type="Resource" script_class="ItemData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/item_data.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/icons/sword.png" id="2"]

[resource]
script = ExtResource("1")
name = "Iron Sword"
description = "A sturdy iron sword."
icon = ExtResource("2")
value = 100
stackable = false
max_stack = 1
```

## Creating Resources in Code

```gdscript
# Create a new resource instance
var item := ItemData.new()
item.name = "Health Potion"
item.value = 50

# Save resource to file
ResourceSaver.save(item, "res://data/items/health_potion.tres")

# Load resource from file
var loaded_item := load("res://data/items/health_potion.tres") as ItemData
```

## Using Resources in Exports

```gdscript
# In a script that uses the resource
@export var weapon_data: ItemData
@export var inventory: Array[ItemData] = []

func _ready() -> void:
    if weapon_data:
        print("Equipped: ", weapon_data.name)
```

## Sub-Resources

```gdscript
# Resource containing other resources
class_name CharacterStats
extends Resource

@export var base_stats: Resource  # Another custom resource
@export var abilities: Array[Resource] = []
```

## Resource Preloading

```gdscript
# Preload for compile-time loading (faster)
const SWORD_DATA := preload("res://data/items/sword.tres")

# Load for runtime loading
var item_data := load("res://data/items/" + item_name + ".tres")
```
EOF
        
        # Create GDScript patterns skill (bonus - not in requirements but useful)
        cat > "${SKILLS_DIR}/gdscript-patterns.md" << 'EOF'
# GDScript 2.0 Patterns Skill

## Type Hints

Always use type hints for clarity:

```gdscript
var health: int = 100
var player_name: String = "Hero"
var items: Array[Item] = []
var stats: Dictionary = {}

func calculate_damage(base: int, multiplier: float) -> int:
    return int(base * multiplier)
```

## Annotations

```gdscript
@onready var sprite: Sprite2D = $Sprite2D
@export var speed: float = 100.0
@export_range(0, 100) var health: int = 100
@export_group("Movement")
@export var jump_height: float = 200.0
```

## Signals

```gdscript
signal health_changed(new_health: int)
signal died

func take_damage(amount: int) -> void:
    health -= amount
    health_changed.emit(health)
    if health <= 0:
        died.emit()
```

## Awaiting Signals

```gdscript
await get_tree().create_timer(1.0).timeout
await animation_player.animation_finished
```

## Super Calls

```gdscript
func _ready() -> void:
    super._ready()  # Call parent implementation
    # Your code here
```

## Static Typing

```gdscript
# Prefer static typing for better performance and error checking
var enemies: Array[Enemy] = []
var player: Player = null

func get_closest_enemy() -> Enemy:
    # Return type is explicit
    return enemies[0] if enemies.size() > 0 else null
```
EOF

        # Create state machine skill
        cat > "${SKILLS_DIR}/godot-state-machine.md" << 'EOF'
# Godot State Machine Skill

Finite State Machine (FSM) patterns for Godot 4.x game AI and player controllers.

## Simple State Machine (Enum-based)

For simple cases with few states:

```gdscript
extends CharacterBody2D

enum State { IDLE, RUNNING, JUMPING, FALLING }
var current_state: State = State.IDLE

func _physics_process(delta: float) -> void:
    match current_state:
        State.IDLE:
            _state_idle(delta)
        State.RUNNING:
            _state_running(delta)
        State.JUMPING:
            _state_jumping(delta)
        State.FALLING:
            _state_falling(delta)

func _state_idle(_delta: float) -> void:
    if Input.is_action_pressed("move_right") or Input.is_action_pressed("move_left"):
        current_state = State.RUNNING
    if Input.is_action_just_pressed("jump") and is_on_floor():
        current_state = State.JUMPING

func _state_running(_delta: float) -> void:
    if not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left"):
        current_state = State.IDLE

func _state_jumping(_delta: float) -> void:
    if velocity.y > 0:
        current_state = State.FALLING

func _state_falling(_delta: float) -> void:
    if is_on_floor():
        current_state = State.IDLE
```

## Node-Based State Machine (Scalable)

For complex AI or characters, use separate State nodes:

**Directory Structure:**
```
Player.tscn
  └── StateMachine (Node)
       ├── IdleState (Node)
       ├── RunState (Node)
       └── JumpState (Node)
```

**StateMachine.gd:**
```gdscript
extends Node
class_name StateMachine

var current_state: State = null
var states: Dictionary = {}

@export var initial_state: NodePath

func _ready() -> void:
    for child in get_children():
        if child is State:
            states[child.name] = child
            child.state_machine = self
    
    if initial_state:
        current_state = get_node(initial_state)
        current_state.enter()

func change_state(new_state_name: String) -> void:
    if current_state:
        current_state.exit()
    current_state = states.get(new_state_name)
    if current_state:
        current_state.enter()

func _process(delta: float) -> void:
    if current_state:
        current_state.update(delta)

func _physics_process(delta: float) -> void:
    if current_state:
        current_state.physics_update(delta)
```

**State.gd (Base Class):**
```gdscript
extends Node
class_name State

var state_machine: StateMachine = null

func enter() -> void:
    pass

func exit() -> void:
    pass

func update(_delta: float) -> void:
    pass

func physics_update(_delta: float) -> void:
    pass
```

**IdleState.gd (Example):**
```gdscript
extends State

func enter() -> void:
    # Play idle animation
    pass

func physics_update(_delta: float) -> void:
    if Input.is_action_pressed("move_right"):
        state_machine.change_state("RunState")
    if Input.is_action_just_pressed("jump"):
        state_machine.change_state("JumpState")
```

## Best Practices

- Use enum-based FSM for simple cases (< 5 states)
- Use node-based FSM for complex AI or extensible systems
- Always implement `enter()` and `exit()` for setup/cleanup
- Keep state logic isolated - states should not know about each other's internals
- Use signals for state change notifications if needed
EOF

        # Create autoload/singleton manager skill
        cat > "${SKILLS_DIR}/godot-autoload-manager.md" << 'EOF'
# Godot Autoload Manager Skill

Singleton pattern using Godot 4's Autoload system for global managers.

## Creating a Game Manager

**GameManager.gd:**
```gdscript
extends Node

# Signals for state changes
signal score_changed(new_score: int)
signal game_paused(is_paused: bool)
signal game_over

# Game state
var score: int = 0:
    set(value):
        score = value
        score_changed.emit(score)

var is_paused: bool = false
var current_level: int = 1

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS  # Run even when paused

func add_score(points: int) -> void:
    score += points

func pause_game() -> void:
    is_paused = true
    get_tree().paused = true
    game_paused.emit(true)

func resume_game() -> void:
    is_paused = false
    get_tree().paused = false
    game_paused.emit(false)

func reset_game() -> void:
    score = 0
    current_level = 1
    is_paused = false
```

## Registering as Autoload

1. Go to **Project > Project Settings > Autoload**
2. Browse for your script (e.g., `GameManager.gd`)
3. Set the Node Name (e.g., `GameManager`)
4. Click **Add**

## Accessing the Singleton

```gdscript
# From any script in your project
GameManager.add_score(100)
print(GameManager.score)

# Connect to signals
GameManager.score_changed.connect(_on_score_changed)
```

## Common Manager Types

### AudioManager.gd
```gdscript
extends Node

var music_volume: float = 1.0
var sfx_volume: float = 1.0

func play_music(stream: AudioStream) -> void:
    # Implementation
    pass

func play_sfx(stream: AudioStream) -> void:
    # Implementation
    pass
```

### SaveManager.gd
```gdscript
extends Node

const SAVE_PATH := "user://savegame.json"

func save_game(data: Dictionary) -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))

func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    return JSON.parse_string(file.get_as_text())
```

## Best Practices

- Keep singletons focused on one responsibility
- Use signals for decoupled communication
- Set `process_mode = PROCESS_MODE_ALWAYS` for managers that need to run during pause
- Avoid putting game logic in managers - they should coordinate, not implement
- Consider using an EventBus singleton for global event handling
EOF

        # Create UI/Control nodes skill
        cat > "${SKILLS_DIR}/godot-ui-controls.md" << 'EOF'
# Godot UI Controls Skill

Building user interfaces with Control nodes in Godot 4.x.

## UI Node Hierarchy

```
CanvasLayer (for UI overlay)
  └── Control (root UI container)
       ├── MarginContainer
       │    └── VBoxContainer
       │         ├── Label
       │         ├── Button
       │         └── HBoxContainer
       └── Panel
```

## Container Types

| Container | Purpose |
|-----------|---------|
| VBoxContainer | Vertical layout |
| HBoxContainer | Horizontal layout |
| GridContainer | Grid layout |
| MarginContainer | Add margins around content |
| CenterContainer | Center child in available space |
| PanelContainer | Visual panel with child |
| ScrollContainer | Scrollable area |

## Anchors and Size Flags

```gdscript
# Full screen UI
control.anchor_left = 0.0
control.anchor_top = 0.0
control.anchor_right = 1.0
control.anchor_bottom = 1.0

# Size flags for containers
control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
```

## Creating UI in Code

```gdscript
func create_menu() -> Control:
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    
    var vbox := VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_CENTER)
    root.add_child(vbox)
    
    var title := Label.new()
    title.text = "Main Menu"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    var play_btn := Button.new()
    play_btn.text = "Play"
    play_btn.pressed.connect(_on_play_pressed)
    vbox.add_child(play_btn)
    
    return root
```

## Theme Styling

```gdscript
# Apply theme to all children
var theme := Theme.new()
theme.set_font_size("font_size", "Button", 24)
theme.set_color("font_color", "Button", Color.WHITE)
control.theme = theme
```

## Common UI Patterns

### Health Bar
```gdscript
@onready var health_bar: ProgressBar = $HealthBar

func update_health(current: int, maximum: int) -> void:
    health_bar.max_value = maximum
    health_bar.value = current
```

### Dialog Box
```gdscript
func show_dialog(text: String) -> void:
    $DialogPanel.visible = true
    $DialogPanel/Label.text = text
    await get_tree().create_timer(2.0).timeout
    $DialogPanel.visible = false
```

## Best Practices

- Use containers instead of manual positioning
- Set anchors for responsive layouts
- Use themes for consistent styling
- Keep UI logic separate from game logic
- Use CanvasLayer to keep UI above game elements
EOF

        # Create save/load system skill
        cat > "${SKILLS_DIR}/godot-save-load.md" << 'EOF'
# Godot Save/Load System Skill

Implementing game save and load functionality in Godot 4.x.

## JSON-Based Save System

### SaveManager.gd (Autoload)
```gdscript
extends Node

const SAVE_PATH := "user://savegame.json"

signal game_saved
signal game_loaded

func save_game(data: Dictionary) -> bool:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("Could not open save file: %s" % FileAccess.get_open_error())
        return false
    
    var json_string := JSON.stringify(data, "\t")  # Pretty print
    file.store_string(json_string)
    file.close()
    game_saved.emit()
    return true

func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return {}
    
    var json_string := file.get_as_text()
    file.close()
    
    var data = JSON.parse_string(json_string)
    if data == null:
        push_error("Failed to parse save file")
        return {}
    
    game_loaded.emit()
    return data

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
    if has_save():
        DirAccess.remove_absolute(SAVE_PATH)
```

### Usage Example
```gdscript
# Saving
func _on_save_pressed() -> void:
    var save_data := {
        "version": 1,
        "player": {
            "position": {"x": player.position.x, "y": player.position.y},
            "health": player.health,
            "inventory": player.inventory
        },
        "level": current_level,
        "playtime": playtime_seconds
    }
    SaveManager.save_game(save_data)

# Loading
func _on_load_pressed() -> void:
    var data := SaveManager.load_game()
    if data.is_empty():
        print("No save found")
        return
    
    player.position = Vector2(data.player.position.x, data.player.position.y)
    player.health = data.player.health
    current_level = data.level
```

## Resource-Based Save System

### PlayerData.gd (Custom Resource)
```gdscript
extends Resource
class_name PlayerData

@export var player_name: String = ""
@export var health: int = 100
@export var position: Vector2 = Vector2.ZERO
@export var inventory: Array[String] = []
```

### Saving/Loading Resources
```gdscript
const SAVE_PATH := "user://player_data.tres"

func save_player_data(data: PlayerData) -> void:
    var error := ResourceSaver.save(data, SAVE_PATH)
    if error != OK:
        push_error("Failed to save: %s" % error)

func load_player_data() -> PlayerData:
    if ResourceLoader.exists(SAVE_PATH):
        return ResourceLoader.load(SAVE_PATH) as PlayerData
    return PlayerData.new()  # Return default
```

## Best Practices

- Always save to `user://` (writable on all platforms)
- Include a version number for save format migrations
- Handle missing or corrupted files gracefully
- Use JSON for human-readable saves, Resources for complex data
- Consider encryption for sensitive data
- Implement autosave with a timer
EOF

        # Create input handling skill
        cat > "${SKILLS_DIR}/godot-input-handling.md" << 'EOF'
# Godot Input Handling Skill

Input system patterns for Godot 4.x games.

## Input Map Actions

Define actions in **Project > Project Settings > Input Map**:
- `move_left`, `move_right`, `move_up`, `move_down`
- `jump`, `attack`, `interact`
- `pause`, `menu`

## Polling Input (Physics/Process)

```gdscript
func _physics_process(delta: float) -> void:
    # Check if action is held
    if Input.is_action_pressed("move_right"):
        velocity.x = SPEED
    
    # Check if action was just pressed this frame
    if Input.is_action_just_pressed("jump"):
        velocity.y = JUMP_VELOCITY
    
    # Check if action was just released
    if Input.is_action_just_released("attack"):
        end_attack()
    
    # Get axis value (-1 to 1)
    var horizontal := Input.get_axis("move_left", "move_right")
    var vertical := Input.get_axis("move_up", "move_down")
    
    # Get vector for 2D movement
    var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = direction * SPEED
```

## Event-Based Input (_input and _unhandled_input)

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    # Keyboard
    if event is InputEventKey:
        if event.pressed and event.keycode == KEY_ESCAPE:
            pause_game()
    
    # Mouse button
    if event is InputEventMouseButton:
        if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            shoot()
    
    # Mouse motion
    if event is InputEventMouseMotion:
        rotate_camera(event.relative)
    
    # Using actions (preferred)
    if event.is_action_pressed("interact"):
        interact_with_object()
        get_viewport().set_input_as_handled()
```

## Input Buffering

```gdscript
var jump_buffer_time: float = 0.1
var jump_buffer_timer: float = 0.0

func _physics_process(delta: float) -> void:
    # Update buffer
    if Input.is_action_just_pressed("jump"):
        jump_buffer_timer = jump_buffer_time
    else:
        jump_buffer_timer -= delta
    
    # Check buffered input
    if jump_buffer_timer > 0 and is_on_floor():
        perform_jump()
        jump_buffer_timer = 0.0
```

## Mouse Look (First/Third Person)

```gdscript
@export var mouse_sensitivity: float = 0.002

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        rotate_y(-event.relative.x * mouse_sensitivity)
        $Camera3D.rotate_x(-event.relative.y * mouse_sensitivity)
        $Camera3D.rotation.x = clamp($Camera3D.rotation.x, -PI/2, PI/2)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
```

## Best Practices

- Use Input Map actions instead of hardcoded keys
- Use `_unhandled_input` for gameplay, `_input` for UI
- Call `get_viewport().set_input_as_handled()` to stop propagation
- Implement input buffering for responsive controls
- Support both keyboard and gamepad with actions
EOF
    
    # Create Animation/Tween skill
    if [[ ! -f "${SKILLS_DIR}/godot-animation-tween.md" ]]; then
        cat > "${SKILLS_DIR}/godot-animation-tween.md" << 'EOF'
# Godot Animation & Tween Skill

AnimationPlayer and Tween patterns for Godot 4.x.

## When to Use Each

| System | Best For |
|--------|----------|
| AnimationPlayer | Hand-crafted sequences, character animations, cinematics |
| Tween | Procedural/dynamic animations, runtime-determined values |

## AnimationPlayer Patterns

### Method Call Tracks
Synchronize game logic with animation keyframes:

```gdscript
# Called from AnimationPlayer Method Call Track
func enable_hitbox() -> void:
    $Hitbox.disabled = false

func disable_hitbox() -> void:
    $Hitbox.disabled = true

func spawn_particle_effect() -> void:
    var particles = preload("res://effects/hit_spark.tscn").instantiate()
    add_child(particles)
```

### Playing Animations
```gdscript
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func play_attack() -> void:
    anim_player.play("attack")
    await anim_player.animation_finished
    anim_player.play("idle")

# Queue animations
func play_combo() -> void:
    anim_player.play("attack_1")
    anim_player.queue("attack_2")
    anim_player.queue("idle")
```

## Tween Patterns

### Basic Tween Usage
```gdscript
func move_to(target_pos: Vector2) -> void:
    var tween = create_tween()
    tween.tween_property(self, "position", target_pos, 0.5)

# With easing
func bounce_in() -> void:
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
    tween.tween_property(self, "scale", Vector2.ONE, 0.2)\
        .set_trans(Tween.TRANS_BOUNCE)\
        .set_ease(Tween.EASE_OUT)
```

### Tween Transitions & Easing
```gdscript
# Common transitions
Tween.TRANS_LINEAR   # Constant speed
Tween.TRANS_SINE     # Smooth, natural motion
Tween.TRANS_BOUNCE   # Bouncy effect
Tween.TRANS_ELASTIC  # Springy overshoot
Tween.TRANS_BACK     # Slight overshoot

# Ease modes
Tween.EASE_IN        # Start slow
Tween.EASE_OUT       # End slow
Tween.EASE_IN_OUT    # Slow at both ends
```

### Chaining & Parallel Tweens
```gdscript
func animate_ui_panel() -> void:
    var tween = create_tween()
    # Sequential (one after another)
    tween.tween_property($Panel, "modulate:a", 1.0, 0.3)
    tween.tween_property($Panel, "position", Vector2(100, 100), 0.5)
    
    # Parallel (at the same time)
    tween.set_parallel(true)
    tween.tween_property($Panel, "scale", Vector2.ONE, 0.3)
    tween.tween_property($Panel, "rotation", 0.0, 0.3)
```

### Fade Effects
```gdscript
func fade_in(node: CanvasItem, duration: float = 0.5) -> void:
    node.modulate.a = 0.0
    var tween = create_tween()
    tween.tween_property(node, "modulate:a", 1.0, duration)

func fade_out_and_free(node: Node, duration: float = 0.5) -> void:
    var tween = create_tween()
    tween.tween_property(node, "modulate:a", 0.0, duration)
    tween.tween_callback(node.queue_free)
```

### Screen Shake
```gdscript
func screen_shake(intensity: float = 10.0, duration: float = 0.2) -> void:
    var camera = get_viewport().get_camera_2d()
    var original_offset = camera.offset
    var tween = create_tween()
    
    for i in range(int(duration * 60)):
        var offset = Vector2(
            randf_range(-intensity, intensity),
            randf_range(-intensity, intensity)
        )
        tween.tween_property(camera, "offset", offset, 1.0/60.0)
    
    tween.tween_property(camera, "offset", original_offset, 0.05)
```

## Best Practices

- Use AnimationPlayer for predefined, hand-authored sequences
- Use Tween for dynamic values known only at runtime
- Always `await tween.finished` if you need to sequence actions
- Kill existing tweens before starting new ones on the same property:
  ```gdscript
  if tween and tween.is_valid():
      tween.kill()
  tween = create_tween()
  ```
- Use `set_loops()` for repeating animations
- Combine AnimationPlayer for main animations with Tweens for dynamic overlays
EOF
    fi
    
    # Create Navigation/Pathfinding skill
    if [[ ! -f "${SKILLS_DIR}/godot-navigation-pathfinding.md" ]]; then
        cat > "${SKILLS_DIR}/godot-navigation-pathfinding.md" << 'EOF'
# Godot Navigation & Pathfinding Skill

NavigationAgent2D/3D patterns for AI movement in Godot 4.x.

## Navigation Setup

### 2D Navigation
```
NavigationRegion2D (add NavigationPolygon)
  └── CollisionPolygon2D (define walkable area)

CharacterBody2D (your enemy/NPC)
  └── NavigationAgent2D
```

### 3D Navigation
```
NavigationRegion3D (bake NavigationMesh)
  └── MeshInstance3D (level geometry)

CharacterBody3D (your enemy/NPC)
  └── NavigationAgent3D
```

## Basic Path Following

### 2D Character with NavigationAgent2D
```gdscript
extends CharacterBody2D

@export var speed: float = 200.0
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func set_target(target_position: Vector2) -> void:
    nav_agent.target_position = target_position

func _physics_process(delta: float) -> void:
    if nav_agent.is_navigation_finished():
        return
    
    var next_pos = nav_agent.get_next_path_position()
    var direction = (next_pos - global_position).normalized()
    velocity = direction * speed
    move_and_slide()
```

### 3D Character with NavigationAgent3D
```gdscript
extends CharacterBody3D

@export var speed: float = 5.0
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func set_target(target_position: Vector3) -> void:
    nav_agent.target_position = target_position

func _physics_process(delta: float) -> void:
    if nav_agent.is_navigation_finished():
        return
    
    var next_pos = nav_agent.get_next_path_position()
    var direction = (next_pos - global_position).normalized()
    velocity = direction * speed
    move_and_slide()
    
    # Face movement direction
    if direction != Vector3.ZERO:
        look_at(global_position + direction)
```

## Patrol Pattern
```gdscript
extends CharacterBody2D

@export var patrol_points: Array[Marker2D] = []
@export var speed: float = 100.0
@export var wait_time: float = 2.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var current_patrol_index: int = 0
var waiting: bool = false

func _ready() -> void:
    if patrol_points.size() > 0:
        _go_to_next_patrol_point()

func _physics_process(delta: float) -> void:
    if waiting or nav_agent.is_navigation_finished():
        return
    
    var next_pos = nav_agent.get_next_path_position()
    var direction = (next_pos - global_position).normalized()
    velocity = direction * speed
    move_and_slide()

func _go_to_next_patrol_point() -> void:
    nav_agent.target_position = patrol_points[current_patrol_index].global_position

func _on_navigation_agent_2d_navigation_finished() -> void:
    waiting = true
    await get_tree().create_timer(wait_time).timeout
    current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
    _go_to_next_patrol_point()
    waiting = false
```

## Chase Player with Update Interval
```gdscript
extends CharacterBody2D

@export var speed: float = 150.0
@export var path_update_interval: float = 0.5

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
var target: Node2D = null

func _ready() -> void:
    # Update path periodically (not every frame)
    var timer = Timer.new()
    timer.wait_time = path_update_interval
    timer.timeout.connect(_update_path)
    add_child(timer)
    timer.start()

func set_chase_target(new_target: Node2D) -> void:
    target = new_target

func _update_path() -> void:
    if target:
        nav_agent.target_position = target.global_position

func _physics_process(delta: float) -> void:
    if not target or nav_agent.is_navigation_finished():
        velocity = Vector2.ZERO
        return
    
    var next_pos = nav_agent.get_next_path_position()
    velocity = (next_pos - global_position).normalized() * speed
    move_and_slide()
```

## NavigationAgent Properties

| Property | Purpose |
|----------|---------|
| `path_desired_distance` | Distance to waypoint before moving to next |
| `target_desired_distance` | Distance to target to consider "arrived" |
| `navigation_layers` | Which navigation meshes to use |
| `avoidance_enabled` | Enable obstacle avoidance |
| `max_speed` | For avoidance calculations |

## Dynamic Obstacles
```gdscript
# Add NavigationObstacle2D as child of moving obstacles
# The navigation system will route around them

# For static obstacles, bake them into the NavigationPolygon/Mesh
```

## Best Practices

- Update target_position periodically, not every frame (use timer)
- Check `is_navigation_finished()` before moving
- Use `navigation_layers` to separate flying vs ground navigation
- Enable avoidance for multiple agents moving simultaneously
- For smooth rotation, lerp instead of snapping:
  ```gdscript
  rotation = lerp_angle(rotation, direction.angle(), delta * 10.0)
  ```
EOF
    fi
    
    # Create Shader Basics skill
    if [[ ! -f "${SKILLS_DIR}/godot-shader-basics.md" ]]; then
        cat > "${SKILLS_DIR}/godot-shader-basics.md" << 'EOF'
# Godot Shader Basics Skill

Shader and VisualShader patterns for Godot 4.x.

## Shader Types

| Type | Use Case |
|------|----------|
| `shader_type canvas_item` | 2D sprites, UI, CanvasItem nodes |
| `shader_type spatial` | 3D materials |
| `shader_type particles` | GPU particles |
| `shader_type sky` | Sky/environment shaders |

## Basic 2D Shader Structure

```glsl
shader_type canvas_item;

// Uniforms (parameters controllable from GDScript)
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D noise_texture;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    color.rgb *= tint_color.rgb * intensity;
    COLOR = color;
}
```

## Common 2D Effects

### Flash White (Hit Effect)
```glsl
shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    color.rgb = mix(color.rgb, vec3(1.0), flash_amount);
    COLOR = color;
}
```

### Outline
```glsl
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;

void fragment() {
    vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
    float outline = texture(TEXTURE, UV + vec2(-size.x, 0)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
    outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
    
    vec4 color = texture(TEXTURE, UV);
    if (outline > 0.0 && color.a == 0.0) {
        COLOR = outline_color;
    } else {
        COLOR = color;
    }
}
```

### Dissolve Effect
```glsl
shader_type canvas_item;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_texture;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    float noise = texture(noise_texture, UV).r;
    
    if (noise < dissolve_amount) {
        discard;
    } else if (noise < dissolve_amount + edge_width) {
        color.rgb = edge_color.rgb;
    }
    
    COLOR = color;
}
```

## Controlling Shaders from GDScript

```gdscript
extends Sprite2D

@onready var material: ShaderMaterial = material as ShaderMaterial

func flash_white(duration: float = 0.1) -> void:
    material.set_shader_parameter("flash_amount", 1.0)
    await get_tree().create_timer(duration).timeout
    
    var tween = create_tween()
    tween.tween_method(
        func(value): material.set_shader_parameter("flash_amount", value),
        1.0, 0.0, 0.2
    )

func set_dissolve(amount: float) -> void:
    material.set_shader_parameter("dissolve_amount", amount)

func dissolve_out(duration: float = 1.0) -> void:
    var tween = create_tween()
    tween.tween_method(set_dissolve, 0.0, 1.0, duration)
```

## 3D Spatial Shader Structure

```glsl
shader_type spatial;
render_mode unshaded;  // or: blend_mix, depth_draw_opaque, etc.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color;

void fragment() {
    vec4 tex = texture(texture_albedo, UV);
    ALBEDO = tex.rgb * albedo.rgb;
    ALPHA = tex.a * albedo.a;
}
```

## VisualShader Tips

- Use VisualShader for prototyping or if you prefer node-based editing
- Right-click canvas to add nodes
- Common nodes: `Texture2D`, `ColorParameter`, `FloatParameter`
- Convert to code: VisualShader → Resource → Convert to ShaderMaterial

## Creating Shader Material in Code

```gdscript
func apply_custom_shader() -> void:
    var shader = preload("res://shaders/my_shader.gdshader")
    var mat = ShaderMaterial.new()
    mat.shader = shader
    mat.set_shader_parameter("tint_color", Color.RED)
    $Sprite2D.material = mat
```

## Best Practices

- Use uniforms for any value you might want to change at runtime
- Use `hint_range()` for float uniforms to get sliders in inspector
- Use `: source_color` hint for color uniforms
- Test shaders on target hardware (mobile performance differs)
- Use `render_mode unshaded` for pure visual effects (no lighting)
- Keep shaders simple; complex math per-pixel is expensive
EOF
    fi
    
    # Create Object Pooling skill
    if [[ ! -f "${SKILLS_DIR}/godot-object-pooling.md" ]]; then
        cat > "${SKILLS_DIR}/godot-object-pooling.md" << 'EOF'
# Godot Object Pooling Skill

Performance optimization through object reuse in Godot 4.x.

## Why Use Object Pooling?

- Avoid performance spikes from frequent `instantiate()` / `queue_free()`
- Reduce memory allocation and garbage collection overhead
- Essential for bullet-hell games, particle effects, spawning enemies

## Basic Pool Implementation

```gdscript
# object_pool.gd
class_name ObjectPool
extends Node

@export var pooled_scene: PackedScene
@export var initial_size: int = 20

var _pool: Array[Node] = []

func _ready() -> void:
    _initialize_pool()

func _initialize_pool() -> void:
    for i in initial_size:
        var obj = pooled_scene.instantiate()
        obj.set_process(false)
        obj.visible = false
        add_child(obj)
        _pool.append(obj)

func get_object() -> Node:
    for obj in _pool:
        if not obj.visible:
            obj.visible = true
            obj.set_process(true)
            return obj
    
    # Pool exhausted - expand dynamically
    var obj = pooled_scene.instantiate()
    add_child(obj)
    _pool.append(obj)
    return obj

func release_object(obj: Node) -> void:
    obj.visible = false
    obj.set_process(false)
    # Reset object state here if needed
```

## Bullet Pool Example

```gdscript
# bullet_pool.gd
class_name BulletPool
extends Node

@export var bullet_scene: PackedScene
@export var pool_size: int = 100

var _bullets: Array[Node2D] = []

func _ready() -> void:
    for i in pool_size:
        var bullet = bullet_scene.instantiate()
        bullet.visible = false
        bullet.set_physics_process(false)
        add_child(bullet)
        _bullets.append(bullet)

func spawn_bullet(pos: Vector2, direction: Vector2, speed: float) -> Node2D:
    for bullet in _bullets:
        if not bullet.visible:
            bullet.global_position = pos
            bullet.direction = direction
            bullet.speed = speed
            bullet.visible = true
            bullet.set_physics_process(true)
            return bullet
    
    # Fallback: reuse oldest bullet or expand pool
    push_warning("Bullet pool exhausted!")
    return null

func release_bullet(bullet: Node2D) -> void:
    bullet.visible = false
    bullet.set_physics_process(false)
```

### Pooled Bullet Script
```gdscript
# bullet.gd
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var pool: BulletPool  # Reference to pool for self-release

func _physics_process(delta: float) -> void:
    position += direction * speed * delta

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
    release()

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("take_damage"):
        body.take_damage(10)
    release()

func release() -> void:
    if pool:
        pool.release_bullet(self)
    else:
        visible = false
        set_physics_process(false)
```

## Generic Pool Manager (Autoload)

```gdscript
# pool_manager.gd - Add as Autoload
extends Node

var _pools: Dictionary = {}

func create_pool(pool_name: String, scene: PackedScene, size: int) -> void:
    if pool_name in _pools:
        return
    
    var pool = ObjectPool.new()
    pool.pooled_scene = scene
    pool.initial_size = size
    pool.name = pool_name
    add_child(pool)
    _pools[pool_name] = pool

func get_from_pool(pool_name: String) -> Node:
    if pool_name in _pools:
        return _pools[pool_name].get_object()
    return null

func release_to_pool(pool_name: String, obj: Node) -> void:
    if pool_name in _pools:
        _pools[pool_name].release_object(obj)
```

### Usage
```gdscript
# In _ready() of main scene or loading
func _ready() -> void:
    PoolManager.create_pool("bullets", preload("res://bullet.tscn"), 100)
    PoolManager.create_pool("enemies", preload("res://enemy.tscn"), 30)

# When spawning
func fire_bullet() -> void:
    var bullet = PoolManager.get_from_pool("bullets")
    if bullet:
        bullet.global_position = $Muzzle.global_position
        bullet.direction = (get_global_mouse_position() - bullet.global_position).normalized()
```

## Reset Patterns

Always reset pooled objects when retrieving:

```gdscript
func get_object() -> Node:
    for obj in _pool:
        if not obj.visible:
            _reset_object(obj)
            obj.visible = true
            return obj
    return null

func _reset_object(obj: Node) -> void:
    # Reset common properties
    if obj is Node2D:
        obj.position = Vector2.ZERO
        obj.rotation = 0.0
        obj.scale = Vector2.ONE
    
    # Reset velocity if it's a physics body
    if obj is CharacterBody2D:
        obj.velocity = Vector2.ZERO
    
    # Call custom reset method if available
    if obj.has_method("reset"):
        obj.reset()
```

## Best Practices

- **Pre-allocate** pools during loading screens, not gameplay
- **Spread initialization** across frames if pool is very large:
  ```gdscript
  func _initialize_pool_async() -> void:
      for i in initial_size:
          var obj = pooled_scene.instantiate()
          add_child(obj)
          _pool.append(obj)
          if i % 10 == 0:
              await get_tree().process_frame
  ```
- **Size appropriately**: Test max concurrent usage, add 20% buffer
- **Disable processing**: Set `process_mode` or `set_process(false)` on inactive objects
- **Don't mix**: Either use pooling OR `queue_free()` for an object type, not both
- **Clear pools** between scenes if needed to free memory
EOF
    fi
    
    # Create Audio Manager skill
    if [[ ! -f "${SKILLS_DIR}/godot-audio-manager.md" ]]; then
        cat > "${SKILLS_DIR}/godot-audio-manager.md" << 'EOF'
# Godot Audio Manager Skill

Audio, SFX, and music patterns for Godot 4.x.

## Audio Node Types

| Node | Use Case |
|------|----------|
| AudioStreamPlayer | Non-positional (music, UI sounds) |
| AudioStreamPlayer2D | 2D positional audio |
| AudioStreamPlayer3D | 3D positional audio |

## Audio Bus Setup

1. Go to **Project > Project Settings > Audio**
2. Create buses: Master → Music, Master → SFX, Master → UI
3. Add effects (reverb, compression) to buses as needed

## Basic Audio Manager (Autoload)

```gdscript
# audio_manager.gd
extends Node

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8

func _ready() -> void:
    # Create music player
    music_player = AudioStreamPlayer.new()
    music_player.bus = "Music"
    add_child(music_player)
    
    # Create SFX player pool
    for i in SFX_POOL_SIZE:
        var player = AudioStreamPlayer.new()
        player.bus = "SFX"
        add_child(player)
        sfx_players.append(player)

func play_music(stream: AudioStream, fade_in: float = 0.5) -> void:
    if music_player.stream == stream and music_player.playing:
        return
    
    if music_player.playing and fade_in > 0:
        var tween = create_tween()
        tween.tween_property(music_player, "volume_db", -40, fade_in)
        await tween.finished
    
    music_player.stream = stream
    music_player.volume_db = 0
    music_player.play()

func stop_music(fade_out: float = 1.0) -> void:
    if not music_player.playing:
        return
    
    var tween = create_tween()
    tween.tween_property(music_player, "volume_db", -40, fade_out)
    await tween.finished
    music_player.stop()

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
    for player in sfx_players:
        if not player.playing:
            player.stream = stream
            player.volume_db = volume_db
            player.play()
            return
    
    # All players busy - use first one (interrupting oldest sound)
    sfx_players[0].stream = stream
    sfx_players[0].volume_db = volume_db
    sfx_players[0].play()
```

## One-Shot SFX Pattern

```gdscript
func play_sfx_oneshot(stream: AudioStream, pos: Vector2 = Vector2.ZERO) -> void:
    var player = AudioStreamPlayer2D.new()
    player.stream = stream
    player.bus = "SFX"
    player.global_position = pos
    add_child(player)
    player.play()
    player.finished.connect(player.queue_free)
```

## Randomized SFX (Variation)

```gdscript
# For footsteps, hits, etc. - avoid repetition
@export var footstep_sounds: Array[AudioStream] = []
var last_footstep_index: int = -1

func play_footstep() -> void:
    if footstep_sounds.is_empty():
        return
    
    # Pick random sound, avoiding the last one played
    var index = randi() % footstep_sounds.size()
    while index == last_footstep_index and footstep_sounds.size() > 1:
        index = randi() % footstep_sounds.size()
    
    last_footstep_index = index
    AudioManager.play_sfx(footstep_sounds[index])
```

## Using AudioStreamRandomizer

```gdscript
# In the Inspector, create an AudioStreamRandomizer resource
# Add multiple streams to it
# The engine will automatically randomize pitch/selection

@export var hit_sounds: AudioStreamRandomizer
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

func play_hit() -> void:
    audio_player.stream = hit_sounds
    audio_player.play()
```

## Volume Control

```gdscript
func set_music_volume(linear: float) -> void:
    # Convert linear (0-1) to decibels
    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index("Music"),
        linear_to_db(linear)
    )

func set_sfx_volume(linear: float) -> void:
    AudioServer.set_bus_volume_db(
        AudioServer.get_bus_index("SFX"),
        linear_to_db(linear)
    )

func set_master_volume(linear: float) -> void:
    AudioServer.set_bus_volume_db(0, linear_to_db(linear))

func mute_bus(bus_name: String, muted: bool) -> void:
    AudioServer.set_bus_mute(
        AudioServer.get_bus_index(bus_name),
        muted
    )
```

## Crossfade Music

```gdscript
func crossfade_music(new_stream: AudioStream, duration: float = 2.0) -> void:
    var old_player = music_player
    
    # Create new player for crossfade
    var new_player = AudioStreamPlayer.new()
    new_player.stream = new_stream
    new_player.bus = "Music"
    new_player.volume_db = -40
    add_child(new_player)
    new_player.play()
    
    # Crossfade
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(old_player, "volume_db", -40, duration)
    tween.tween_property(new_player, "volume_db", 0, duration)
    
    await tween.finished
    old_player.stop()
    music_player = new_player
    old_player.queue_free()
```

## Positional 2D Audio

```gdscript
# Attach AudioStreamPlayer2D to moving objects
# Godot handles panning and attenuation automatically

extends CharacterBody2D

@onready var footstep_player: AudioStreamPlayer2D = $FootstepPlayer
@export var footstep_sound: AudioStream

func play_footstep() -> void:
    if not footstep_player.playing:
        footstep_player.stream = footstep_sound
        footstep_player.pitch_scale = randf_range(0.9, 1.1)
        footstep_player.play()
```

## Best Practices

- Use **WAV** for short SFX (no decoding delay)
- Use **OGG** for music (smaller file size, supports looping)
- Set up audio buses early - easier to balance later
- Pool AudioStreamPlayers for frequent SFX
- Use `max_polyphony` property for multi-instance sounds
- Preload frequently used sounds:
  ```gdscript
  const JUMP_SFX = preload("res://audio/sfx/jump.wav")
  ```
- Test audio balance with different volumes
- Add slight pitch variation (0.9-1.1) for repeated sounds
EOF
    fi

    mkdir -p "$final_skills_dir"
    for skill_file in "${MISSING_SKILLS[@]}"; do
        if [[ -f "${SKILLS_DIR}/${skill_file}" ]]; then
            mv "${SKILLS_DIR}/${skill_file}" "${final_skills_dir}/${skill_file}"
            created_count=$((created_count + 1))
        fi
    done

    rm -rf "$temp_dir"

    if [[ "$created_count" -gt 0 ]]; then
        print_success "Created ${created_count} missing skill template(s) in ${final_skills_dir}/"
    else
        print_skip "Core skill templates already available"
    fi
}

# -----------------------------------------------------------------------------
# Exclusion Configuration
# -----------------------------------------------------------------------------

configure_exclusions() {
    # Update .gitignore
    local gitignore=".gitignore"
    local needs_update=false
    local additions=""
    
    if [[ ! -f "$gitignore" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            touch "$gitignore"
        fi
        needs_update=true
    fi
    
    # Use wildcard pattern for docs directory to match any version
    # Note: We DON'T add addons/ or test/ to gitignore as they should be committed
    for entry in "${DOCS_BASE_DIR}/" "validate-godot.sh" "run-tests.sh" ".gutconfig.json"; do
        if ! grep -qF "$entry" "$gitignore" 2>/dev/null; then
            additions+="$entry"$'\n'
            needs_update=true
        fi
    done
    
    if [[ "$needs_update" == true && -n "$additions" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            if ! grep -qF "# Agentic AI workflow files" "$gitignore" 2>/dev/null; then
                [[ -s "$gitignore" ]] && printf '\n' >> "$gitignore"
                echo "# Agentic AI workflow files" >> "$gitignore"
            fi
            echo -n "$additions" >> "$gitignore"
        fi
        print_success "Updated .gitignore with exclusions"
    else
        print_skip ".gitignore already configured"
    fi
    
    # Update .gdignore (excludes from Godot editor)
    # Note: .docs/ is already hidden, but we add it for explicitness
    local gdignore=".gdignore"
    needs_update=false
    additions=""
    
    if [[ ! -f "$gdignore" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            touch "$gdignore"
        fi
        needs_update=true
    fi
    
    for entry in "${DOCS_BASE_DIR}/"; do
        if ! grep -qF "$entry" "$gdignore" 2>/dev/null; then
            additions+="$entry"$'\n'
            needs_update=true
        fi
    done
    
    if [[ "$needs_update" == true && -n "$additions" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            echo -n "$additions" >> "$gdignore"
        fi
        print_success "Updated .gdignore with exclusions"
    else
        print_skip ".gdignore already configured"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    echo ""
    echo "=========================================="
    echo "  Godot Agentic AI Workflow Setup"
    echo "=========================================="
    echo ""
    
    parse_args "$@"
    
    # Step 1: Detect Godot project
    detect_godot_project
    
    # Step 2: Parse version
    parse_godot_version
    inventory_project_setup
    
    echo ""
    
    # Step 3: Create documentation
    create_agents_md
    update_readme_version
    
    # Step 4: Download offline docs
    if [[ "$SKIP_DOCS" == true ]]; then
        print_info "Skipping documentation download (--skip-docs)"
    else
        download_documentation || true
    fi
    
    # Step 5: Create validation script
    create_validation_script
    
    # Step 6: Install GUT testing framework
    install_gut_framework
    
    # Step 7: Setup skills
    setup_skills
    
    # Step 8: Configure exclusions
    configure_exclusions
    
    echo ""
    echo "=========================================="
    print_success "Setup complete!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Review AGENTS.md and customize as needed"
    echo "  2. Run ./run-tests.sh to execute unit tests"
    echo "  3. Run ./validate-godot.sh to test syntax validation"
    echo "  4. Check ${SKILLS_DIR}/ for reusable prompt templates"
    if docs_are_available; then
        echo "  5. Documentation is available in ${DOCS_DIR}/"
    fi
    echo ""
    if gut_plugin_is_enabled "project.godot"; then
        echo "Note: GUT plugin is enabled in project.godot"
    else
        echo "Note: GUT plugin may need manual enablement in project.godot"
    fi
    echo ""
}

main "$@"
