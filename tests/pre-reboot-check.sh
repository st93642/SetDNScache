#!/bin/bash

# Pre-reboot verification test script
# Validates DNS configuration before system reboot

set -euo pipefail

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file for pre-reboot state
LOG_FILE="/tmp/dns-setup-preboot.log"
JSON_REPORT="/var/log/dns-reboot-test-results.json"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to test DNS resolution
test_dns_resolution() {
    echo "Testing DNS resolution..."
    local test_domains=("example.com" "google.com" "cloudflare.com")
    local success_count=0
    
    for domain in "${test_domains[@]}"; do
        if dig +short "$domain" >/dev/null 2>&1; then
            echo "✓ DNS resolution for $domain: PASS"
            ((success_count++))
        else
            echo "✗ DNS resolution for $domain: FAIL"
        fi
    done
    
    if [ $success_count -eq ${#test_domains[@]} ]; then
        return 0
    else
        return 1
    fi
}

# Function to check if port is listening
check_port_listening() {
    local port=$1
    local protocol=$2
    
    if ss -tuln | grep -q "$port"; then
        return 0
    else
        return 1
    fi
}

# Function to verify service status
verify_service() {
    local service_name=$1
    local display_name=$2
    
    echo "Checking $display_name service..."
    
    # Check if service is running
    if systemctl is-active --quiet "$service_name"; then
        echo "✓ $display_name is running: PASS"
        local running=true
    else
        echo "✗ $display_name is running: FAIL"
        local running=false
    fi
    
    # Check if service is enabled
    if systemctl is-enabled --quiet "$service_name"; then
        echo "✓ $display_name is enabled: PASS"
        local enabled=true
    else
        echo "✗ $display_name is enabled: FAIL"
        local enabled=false
    fi
    
    if [ "$running" = true ] && [ "$enabled" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to verify configuration files
verify_config_files() {
    echo "Verifying configuration files..."
    
    local files_to_check=(
        "/etc/resolv.conf"
        "/etc/stubby/stubby.yml"
        "/etc/dnsmasq.d/dns-stubby.conf"
    )
    
    local all_good=true
    
    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            echo "✓ Configuration file $file exists: PASS"
            
            # Check if file is readable
            if [ -r "$file" ]; then
                echo "✓ Configuration file $file is readable: PASS"
            else
                echo "✗ Configuration file $file is readable: FAIL"
                all_good=false
            fi
            
            # Check for specific content in resolv.conf
            if [ "$file" = "/etc/resolv.conf" ]; then
                if grep -q "127.0.0.1" "$file"; then
                    echo "✓ /etc/resolv.conf points to 127.0.0.1: PASS"
                else
                    echo "✗ /etc/resolv.conf points to 127.0.0.1: FAIL"
                    all_good=false
                fi
            fi
        else
            echo "✗ Configuration file $file exists: FAIL"
            all_good=false
        fi
    done
    
    if [ "$all_good" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to check symlink integrity
check_symlinks() {
    echo "Checking symlink integrity..."
    
    local broken_symlinks=false
    
    # Find broken symlinks in /etc/
    while IFS= read -r -d '' symlink; do
        if [ ! -e "$symlink" ]; then
            echo "✗ Broken symlink found: $symlink"
            broken_symlinks=true
        fi
    done < <(find /etc/ -type l -print0)
    
    if [ "$broken_symlinks" = false ]; then
        echo "✓ No broken symlinks found: PASS"
        return 0
    else
        return 1
    fi
}

# Function to display ASCII art progress indicator
display_progress() {
    echo "${BLUE}"
    echo "  _____ _____ _____ _____ _____ _____ _____ _____"
    echo " |_   _|_   _|_   _|_   _|_   _|_   _|_   _|_   _|"
    echo "   | |   | |   | |   | |   | |   | |   | |   | |  "
    echo "   | |   | |   | |   | |   | |   | |   | |   | |  "
    echo "   |_|   |_|   |_|   |_|   |_|   |_|   |_|   |_|  "
    echo "${NC}"
}

# Main execution
main() {
    echo "${YELLOW}"
    echo "=========================================="
    echo "  DNS Pre-Reboot Verification Test"
    echo "=========================================="
    echo "${NC}"
    
    # Clear previous log file
    rm -f "$LOG_FILE"
    touch "$LOG_FILE"
    
    log_message "Starting pre-reboot verification test"
    
    # Initialize JSON report
    echo '{' > "$JSON_REPORT"
    echo '  "pre_reboot_test": {' >> "$JSON_REPORT"
    echo '    "timestamp": "'$(date '+%Y-%m-%d %H:%M:%S')'",' >> "$JSON_REPORT"
    echo '    "tests": [' >> "$JSON_REPORT"
    
    local test_count=0
    local pass_count=0
    
    # Test 1: Verify Stubby service
    echo ""
    echo "${YELLOW}Test 1: Stubby Service Verification${NC}"
    if verify_service "stubby" "Stubby"; then
        echo '      {"test": "stubby_service", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo '      {"test": "stubby_service", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 2: Verify DNSMasq service
    echo ""
    echo "${YELLOW}Test 2: DNSMasq Service Verification${NC}"
    if verify_service "dnsmasq" "DNSMasq"; then
        echo '      {"test": "dnsmasq_service", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo '      {"test": "dnsmasq_service", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 3: Verify port 53 listening
    echo ""
    echo "${YELLOW}Test 3: Port 53 Listening Check${NC}"
    if check_port_listening "53" "tcp"; then
        echo "✓ Port 53 is listening: PASS"
        echo '      {"test": "port_53_listening", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo "✗ Port 53 is listening: FAIL"
        echo '      {"test": "port_53_listening", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 4: Verify port 5353 listening
    echo ""
    echo "${YELLOW}Test 4: Port 5353 Listening Check${NC}"
    if check_port_listening "5353" "tcp"; then
        echo "✓ Port 5353 is listening: PASS"
        echo '      {"test": "port_5353_listening", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo "✗ Port 5353 is listening: FAIL"
        echo '      {"test": "port_5353_listening", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 5: Verify configuration files
    echo ""
    echo "${YELLOW}Test 5: Configuration Files Verification${NC}"
    if verify_config_files; then
        echo '      {"test": "configuration_files", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo '      {"test": "configuration_files", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 6: DNS resolution test
    echo ""
    echo "${YELLOW}Test 6: DNS Resolution Test${NC}"
    if test_dns_resolution; then
        echo '      {"test": "dns_resolution", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo '      {"test": "dns_resolution", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 7: Check symlink integrity
    echo ""
    echo "${YELLOW}Test 7: Symlink Integrity Check${NC}"
    if check_symlinks; then
        echo '      {"test": "symlink_integrity", "status": "PASS"}' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo '      {"test": "symlink_integrity", "status": "FAIL"}' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Close JSON array and object
    echo '    ],' >> "$JSON_REPORT"
    echo '    "summary": {' >> "$JSON_REPORT"
    echo '      "total_tests": '$test_count',' >> "$JSON_REPORT"
    echo '      "passed_tests": '$pass_count',' >> "$JSON_REPORT"
    echo '      "failed_tests": '$((test_count - pass_count))'' >> "$JSON_REPORT"
    echo '    }' >> "$JSON_REPORT"
    echo '  }' >> "$JSON_REPORT"
    echo '}' >> "$JSON_REPORT"
    
    # Display summary
    echo ""
    echo "${YELLOW}"
    echo "=========================================="
    echo "  Pre-Reboot Test Summary"
    echo "=========================================="
    echo "${NC}"
    
    echo "Total tests: $test_count"
    echo "Passed: ${GREEN}$pass_count${NC}"
    echo "Failed: ${RED}$((test_count - pass_count))${NC}"
    
    if [ $pass_count -eq $test_count ]; then
        echo ""
        echo "${GREEN}✓ All tests passed! System is ready for reboot.${NC}"
        display_progress
    else
        echo ""
        echo "${RED}✗ Some tests failed. Please review the issues before rebooting.${NC}"
        echo ""
        echo "${YELLOW}Pre-reboot state saved to: $LOG_FILE${NC}"
        echo "${YELLOW}Full JSON report saved to: $JSON_REPORT${NC}"
    fi
    
    log_message "Pre-reboot verification test completed"
    log_message "Tests passed: $pass_count/$test_count"
}

# Run main function
main