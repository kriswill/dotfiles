#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Current version from package file
PACKAGE_FILE="pkgs/claude-code/package.nix"
LOCK_FILE="pkgs/claude-code/package-lock.json"
CURRENT_VERSION=$(grep -oE 'version = "[0-9]+\.[0-9]+\.[0-9]+"' "$PACKAGE_FILE" | cut -d'"' -f2)

echo "Fetching available versions..."

# Fetch all versions from npm
ALL_VERSIONS=$(curl -s https://registry.npmjs.org/@anthropic-ai/claude-code | jq -r '.versions | keys | .[]' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V -r)

if [ -z "$ALL_VERSIONS" ]; then
  echo -e "${RED}Failed to fetch versions from npm${NC}"
  exit 1
fi

# Get latest version
LATEST_VERSION=$(echo "$ALL_VERSIONS" | head -n1)

# Function to compare versions
version_gt() {
  test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# Build version list based on current vs latest
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  # Already on latest, show previous 10 versions
  echo -e "${GREEN}You are on the latest version${NC}"
  echo ""
  DISPLAY_VERSIONS=$(echo "$ALL_VERSIONS" | head -n11 | sort -V)
else
  # Show versions between current and latest
  DISPLAY_VERSIONS=""
  for version in $ALL_VERSIONS; do
    if version_gt "$version" "$CURRENT_VERSION" || [ "$version" = "$CURRENT_VERSION" ]; then
      DISPLAY_VERSIONS="$DISPLAY_VERSIONS$version\n"
    fi
    if [ "$version" = "$CURRENT_VERSION" ]; then
      break
    fi
  done
  DISPLAY_VERSIONS=$(echo -e "$DISPLAY_VERSIONS" | grep -v '^$' | sort -V)
fi

# Display versions with current version marked
echo -e "${CYAN}Available versions:${NC}"
echo ""
i=1
while IFS= read -r version; do
  if [ "$version" = "$CURRENT_VERSION" ]; then
    echo -e "  ${GREEN}$i) $version *${NC} (current)"
  else
    echo "  $i) $version"
  fi
  ((i++))
done <<< "$DISPLAY_VERSIONS"

echo ""
echo -n "Select version number (or 'q' to quit): "
read -r selection

if [[ $selection == "q" ]]; then
  echo "Update cancelled."
  exit 0
fi

# Validate selection
if ! [[ $selection =~ ^[0-9]+$ ]]; then
  echo -e "${RED}Invalid selection${NC}"
  exit 1
fi

# Get selected version
SELECTED_VERSION=$(echo "$DISPLAY_VERSIONS" | sed -n "${selection}p")

if [ -z "$SELECTED_VERSION" ]; then
  echo -e "${RED}Invalid selection${NC}"
  exit 1
fi

if [ "$SELECTED_VERSION" = "$CURRENT_VERSION" ]; then
  echo -e "${YELLOW}Selected version is already installed${NC}"
  exit 0
fi

echo ""
echo -e "${BLUE}Updating from $CURRENT_VERSION to $SELECTED_VERSION${NC}"

# Fetch the new hash
echo "Fetching hash for version $SELECTED_VERSION..."
NEW_HASH=$(nix-prefetch-url --type sha256 --unpack "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${SELECTED_VERSION}.tgz" 2>&1 | tail -n1)

if [ -z "$NEW_HASH" ] || [[ $NEW_HASH == *"error"* ]]; then
  echo -e "${RED}Failed to fetch hash for new version${NC}"
  exit 1
fi

# Convert to SRI hash format
SRI_HASH=$(nix hash convert --hash-algo sha256 "$NEW_HASH" 2> /dev/null || echo "sha256-$NEW_HASH")

echo "New hash: $SRI_HASH"

# Create backups
cp "$PACKAGE_FILE" "${PACKAGE_FILE}.bak"
echo "Created backup of package.nix"

# Update the package.nix file with dummy npmDepsHash
DUMMY_NPM_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

if [[ $OSTYPE == "darwin"* ]]; then
  # macOS sed requires a backup extension
  sed -i.tmp \
    -e "s/version = \"${CURRENT_VERSION}\"/version = \"${SELECTED_VERSION}\"/" \
    -e "s|hash = \"[^\"]*\"|hash = \"${SRI_HASH}\"|" \
    -e "s|npmDepsHash = \"[^\"]*\"|npmDepsHash = \"${DUMMY_NPM_HASH}\"|" \
    "$PACKAGE_FILE"
  rm "${PACKAGE_FILE}.tmp"
else
  # GNU sed
  sed -i \
    -e "s/version = \"${CURRENT_VERSION}\"/version = \"${SELECTED_VERSION}\"/" \
    -e "s|hash = \"[^\"]*\"|hash = \"${SRI_HASH}\"|" \
    -e "s|npmDepsHash = \"[^\"]*\"|npmDepsHash = \"${DUMMY_NPM_HASH}\"|" \
    "$PACKAGE_FILE"
fi

# Generate fresh package-lock.json from upstream package.json
# NOTE this is necessary to properly install the optionalDependencies, which include platform-specific image processing tools, which won't
# function properly if we skip creating the package-lock.json file
echo ""
echo "Generating package-lock.json from upstream package.json..."
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Store current directory to get back to it
SCRIPT_DIR=$(pwd)

# Download and extract tarball
curl -sL "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${SELECTED_VERSION}.tgz" | tar -xz -C "$TEMP_DIR"

# Generate package-lock.json
cd "$TEMP_DIR/package"
npm install --package-lock-only --ignore-scripts

# Copy generated package-lock.json to repo
cp package-lock.json "$SCRIPT_DIR/$LOCK_FILE"
cd "$SCRIPT_DIR"

echo "Generated fresh package-lock.json"

echo ""
echo "Calculating npmDepsHash..."
echo ""

# Try to build the package to get the correct npmDepsHash
# We'll capture the hash mismatch error
# Use the darwin configuration to ensure overlays are applied
NPM_HASH_OUTPUT=$(NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link --expr 'with import <nixpkgs> { overlays = [ (import ./overlays/claude-code.nix) ]; config.allowUnfree = true; }; claude-code' 2>&1 || true)

# Extract the correct hash from the error message
# Look for "got:    sha256-..." pattern
CORRECT_NPM_HASH=$(echo "$NPM_HASH_OUTPUT" | grep -oE 'got:\s+sha256-[A-Za-z0-9+/=]+' | head -n1 | sed 's/got:\s*//' | tr -d '[:space:]')

if [ -z "$CORRECT_NPM_HASH" ]; then
  echo -e "${RED}Failed to determine npmDepsHash${NC}"
  echo "Build output:"
  echo "$NPM_HASH_OUTPUT"
  echo ""
  echo -e "${YELLOW}You may need to manually update npmDepsHash in $PACKAGE_FILE${NC}"
  echo "Restoring backup..."
  mv "${PACKAGE_FILE}.bak" "$PACKAGE_FILE"
  echo -e "${YELLOW}Note: package-lock.json has been regenerated. You may need to restore it manually if needed.${NC}"
  exit 1
fi

echo "Calculated npmDepsHash: $CORRECT_NPM_HASH"

# Update the package.nix file with the correct npmDepsHash
if [[ $OSTYPE == "darwin"* ]]; then
  sed -i.tmp "s|npmDepsHash = \"[^\"]*\"|npmDepsHash = \"${CORRECT_NPM_HASH}\"|" "$PACKAGE_FILE"
  rm "${PACKAGE_FILE}.tmp"
else
  sed -i "s|npmDepsHash = \"[^\"]*\"|npmDepsHash = \"${CORRECT_NPM_HASH}\"|" "$PACKAGE_FILE"
fi

# Remove backup file after successful update
rm "${PACKAGE_FILE}.bak"

echo -e "${GREEN}Updated package file successfully!${NC}"
echo ""
echo "Changes made:"
echo "  Version: $CURRENT_VERSION → $SELECTED_VERSION"
echo "  Source hash: updated to $SRI_HASH"
echo "  npmDepsHash: updated to $CORRECT_NPM_HASH"
echo "  package-lock.json: regenerated from upstream package.json"
echo ""
echo "To apply the changes, run:"
echo "  sudo darwin-rebuild switch --flake ~/src/dotfiles |& nom"
