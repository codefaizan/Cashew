#!/usr/bin/env bash
set -euo pipefail

# ── build-and-release.sh ─────────────────────────────────────────────
# Build a Flutter release APK and publish it to a GitHub release.
# The tag name is read from pubspec.yaml (version field).
#
# Prerequisites:
#   - flutter CLI on PATH
#   - gh CLI on PATH, authenticated (gh auth status)
#   - git in the project root (auto-detected)
#
# Usage:
#   ./scripts/build-and-release.sh [--release-notes "..."|--release-notes-file notes.md]
#     --release-notes   inline notes for the release (default: latest commit message)
#     --release-notes-file  path to a markdown file
#     --dry-run         print what would happen without doing it
#     --keep-tag        don't force-move the tag (use when tag doesn't exist yet)
# ──────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# ── helpers ───────────────────────────────────────────────────────────
die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "→ $*"; }

# ── flags ─────────────────────────────────────────────────────────────
DRY_RUN=false
KEEP_TAG=false
RELEASE_NOTES=""
RELEASE_NOTES_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-notes)       RELEASE_NOTES="$2"; shift 2 ;;
    --release-notes=*)     RELEASE_NOTES="${1#*=}"; shift ;;
    --release-notes-file)  RELEASE_NOTES_FILE="$2"; shift 2 ;;
    --release-notes-file=*) RELEASE_NOTES_FILE="${1#*=}"; shift ;;
    --dry-run)             DRY_RUN=true; shift ;;
    --keep-tag)            KEEP_TAG=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--release-notes \"...\"|--release-notes-file path.md] [--dry-run] [--keep-tag]"
      exit 0 ;;
    *) die "Unknown flag: $1" ;;
  esac
done

# ── checks ────────────────────────────────────────────────────────────
command -v flutter >/dev/null 2>&1 || die "flutter not found on PATH"
command -v gh      >/dev/null 2>&1 || die "gh CLI not found on PATH"

gh auth status >/dev/null 2>&1 || die "gh not authenticated – run 'gh auth login'"

REPO="$(git remote get-url origin | sed 's|.*github\.com[:/]||; s|\.git$||')"
[[ -n "$REPO" ]] || die "Could not determine GitHub repo from origin remote"

# ── version ───────────────────────────────────────────────────────────
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
[[ -n "$VERSION" ]] || die "Could not parse version from pubspec.yaml"
TAG="v$VERSION"
info "Version: $VERSION  →  Tag: $TAG  →  Repo: $REPO  →  Branch: $(git branch --show-current)"

# ── release notes ─────────────────────────────────────────────────────
if [[ -n "$RELEASE_NOTES_FILE" ]]; then
  RELEASE_NOTES="$(cat "$RELEASE_NOTES_FILE")"
elif [[ -z "$RELEASE_NOTES" ]]; then
  # Default: latest commit message
  RELEASE_NOTES="$(git log -1 --pretty=%B)"
fi
info "Release notes: ${RELEASE_NOTES:0:80}..."

# ── dry-run? ──────────────────────────────────────────────────────────
if $DRY_RUN; then
  info "[dry-run] Would build APK, tag $TAG, and upload to $REPO"
  exit 0
fi

# ── build APK ─────────────────────────────────────────────────────────
info "Building release APK..."
flutter build apk --release
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
[[ -f "$APK_PATH" ]] || die "APK not found at $APK_PATH after build"
info "APK built: $(du -h "$APK_PATH" | cut -f1)"

# ── tag ───────────────────────────────────────────────────────────────
if $KEEP_TAG; then
  if git rev-parse "$TAG" >/dev/null 2>&1; then
    info "Tag $TAG already exists (--keep-tag set, will not force-move it)"
  else
    git tag "$TAG"
    git push origin "$TAG"
    info "Created tag $TAG"
  fi
else
  # Force-move tag to current HEAD
  git tag -f "$TAG"
  git push origin "$TAG" --force
  info "Tag $TAG force-moved to $(git rev-parse --short HEAD)"
fi

# ── GitHub release + upload APK ───────────────────────────────────────
if gh release view "$TAG" --repo "$REPO" &>/dev/null; then
  info "Release $TAG exists – uploading APK (clobber) and updating notes..."
  gh release upload "$TAG" "$APK_PATH" --repo "$REPO" --clobber
  gh release edit "$TAG" --repo "$REPO" --notes "$RELEASE_NOTES"
else
  info "Release $TAG does not exist – creating..."
  gh release create "$TAG" "$APK_PATH" \
    --repo "$REPO" \
    --title "$TAG" \
    --notes "$RELEASE_NOTES"
fi

info "Done!  Release: https://github.com/$REPO/releases/tag/${TAG//+/%2B}"
