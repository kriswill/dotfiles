#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BUN_BIN="$HOME/.bun/bin"
OPENCODE_BIN="$BUN_BIN/opencode"

# Check if opencode is installed
if [[ ! -x "$OPENCODE_BIN" ]]; then
  echo -e "${YELLOW}opencode-ai is not installed globally via bun.${NC}"
  echo -n "Would you like to install it? [y/N] "
  read -r response

  if [[ "$response" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Installing opencode-ai...${NC}"
    bun add -g opencode-ai

    if [[ ! -x "$OPENCODE_BIN" ]]; then
      echo -e "${RED}Installation failed. opencode binary not found.${NC}"
      exit 1
    fi
    echo -e "${GREEN}Successfully installed opencode-ai${NC}"
  else
    echo "Installation cancelled."
    exit 0
  fi
fi

# Run opencode with bun as the runtime
exec bun --bun "$OPENCODE_BIN" "$@"
