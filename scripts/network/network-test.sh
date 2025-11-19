#!/bin/bash
# Network Connectivity Test Script

echo "=== Network Diagnostic Tool ==="

# Test internet connectivity
echo "Testing internet connectivity..."
ping -c 2 8.8.8.8

# Display network configuration (macOS compatible)
echo -e "\nNetwork configuration:"
ifconfig | grep -E "inet|flags" | head -10

# Check open ports (macOS compatible)
echo -e "\nChecking common service ports..."
netstat -an | grep -E "\.(22|80|443|3389)" | grep LISTEN

echo "Network test completed!"
