#!/bin/bash

# Post-reboot verification test script
# Validates DNS configuration after system reboot

set -euo pipefail

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log files
PREBOOT_LOG="/tmp/dns-setup-preboot.log"
POSTBOOT_LOG="/tmp/dns-setup-postboot.log"
JSON_REPORT="/var/log/dns-reboot-test-results.json"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$POSTBOOT_LOG"
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

# Function to measure service startup time
measure_startup_time() {
    echo "Measuring service startup time..."
    
    local stubby_startup=$(systemctl show stubby --property=ExecMainStartTimestamp,ExecMainExitTimestamp --value 2>/dev/null || echo "N/A")
    local dnsmasq_startup=$(systemctl show dnsmasq --property=ExecMainStartTimestamp,ExecMainExitTimestamp --value 2>/dev/null || echo "N/A")
    
    echo "Stubby startup: $stubby_startup"
    echo "DNSMasq startup: $dnsmasq_startup"
    
    return 0
}

# Function to compare with pre-reboot state
compare_with_preboot() {
    echo "Comparing with pre-reboot state..."
    
    if [ -f "$PREBOOT_LOG" ]; then
        echo "✓ Pre-reboot log found: PASS"
        
        # Check if services were running before reboot
        if grep -q "Stubby is running: PASS" "$PREBOOT_LOG"; then
            echo "✓ Stubby was running before reboot: PASS"
        fi
        
        if grep -q "DNSMasq is running: PASS" "$PREBOOT_LOG"; then
            echo "✓ DNSMasq was running before reboot: PASS"
        fi
        
        return 0
    else
        echo "✗ Pre-reboot log not found: FAIL"
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

# Function to provide remediation steps
provide_remediation() {
    echo ""
    echo "${YELLOW}Remediation Steps:${NC}"
    echo ""
    
    # Check if stubby is not running
    if ! systemctl is-active --quiet stubby; then
        echo "1. Stubby service failed to start automatically:"
        echo "   - Check service status: sudo systemctl status stubby"
        echo "   - Start manually: sudo systemctl start stubby"
        echo "   - Enable for auto-start: sudo systemctl enable stubby"
        echo ""
    fi
    
    # Check if dnsmasq is not running
    if ! systemctl is-active --quiet dnsmasq; then
        echo "2. DNSMasq service failed to start automatically:"
        echo "   - Check service status: sudo systemctl status dnsmasq"
        echo "   - Start manually: sudo systemctl start dnsmasq"
        echo "   - Enable for auto-start: sudo systemctl enable dnsmasq"
        echo ""
    fi
    
    # Check resolv.conf
    if [ -f "/etc/resolv.conf" ] && ! grep -q "127.0.0.1" "/etc/resolv.conf"; then
        echo "3. /etc/resolv.conf not pointing to localhost:"
        echo "   - Check current content: cat /etc/resolv.conf"
        echo "   - Fix with: echo 'nameserver 127.0.0.1' | sudo tee /etc/resolv.conf"
        echo ""
    fi
    
    echo "For more detailed troubleshooting, check the full report at: $JSON_REPORT"
}

# Main execution
main() {
    echo "${YELLOW}"
    echo "=========================================="
    echo "  DNS Post-Reboot Verification Test"
    echo "=========================================="
    echo "${NC}"
    
    # Clear previous log file
    rm -f "$POSTBOOT_LOG"
    touch "$POSTBOOT_LOG"
    
    log_message "Starting post-reboot verification test"
    
    # Check if we have a pre-reboot log to compare with
    if [ -f "$JSON_REPORT" ]; then
        # Append to existing JSON report
        local action="append"
        echo '  },' >> "$JSON_REPORT"
        echo '  "post_reboot_test": {' >> "$JSON_REPORT"
        echo '    "timestamp": "'$(date '+%Y-%m-%d %H:%M:%S')'",' >> "$JSON_REPORT"
        echo '    "tests": [' >> "$JSON_REPORT"
    else
        # Create new JSON report
        local action="new"
        echo '{' > "$JSON_REPORT"
        echo '  "post_reboot_test": {' >> "$JSON_REPORT"
        echo '    "timestamp": "'$(date '+%Y-%m-%d %H:%M:%S')'",' >> "$JSON_REPORT"
        echo '    "tests": [' >> "$JSON_REPORT"
    fi
    
    local test_count=0
    local pass_count=0
    
    # Test 1: Verify Stubby service started automatically
    echo ""
    echo "${YELLOW}Test 1: Stubby Service Auto-Start Verification${NC}"
    if verify_service "stubby" "Stubby"; then
        echo '      {"test": "stubby_auto_start", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo '      {"test": "stubby_auto_start", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 2: Verify DNSMasq service started automatically
    echo ""
    echo "${YELLOW}Test 2: DNSMasq Service Auto-Start Verification${NC}"
    if verify_service "dnsmasq" "DNSMasq"; then
        echo '      {"test": "dnsmasq_auto_start", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo '      {"test": "dnsmasq_auto_start", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 3: Verify /etc/resolv.conf still points to 127.0.0.1
    echo ""
    echo "${YELLOW}Test 3: /etc/resolv.conf Configuration Persistence${NC}"
    if [ -f "/etc/resolv.conf" ] && grep -q "127.0.0.1" "/etc/resolv.conf"; then
        echo "✓ /etc/resolv.conf points to 127.0.0.1: PASS"
        echo '      {"test": "resolv_conf_persistence", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo "✗ /etc/resolv.conf points to 127.0.0.1: FAIL"
        echo '      {"test": "resolv_conf_persistence", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 4: Verify stubby.yml configuration is intact
    echo ""
    echo "${YELLOW}Test 4: Stubby Configuration File Integrity${NC}"
    if [ -f "/etc/stubby/stubby.yml" ] && [ -r "/etc/stubby/stubby.yml" ]; then
        echo "✓ /etc/stubby/stubby.yml configuration intact: PASS"
        echo '      {"test": "stubby_config_integrity", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo "✗ /etc/stubby/stubby.yml configuration intact: FAIL"
        echo '      {"test": "stubby_config_integrity", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 5: Verify dns-stubby.conf configuration is intact
    echo ""
    echo "${YELLOW}Test 5: DNSMasq Configuration File Integrity${NC}"
    if [ -f "/etc/dnsmasq.d/dns-stubby.conf" ] && [ -r "/etc/dnsmasq.d/dns-stubby.conf" ]; then
        echo "✓ /etc/dnsmasq.d/dns-stubby.conf configuration intact: PASS"
        echo '      {"test": "dnsmasq_config_integrity", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo "✗ /etc/dnsmasq.d/dns-stubby.conf configuration intact: FAIL"
        echo '      {"test": "dnsmasq_config_integrity", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 6: DNS resolution test after reboot
    echo ""
    echo "${YELLOW}Test 6: Post-Reboot DNS Resolution Test${NC}"
    if test_dns_resolution; then
        echo '      {"test": "post_reboot_dns_resolution", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo '      {"test": "post_reboot_dns_resolution", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 7: Verify port 53 listening after reboot
    echo ""
    echo "${YELLOW}Test 7: Port 53 Listening After Reboot${NC}"
    if check_port_listening "53" "tcp"; then
        echo "✓ Port 53 is listening: PASS"
        echo '      {"test": "port_53_post_reboot", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo "✗ Port 53 is listening: FAIL"
        echo '      {"test": "port_53_post_reboot", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 8: Verify port 5353 listening after reboot
    echo ""
    echo "${YELLOW}Test 8: Port 5353 Listening After Reboot${NC}"
    if check_port_listening "5353" "tcp"; then
        echo "✓ Port 5353 is listening: PASS"
        echo '      {"test": "port_5353_post_reboot", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo "✗ Port 5353 is listening: FAIL"
        echo '      {"test": "port_5353_post_reboot", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 9: Measure startup time
    echo ""
    echo "${YELLOW}Test 9: Service Startup Time Measurement${NC}"
    if measure_startup_time; then
        echo '      {"test": "startup_time_measurement", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo '      {"test": "startup_time_measurement", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 10: Compare with pre-reboot state
    echo ""
    echo "${YELLOW}Test 10: Pre-Reboot State Comparison${NC}"
    if compare_with_preboot; then
        echo '      {"test": "pre_reboot_comparison", "status": "PASS"},' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo '      {"test": "pre_reboot_comparison", "status": "FAIL"},' >> "$JSON_REPORT"
    fi
    ((test_count++))
    
    # Test 11: DNSSEC persistence check (final test - no trailing comma)
    echo ""
    echo "${YELLOW}Test 11: DNSSEC Persistence After Reboot${NC}"
    if dig +dnssec cloudflare.com | grep -q "ad;"; then
        echo "✓ DNSSEC validation still working: PASS"
        echo '      {"test": "dnssec_persistence", "status": "PASS"}' >> "$JSON_REPORT"
        ((pass_count++))
    else
        echo "✗ DNSSEC validation failed: FAIL"
        echo '      {"test": "dnssec_persistence", "status": "FAIL"}' >> "$JSON_REPORT"
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
    echo "  Post-Reboot Test Summary"
    echo "=========================================="
    echo "${NC}"
    
    echo "Total tests: $test_count"
    echo "Passed: ${GREEN}$pass_count${NC}"
    echo "Failed: ${RED}$((test_count - pass_count))${NC}"
    
    if [ $pass_count -eq $test_count ]; then
        echo ""
        echo "${GREEN}✓ All tests passed! DNS configuration persisted successfully across reboot.${NC}"
        display_progress
    else
        echo ""
        echo "${RED}✗ Some tests failed. DNS configuration may not have persisted correctly.${NC}"
        echo ""
        provide_remediation
    fi
    
    log_message "Post-reboot verification test completed"
    log_message "Tests passed: $pass_count/$test_count"
    
    echo ""
    echo "${YELLOW}Post-reboot state saved to: $POSTBOOT_LOG${NC}"
    echo "${YELLOW}Full JSON report saved to: $JSON_REPORT${NC}"
}

# Run main function
main