#!/usr/bin/env bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Updating opencode flake input...${NC}"
nix flake update opencode

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "To apply the changes, run:"
echo "  sudo darwin-rebuild switch --flake ~/src/dotfiles |& nom"
