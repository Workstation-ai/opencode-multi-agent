#!/bin/bash
# Setup networking for Firecracker microVMs
set -euo pipefail

BRIDGE_NAME="fcbr0"
TAP_PREFIX="fc"

echo "Setting up Firecracker networking..."

# Create bridge if it doesn't exist
if ! ip link show "${BRIDGE_NAME}" &>/dev/null; then
  sudo ip link add "${BRIDGE_NAME}" type bridge
  sudo ip addr add 172.16.0.1/24 dev "${BRIDGE_NAME}"
  sudo ip link set "${BRIDGE_NAME}" up
  echo "Bridge ${BRIDGE_NAME} created: 172.16.0.1/24"
fi

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Setup NAT for internet access
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i "${BRIDGE_NAME}" -o eth0 -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o "${BRIDGE_NAME}" -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "Network ready: ${BRIDGE_NAME} (172.16.0.1/24)"

# Function to create TAP interface for a VM
create_tap() {
  local tap_name="${TAP_PREFIX}$1"
  if ! ip link show "${tap_name}" &>/dev/null; then
    sudo ip tuntap add dev "${tap_name}" mode tap
    sudo ip link set "${tap_name}" master "${BRIDGE_NAME}"
    sudo ip link set "${tap_name}" up
    echo "TAP ${tap_name} created"
  fi
}

# Function to assign IP to VM
assign_ip() {
  local vm_id=$1
  local ip="172.16.0.$((vm_id + 10))"
  local tap_name="${TAP_PREFIX}${vm_id}"
  
  # Add IP rule for the TAP interface
  sudo ip addr add "${ip}/24" dev "${tap_name}" 2>/dev/null || true
  
  echo "VM ${vm_id} → ${ip}"
}

# Cleanup function
cleanup() {
  echo "Cleaning up networking..."
  for tap in $(ip link show | grep "${TAP_PREFIX}" | awk -F: '{print $2}' | tr -d ' '); do
    sudo ip link delete "${tap}" 2>/dev/null || true
  done
  sudo ip link delete "${BRIDGE_NAME}" 2>/dev/null || true
  sudo iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
  echo "Cleanup complete"
}

# Export functions for use by other scripts
export -f create_tap assign_ip cleanup
export BRIDGE_NAME TAP_PREFIX
