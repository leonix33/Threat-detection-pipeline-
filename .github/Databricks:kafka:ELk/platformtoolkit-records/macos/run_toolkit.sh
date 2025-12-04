#!/bin/bash

# ============================================================
#   PLATFORM TOOLKIT RUNNER SCRIPT FOR MACOS
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

show_help() {
    echo -e "${BLUE}Platform Toolkit for macOS${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  install     Install/update all tools"
    echo "  verify      Verify installation"
    echo "  update      Update all tools"
    echo "  uninstall   Remove all tools"
    echo "  help        Show this help message"
    echo ""
    echo -e "${YELLOW}Install Options:${NC}"
    echo "  --dry-run   Show what would be done"
    echo "  --force     Force reinstall all tools"
    echo "  --log       Enable logging"
    echo "  --verbose   Verbose output"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 install                  # Install all tools"
    echo "  $0 install --dry-run        # Preview installation"
    echo "  $0 install --force --log    # Force reinstall with logging"
    echo "  $0 verify                   # Check installation status"
    echo "  $0 update                   # Update all tools"
    echo ""
}

case "${1:-help}" in
    install)
        shift
        echo -e "${BLUE}Running Platform Toolkit Installation...${NC}"
        bash "$SCRIPT_DIR/platform_toolkit.sh" "$@"
        ;;
    verify)
        echo -e "${BLUE}Verifying Installation...${NC}"
        bash "$SCRIPT_DIR/scripts/verify_installation.sh"
        ;;
    update)
        echo -e "${BLUE}Updating Platform Toolkit...${NC}"
        bash "$SCRIPT_DIR/update_toolkit.sh"
        ;;
    uninstall)
        echo -e "${BLUE}Uninstalling Platform Toolkit...${NC}"
        bash "$SCRIPT_DIR/uninstall_toolkit.sh"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac