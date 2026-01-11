#!/bin/bash

# Reboot test helper script
# Interactive guide through reboot cycle with pre/post checks

set -euo pipefail

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Script paths
PRE_REBOOT_SCRIPT="$PROJECT_ROOT/tests/pre-reboot-check.sh"
POST_REBOOT_SCRIPT="$PROJECT_ROOT/tests/post-reboot-check.sh"
JSON_REPORT="/var/log/dns-reboot-test-results.json"

# Function to display ASCII art header
display_header() {
    echo "${BLUE}"
    echo "  _____ _____ _____ _____ _____ _____ _____ _____"
    echo " |_   _|_   _|_   _|_   _|_   _|_   _|_   _|_   _|"
    echo "   | |   | |   | |   | |   | |   | |   | |   | |  "
    echo "   | |   | |   | |   | |   | |   | |   | |   | |  "
    echo "   |_|   |_|   |_|   |_|   |_|   |_|   |_|   |_|  "
    echo "${NC}"
    echo "${YELLOW}"
    echo "  DNS Reboot Test Helper"
    echo "  Interactive Reboot Cycle Guide"
    echo "${NC}"
    echo ""
}

# Function to display progress spinner
display_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "  [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to check if scripts are executable
check_scripts_executable() {
    if [ ! -x "$PRE_REBOOT_SCRIPT" ]; then
        echo "${RED}Error: Pre-reboot script is not executable${NC}"
        echo "Please run: chmod +x $PRE_REBOOT_SCRIPT"
        return 1
    fi
    
    if [ ! -x "$POST_REBOOT_SCRIPT" ]; then
        echo "${RED}Error: Post-reboot script is not executable${NC}"
        echo "Please run: chmod +x $POST_REBOOT_SCRIPT"
        return 1
    fi
    
    return 0
}

# Function to display test checklist
display_checklist() {
    echo "${YELLOW}"
    echo "=========================================="
    echo "  Pre-Reboot Checklist"
    echo "=========================================="
    echo "${NC}"
    echo "The pre-reboot test will verify:"
    echo "  ✓ Stubby service is running and enabled"
    echo "  ✓ DNSMasq service is running and enabled"
    echo "  ✓ Port 53 is listening"
    echo "  ✓ Port 5353 is listening"
    echo "  ✓ Configuration files exist and are readable"
    echo "  ✓ DNS resolution is working"
    echo "  ✓ No broken symlinks in /etc/"
    echo ""
}

# Function to display reboot instructions
display_reboot_instructions() {
    echo "${YELLOW}"
    echo "=========================================="
    echo "  Reboot Instructions"
    echo "=========================================="
    echo "${NC}"
    echo "After the system reboots:"
    echo ""
    echo "1. Log back into your system"
    echo "2. Open a terminal"
    echo "3. Run the post-reboot test:"
    echo "   ${GREEN}$POST_REBOOT_SCRIPT${NC}"
    echo ""
    echo "The post-reboot test will verify:"
    echo "  ✓ Services started automatically"
    echo "  ✓ Configuration files persisted"
    echo "  ✓ DNS resolution works after reboot"
    echo "  ✓ Ports are listening"
    echo "  ✓ Compare with pre-reboot state"
    echo ""
}

# Function to generate comparison report
generate_comparison_report() {
    echo "${YELLOW}"
    echo "=========================================="
    echo "  Comparison Report"
    echo "=========================================="
    echo "${NC}"
    
    if [ -f "$JSON_REPORT" ]; then
        echo "Full test results available in: $JSON_REPORT"
        echo ""
        
        # Extract and display summary
        if grep -q "pre_reboot_test" "$JSON_REPORT" && grep -q "post_reboot_test" "$JSON_REPORT"; then
            echo "Both pre-reboot and post-reboot tests completed successfully."
            echo ""
            
            # Show pre-reboot summary
            echo "Pre-reboot summary:"
            grep -A 3 '"pre_reboot_test"' "$JSON_REPORT" | grep -E '"total_tests"|"passed_tests"|"failed_tests"' | sed 's/.*: //;s/[",]//g'
            echo ""
            
            # Show post-reboot summary  
            echo "Post-reboot summary:"
            grep -A 3 '"post_reboot_test"' "$JSON_REPORT" | grep -E '"total_tests"|"passed_tests"|"failed_tests"' | sed 's/.*: //;s/[",]//g'
            echo ""
            
            # Check if all tests passed
            local pre_failed=$(grep -A 3 '"pre_reboot_test"' "$JSON_REPORT" | grep '"failed_tests"' | sed 's/.*: //;s/[",]//g')
            local post_failed=$(grep -A 3 '"post_reboot_test"' "$JSON_REPORT" | grep '"failed_tests"' | sed 's/.*: //;s/[",]//g')
            
            if [ "$pre_failed" = "0" ] && [ "$post_failed" = "0" ]; then
                echo "${GREEN}✓ All tests passed! DNS configuration successfully persisted across reboot.${NC}"
            else
                echo "${RED}✗ Some tests failed. Review the JSON report for details.${NC}"
            fi
        else
            echo "Incomplete test data in JSON report."
        fi
    else
        echo "No JSON report found. Please run both pre-reboot and post-reboot tests."
    fi
}

# Main interactive function
main() {
    display_header
    
    # Check if scripts are executable
    if ! check_scripts_executable; then
        exit 1
    fi
    
    echo "This script will guide you through a complete reboot test cycle."
    echo "It includes pre-reboot checks, system reboot, and post-reboot verification."
    echo ""
    
    # Ask for confirmation to proceed
    read -p "Do you want to proceed with the reboot test? (y/n) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Reboot test cancelled."
        exit 0
    fi
    
    # Step 1: Run pre-reboot checks
    echo ""
    echo "${YELLOW}Step 1: Running Pre-Reboot Checks${NC}"
    echo ""
    
    display_checklist
    
    echo "Running pre-reboot verification test..."
    echo ""
    
    # Run pre-reboot script
    if [ -x "$PRE_REBOOT_SCRIPT" ]; then
        $PRE_REBOOT_SCRIPT
        echo ""
    else
        echo "${RED}Error: Cannot execute pre-reboot script${NC}"
        exit 1
    fi
    
    # Step 2: Prepare for reboot
    echo ""
    echo "${YELLOW}Step 2: Preparing for System Reboot${NC}"
    echo ""
    
    display_reboot_instructions
    
    # Ask for confirmation to reboot
    read -p "Are you ready to reboot the system? (y/n) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Reboot cancelled. You can manually reboot later and run the post-reboot test."
        exit 0
    fi
    
    # Step 3: Reboot the system
    echo ""
    echo "${YELLOW}Step 3: Rebooting System${NC}"
    echo ""
    echo "The system will reboot now..."
    echo ""
    
    # Give user a moment to see the message
    sleep 3
    
    # Reboot the system
    sudo reboot
}

# Alternative function for post-reboot guidance
post_reboot_guidance() {
    display_header
    
    echo "Welcome back! This will guide you through post-reboot verification."
    echo ""
    
    # Check if pre-reboot log exists
    if [ -f "/tmp/dns-setup-preboot.log" ]; then
        echo "✓ Pre-reboot test data found. Proceeding with comparison."
        echo ""
    else
        echo "⚠ No pre-reboot test data found."
        echo "You can still run the post-reboot test for basic verification."
        echo ""
    fi
    
    # Ask for confirmation to run post-reboot test
    read -p "Do you want to run the post-reboot verification test? (y/n) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Post-reboot test cancelled."
        exit 0
    fi
    
    # Run post-reboot script
    echo "Running post-reboot verification test..."
    echo ""
    
    if [ -x "$POST_REBOOT_SCRIPT" ]; then
        $POST_REBOOT_SCRIPT
        echo ""
    else
        echo "${RED}Error: Cannot execute post-reboot script${NC}"
        exit 1
    fi
    
    # Generate comparison report
    echo ""
    generate_comparison_report
}

# Main execution logic
if [ "$#" -eq 0 ]; then
    # No arguments - run full interactive reboot test
    main
elif [ "$1" = "--post-reboot" ] || [ "$1" = "-p" ]; then
    # Post-reboot mode
    post_reboot_guidance
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    # Help message
    echo "DNS Reboot Test Helper"
    echo ""
    echo "Usage:"
    echo "  $0                    - Run full interactive reboot test"
    echo "  $0 --post-reboot (-p) - Run post-reboot verification only"
    echo "  $0 --help (-h)        - Show this help message"
    echo ""
    exit 0
else
    echo "Unknown option: $1"
    echo "Use --help for usage information."
    exit 1
fi