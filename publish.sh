#!/usr/bin/env bash
# ==============================================================================
# publish.sh - Automated Public Release Pipeline for Waypoint
#
# Bridges the private repository (EventsManager / Helm) to the public
# distribution repository (Helm-App).
#
# Workflow:
#  1. Runs existing build runner (helm/build.ps1) for Windows + Android.
#  2. Locates and validates output binaries.
#  3. Extracts recent git commits into clean markdown changelog notes.
#  4. Enforces strict security boundaries (no private source code leaked).
#  5. Updates public repository (releases/, CHANGELOG.md, README.md).
#  6. Commits, tags (v<version>), and pushes to public repository.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_REPO="$SCRIPT_DIR"
HELM_DIR="$PRIVATE_REPO/helm"
TODAY="$(date +%Y-%m-%d)"

# --- Color Output Helpers ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
pass()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fatal() { echo -e "${RED}[FATAL]${NC} $*" >&2; exit 1; }

# --- Parse Arguments ---
SKIP_BUILD=false
DRY_RUN=false
CUSTOM_VERSION=""
PUBLIC_REPO_ARG=""

print_usage() {
    cat <<EOF
Usage: ./publish.sh [OPTIONS] [VERSION]

Options:
  --skip-build          Skip executing flutter build runner (use existing prebuilt binaries)
  --dry-run             Perform validations, artifact copying, and doc updates without git commit/push
  --public-repo <path>  Explicit path to public distribution repository
  -h, --help            Show this help message

Examples:
  ./publish.sh                      # Full build and publish for current pubspec version
  ./publish.sh --skip-build         # Publish with existing prebuilt binaries
  ./publish.sh --dry-run            # Validate and stage changes without git commit or push
  ./publish.sh 0.4.1                # Publish specific version override
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --public-repo)
            PUBLIC_REPO_ARG="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            if [[ -z "$CUSTOM_VERSION" && ! "$1" =~ ^- ]]; then
                CUSTOM_VERSION="$1"
                shift
            else
                fatal "Unknown argument: $1"
            fi
            ;;
    esac
done

# --- 1. Resolve Version ---
if [[ -n "$CUSTOM_VERSION" ]]; then
    VERSION="$CUSTOM_VERSION"
    BUILD_NUMBER=""
else
    PUBSPEC="$HELM_DIR/pubspec.yaml"
    if [[ ! -f "$PUBSPEC" ]]; then
        fatal "pubspec.yaml not found at: $PUBSPEC"
    fi
    VERSION=$(grep -E '^version:' "$PUBSPEC" | head -n1 | sed -E 's/version:[[:space:]]*([0-9.]+).*/\1/')
    BUILD_NUMBER=$(grep -E '^version:' "$PUBSPEC" | head -n1 | sed -nE 's/.*\+([0-9]+).*/\1/p')
fi

if [[ -z "$VERSION" ]]; then
    fatal "Could not determine release version."
fi

RELEASE_TITLE="Waypoint-v${VERSION}"
if [[ -n "$BUILD_NUMBER" ]]; then
    RELEASE_TITLE="Waypoint-v${VERSION}+${BUILD_NUMBER}"
fi

info "Publishing Waypoint version: v${VERSION} (${RELEASE_TITLE})"
info "Release date: ${TODAY}"

# --- 2. Resolve & Verify Public Repository Path ---
resolve_public_repo() {
    if [[ -n "$PUBLIC_REPO_ARG" && -d "$PUBLIC_REPO_ARG" ]]; then
        echo "$PUBLIC_REPO_ARG"
        return
    fi
    if [[ -n "${PUBLIC_REPO_PATH:-}" && -d "${PUBLIC_REPO_PATH:-}" ]]; then
        echo "$PUBLIC_REPO_PATH"
        return
    fi

    # Standard workspace locations
    local candidates=(
        "/c/codes/Personal-cmp/Helm/Helm-App"
        "C:/codes/Personal-cmp/Helm/Helm-App"
        "$PRIVATE_REPO/../Personal-cmp/Helm/Helm-App"
        "$PRIVATE_REPO/../Helm-App"
        "/c/codes/Personal-cmp/Helm"
    )

    for c in "${candidates[@]}"; do
        if [[ -d "$c/.git" ]]; then
            echo "$c"
            return
        elif [[ -d "$c/Helm-App/.git" ]]; then
            echo "$c/Helm-App"
            return
        fi
    done

    echo ""
}

PUBLIC_REPO="$(resolve_public_repo)"
if [[ -z "$PUBLIC_REPO" ]]; then
    fatal "Could not locate public distribution repository. Set --public-repo <path> or PUBLIC_REPO_PATH."
fi

# Normalize paths for POSIX comparison
PUBLIC_REPO_REAL="$(cd "$PUBLIC_REPO" && pwd)"
PRIVATE_REPO_REAL="$(cd "$PRIVATE_REPO" && pwd)"

info "Private Repo: $PRIVATE_REPO_REAL"
info "Public Repo:  $PUBLIC_REPO_REAL"

# --- Security Check: Ensure Repositories Are Distinct ---
if [[ "$PUBLIC_REPO_REAL" == "$PRIVATE_REPO_REAL" ]]; then
    fatal "SECURITY VIOLATION: Public repository path matches private repository path! Aborting."
fi

if [[ ! -d "$PUBLIC_REPO_REAL/.git" ]]; then
    fatal "Target public repository is not a valid Git repository: $PUBLIC_REPO_REAL"
fi

# --- 3. Step 1: Run Existing Build Script ---
if [[ "$SKIP_BUILD" == false ]]; then
    info "Running existing multi-platform build runner for Windows & Android..."
    if command -v powershell.exe >/dev/null 2>&1; then
        PS_BIN="powershell.exe"
    elif command -v pwsh >/dev/null 2>&1; then
        PS_BIN="pwsh"
    else
        fatal "PowerShell executable not found in PATH to run build.ps1."
    fi

    HELM_DIR_WIN="$HELM_DIR"
    if command -v cygpath >/dev/null 2>&1; then
        HELM_DIR_WIN="$(cygpath -w "$HELM_DIR")"
    fi

    # Run build for windows and apk
    "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -Command "& '$HELM_DIR_WIN\\build.ps1' -Target windows"
    "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -Command "& '$HELM_DIR_WIN\\build.ps1' -Target apk"

    # Ensure Windows Inno Setup installer is compiled if CMake did not invoke it
    if [[ ! -f "$HELM_DIR/build/windows/installer/Waypoint-v${VERSION}-Setup.exe" ]]; then
        info "Running package_windows.ps1 to generate Inno Setup installer..."
        "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -Command "& '$HELM_DIR_WIN\\tools\\package_windows.ps1' -Build:\$false" || true
    fi

    pass "Build runner execution completed successfully."
else
    warn "Skipping build execution as requested (--skip-build)."
fi

# --- 4. Locate & Verify Output Binaries ---
locate_artifacts() {
    WIN_BIN=""
    APK_BIN=""

    # Windows candidate paths (ordered by installer priority)
    local win_candidates=(
        "$HELM_DIR/build/windows/installer/Waypoint-v${VERSION}-Setup.exe"
        "$HELM_DIR/build/windows/installer/waypoint-v${VERSION}-windows.zip"
        "$HELM_DIR/build/windows/x64/runner/Release/waypoint-v${VERSION}.exe"
        "$HELM_DIR/build/windows/x64/runner/Release/waypoint.exe"
    )

    for p in "${win_candidates[@]}"; do
        if [[ -f "$p" && -s "$p" ]]; then
            WIN_BIN="$p"
            break
        fi
    done

    # Android candidate paths
    local apk_candidates=(
        "$HELM_DIR/build/app/outputs/flutter-apk/waypoint-v${VERSION}.apk"
        "$HELM_DIR/build/app/outputs/apk/release/waypoint-v${VERSION}.apk"
        "$HELM_DIR/build/app/outputs/flutter-apk/app-release.apk"
    )

    for p in "${apk_candidates[@]}"; do
        if [[ -f "$p" && -s "$p" ]]; then
            APK_BIN="$p"
            break
        fi
    done
}

locate_artifacts

if [[ -z "$WIN_BIN" ]]; then
    fatal "Windows release artifact not found. Please run the build script first."
fi
if [[ -z "$APK_BIN" ]]; then
    fatal "Android APK release artifact not found. Please run the build script first."
fi

WIN_SIZE=$(ls -lh "$WIN_BIN" | awk '{print $5}')
APK_SIZE=$(ls -lh "$APK_BIN" | awk '{print $5}')

pass "Verified Windows binary: $WIN_BIN ($WIN_SIZE)"
pass "Verified Android binary: $APK_BIN ($APK_SIZE)"

# --- 5. Step 2: Generate Changelog ---
info "Extracting changelog notes from private repository git history..."

LAST_TAG=$(git -C "$PRIVATE_REPO" describe --tags --match "v*" --abbrev=0 2>/dev/null || echo "")
CHANGELOG_NOTES=""

if [[ -f "$PRIVATE_REPO/docs/release_notes_v${VERSION}.md" ]]; then
    info "Using comprehensive release notes from docs/release_notes_v${VERSION}.md"
    CHANGELOG_NOTES="$(cat "$PRIVATE_REPO/docs/release_notes_v${VERSION}.md")"
elif [[ -n "$LAST_TAG" ]]; then
    CHANGELOG_NOTES=$(git -C "$PRIVATE_REPO" log "${LAST_TAG}..HEAD" --no-merges --pretty=format:"* %s (%h)" || echo "")
fi

if [[ -z "$CHANGELOG_NOTES" ]]; then
    CHANGELOG_NOTES=$(git -C "$PRIVATE_REPO" log -n 10 --no-merges --pretty=format:"* %s (%h)")
fi

if [[ -z "$CHANGELOG_NOTES" ]]; then
    CHANGELOG_NOTES="* Routine release updates and performance optimizations."
fi

info "Generated changelog bullets:"
echo "$CHANGELOG_NOTES"

# --- 6. Pre-flight Security Audit on Public Repo ---
info "Running security scan on public repository before release operations..."

# Check that public repo does not already contain forbidden private source code
FORBIDDEN_FILES=$(find "$PUBLIC_REPO_REAL" -maxdepth 3 \( \
    -name "*.dart" -o \
    -name "*.sql" -o \
    -name "*.keystore" -o \
    -name "*.jks" -o \
    -name ".env*" \
\) ! -path "*/.git/*" 2>/dev/null || true)

if [[ -n "$FORBIDDEN_FILES" ]]; then
    echo -e "${RED}[SECURITY ALERT]${NC} Forbidden private source files found in public repo:"
    echo "$FORBIDDEN_FILES"
    fatal "Aborting to prevent private source code exposure."
fi

pass "Pre-flight security scan clean. No private code patterns detected in public repository."

# --- 7. Step 3: Update Public Distribution Repo ---
RELEASES_DIR="$PUBLIC_REPO_REAL/releases"
mkdir -p "$RELEASES_DIR"

WIN_NAME="$(basename "$WIN_BIN")"
APK_NAME="$(basename "$APK_BIN")"

info "Copying release artifacts to $RELEASES_DIR..."
cp -f "$WIN_BIN" "$RELEASES_DIR/$WIN_NAME"
cp -f "$APK_BIN" "$RELEASES_DIR/$APK_NAME"
pass "Copied artifacts: $WIN_NAME and $APK_NAME"

# Ensure GitHub CLI is in PATH
if ! command -v gh >/dev/null 2>&1; then
    for gh_dir in "/c/Program Files/GitHub CLI" "C:/Program Files/GitHub CLI"; do
        if [[ -d "$gh_dir" ]]; then
            export PATH="$gh_dir:$PATH"
            break
        fi
    done
fi

# Acquire GH_TOKEN automatically via Git Credential Manager if unset
if [[ -z "${GH_TOKEN:-}" ]]; then
    for gcm in "/c/Program Files/Git/mingw64/bin/git-credential-manager.exe" "C:/Program Files/Git/mingw64/bin/git-credential-manager.exe"; do
        if [[ -f "$gcm" ]]; then
            GCM_TOKEN=$(printf "protocol=https\nhost=github.com\n\n" | "$gcm" get 2>/dev/null | grep -E '^password=' | tr -d '\r\n' | sed -E 's/^password=//' || true)
            if [[ -n "$GCM_TOKEN" ]]; then
                export GH_TOKEN="$GCM_TOKEN"
                break
            fi
        fi
    done
fi

# Attempt gh release if gh is installed and authenticated
if command -v gh >/dev/null 2>&1 && [[ -n "${GH_TOKEN:-}" ]]; then
    info "Publishing release via GitHub CLI (gh release)..."
    (
        cd "$PUBLIC_REPO_REAL"
        REPO_NAME="zedrock-coding/Waypoint-App"
        if gh release view "v${VERSION}" --repo "$REPO_NAME" >/dev/null 2>&1; then
            info "Release v${VERSION} exists on GitHub. Uploading updated assets..."
            gh release upload "v${VERSION}" \
                "$RELEASES_DIR/$WIN_NAME" \
                "$RELEASES_DIR/$APK_NAME" \
                --repo "$REPO_NAME" \
                --clobber
            gh release edit "v${VERSION}" \
                --repo "$REPO_NAME" \
                --title "${RELEASE_TITLE}" \
                --notes "$CHANGELOG_NOTES"
        else
            info "Creating new GitHub Release v${VERSION}..."
            gh release create "v${VERSION}" \
                "$RELEASES_DIR/$WIN_NAME" \
                "$RELEASES_DIR/$APK_NAME" \
                --repo "$REPO_NAME" \
                --title "${RELEASE_TITLE}" \
                --notes "$CHANGELOG_NOTES"
        fi
        pass "GitHub Release successfully published to GitHub Releases!"
    )
else
    warn "GitHub CLI or GH_TOKEN unavailable. Artifacts placed in local releases/ directory."
fi

# Update or Create CHANGELOG.md in Public Repo
PUBLIC_CHANGELOG="$PUBLIC_REPO_REAL/CHANGELOG.md"
CHANGELOG_ENTRY="## [v${VERSION}] - ${TODAY}

### Changes
${CHANGELOG_NOTES}
"

if [[ -f "$PUBLIC_CHANGELOG" ]]; then
    # Prepend new entry below main header if exists, or at start
    if grep -q "^# Changelog" "$PUBLIC_CHANGELOG"; then
        awk -v entry="$CHANGELOG_ENTRY" '
            /^# Changelog/ { print; print ""; print entry; next }
            { print }
        ' "$PUBLIC_CHANGELOG" > "$PUBLIC_CHANGELOG.tmp" && mv "$PUBLIC_CHANGELOG.tmp" "$PUBLIC_CHANGELOG"
    else
        printf "# Changelog\n\n%s\n\n%s" "$CHANGELOG_ENTRY" "$(cat "$PUBLIC_CHANGELOG")" > "$PUBLIC_CHANGELOG"
    fi
    pass "Updated $PUBLIC_CHANGELOG"
else
    cat <<EOF > "$PUBLIC_CHANGELOG"
# Changelog

All notable changes and public releases of Waypoint are documented here.

$CHANGELOG_ENTRY
EOF
    pass "Created $PUBLIC_CHANGELOG"
fi

# Update README.md in Public Repo (Badge + Download Links)
PUBLIC_README="$PUBLIC_REPO_REAL/README.md"
if [[ -f "$PUBLIC_README" ]]; then
    # Update Version badge if present
    if grep -q "img.shields.io/badge/Version-" "$PUBLIC_README"; then
        sed -i -E "s|!\[Version\]\(https://img\.shields\.io/badge/Version-[^)]+-green\)|![Version](https://img.shields.io/badge/Version-v${VERSION}-green)|g" "$PUBLIC_README"
    fi

    # Update or append Downloads section
    DOWNLOADS_SECTION="## 📥 Downloads (v${VERSION})

* 🪟 **Windows**: [\`${WIN_NAME}\`](releases/${WIN_NAME})
* 📱 **Android**: [\`${APK_NAME}\`](releases/${APK_NAME})
"

    if grep -q "^## 📥 Downloads" "$PUBLIC_README"; then
        awk -v dls="$DOWNLOADS_SECTION" '
            /^## 📥 Downloads/ { inside=1; print dls; next }
            inside && /^## / { inside=0 }
            !inside { print }
        ' "$PUBLIC_README" > "$PUBLIC_README.tmp" && mv "$PUBLIC_README.tmp" "$PUBLIC_README"
    else
        echo "" >> "$PUBLIC_README"
        echo "$DOWNLOADS_SECTION" >> "$PUBLIC_README"
    fi
    pass "Updated $PUBLIC_README badge and download links."
fi

# --- 8. Step 4: Strict Staging & Post-Stage Security Verification ---
info "Staging release documentation and artifacts in public repository..."

(
    cd "$PUBLIC_REPO_REAL"

    # Surgical staging: ONLY stage releases, CHANGELOG.md, and README.md
    git add releases/
    git add CHANGELOG.md
    git add README.md

    # Audit staged files
    STAGED_FILES=$(git diff --cached --name-only)
    info "Staged files in public repo:"
    echo "$STAGED_FILES"

    # Strictly verify that no source code file is staged
    LEAKED_FILES=$(echo "$STAGED_FILES" | grep -E '\.(dart|ts|sql|keystore|jks|env)$|^(lib|supabase|test)/' || true)
    if [[ -n "$LEAKED_FILES" ]]; then
        git reset HEAD
        fatal "CRITICAL SECURITY BREACH PREVENTED: Attempted to stage private source code files: $LEAKED_FILES"
    fi

    pass "Post-stage security audit passed. Zero private files staged."

    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    TAG_NAME="v${VERSION}"

    if [[ "$DRY_RUN" == true ]]; then
        warn "[DRY RUN] Verification succeeded. Cleaning working tree and skipping commit/tag/push."
        git reset HEAD >/dev/null 2>&1 || true
        git checkout -- . >/dev/null 2>&1 || true
        git clean -fd >/dev/null 2>&1 || true
        echo ""
        echo -e "${GREEN}================================================================${NC}"
        echo -e "${GREEN} DRY RUN COMPLETE: All checks passed. Ready for live release!   ${NC}"
        echo -e "${GREEN}================================================================${NC}"
        exit 0
    fi

    # Commit
    if git diff --cached --quiet; then
        info "No changes to commit (public repository already up-to-date)."
    else
        git commit -m "release: v${VERSION}"
        pass "Committed release updates on branch '$CURRENT_BRANCH'."
    fi

    # Create or update tag
    if git tag -l "$TAG_NAME" | grep -q "^${TAG_NAME}$"; then
        warn "Tag '$TAG_NAME' already exists. Updating tag to point to latest commit."
        git tag -fa "$TAG_NAME" -m "Release v${VERSION}"
    else
        git tag -a "$TAG_NAME" -m "Release v${VERSION}"
        pass "Created release tag: $TAG_NAME"
    fi

    # Push to remote
    info "Pushing commit and tag '$TAG_NAME' to origin ($CURRENT_BRANCH)..."
    git push origin "$CURRENT_BRANCH"
    git push origin "$TAG_NAME" --force
    pass "Successfully pushed release commit and tag to public repository!"
)

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN} Release v${VERSION} Successfully Published to Public Distribution!${NC}"
echo -e "${GREEN}================================================================${NC}"
echo " * Windows: $WIN_NAME"
echo " * Android: $APK_NAME"
echo " * Public Repo: $PUBLIC_REPO_REAL"
echo ""
