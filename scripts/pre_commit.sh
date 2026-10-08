#!/bin/bash
# ============================================================
# pre_commit.sh - avalanche_flutter_sdk quality gate
# Run before every commit: ./scripts/pre_commit.sh
# ============================================================

set -e

CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}  avalanche_flutter_sdk pre-commit check${NC}"
echo -e "${CYAN}==========================================${NC}"

# ---- Section 1: Format ----
echo ""
echo -e "${YELLOW}[1/3] dart format --set-exit-if-changed .${NC}"
if ! dart format --set-exit-if-changed .; then
    echo -e "${RED}FAILED: Format issues found. Run 'dart format .' to fix.${NC}"
    exit 1
fi
echo -e "${GREEN}Format: OK${NC}"

# ---- Section 2: Analyze ----
echo ""
echo -e "${YELLOW}[2/3] dart analyze --fatal-infos${NC}"
if ! dart analyze --fatal-infos; then
    echo -e "${RED}FAILED: Analysis errors found.${NC}"
    exit 1
fi
echo -e "${GREEN}Analyze: OK${NC}"

# ---- Section 3: Test ----
echo ""
echo -e "${YELLOW}[3/3] flutter test${NC}"
if ! flutter test; then
    echo -e "${RED}FAILED: Tests failed.${NC}"
    exit 1
fi
echo -e "${GREEN}Tests: OK${NC}"

# ---- Done ----
echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  All checks passed. Ready to commit.${NC}"
echo -e "${GREEN}==========================================${NC}"
