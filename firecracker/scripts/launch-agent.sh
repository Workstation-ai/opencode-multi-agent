#!/bin/bash
# Launch a Firecracker microVM for an agent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRECRACKER_BIN="/usr/local/bin/firecracker"
KERNEL="${SCRIPT_DIR}/../kernels/vmlinux"
AGENTS_DIR="${SCRIPT_DIR}/../../agents"

# Configuration
AGENT_NAME="${1:?Usage: $0 <agent-name> [vm-id]}"
VM_ID="${2:-0}"
VM_IP="172.16.0.$((VM_ID + 10))"
TAP_NAME="fc${VM_ID}"
SOCK="/tmp/fc-${AGENT_NAME}.sock"
LOG_FILE="/tmp/fc-${AGENT_NAME}.log"
API_SOCKET="/tmp/fc-${AGENT_NAME}-api.sock"

# Validate inputs
if [[ ! -f "${KERNEL}" ]]; then
  echo "Error: Kernel not found at ${KERNEL}"
  echo "Run: ./build-kernel.sh"
  exit 1
fi

ROOTFS="${SCRIPT_DIR}/../rootfs/${AGENT_NAME}.ext4"
if [[ ! -f "${ROOTFS}" ]]; then
  echo "Error: Rootfs not found at ${ROOTFS}"
  echo "Run: ./build-rootfs.sh ${AGENT_NAME}"
  exit 1
fi

# Setup TAP interface
source "${SCRIPT_DIR}/setup-network.sh"
create_tap "${VM_ID}"
assign_ip "${VM_ID}"

# Clean up existing socket
rm -f "${SOCK}" "${API_SOCKET}"

echo "Starting agent ${AGENT_NAME} (VM ${VM_ID}, IP ${VM_IP})..."

# Configure and start Firecracker
"${FIRECRACKER_BIN}" \
  --api-uds "${API_SOCKET}" \
  --log-to "${LOG_FILE}" \
  --level WARN \
  --dump-crts \
  2>&1 &
  
FC_PID=$!

# Wait for socket
sleep 0.5

# Configure VM via API
curl --unix-socket "${API_SOCKET}" -s http://localhost/boot-source \
  -X PUT \
  -H "Content-Type: application/json" \
  -d "{
    \"kernel_image_path\": \"${KERNEL}\",
    \"boot_args\": \"console=ttyS0 reboot=k panic=1 pci=off ip=${VM_IP}::172.16.0.1:255.255.255.0::eth0:off\"
  }"

curl --unix-socket "${API_SOCKET}" -s http://localhost/rootfs \
  -X PUT \
  -H "Content-Type: application/json" \
  -d "{
    \"drive_id\": \"rootfs\",
    \"path_on_host\": \"${ROOTFS}\",
    \"is_root_device\": true,
    \"is_read_only\": false
  }"

curl --unix-socket "${API_SOCKET}" -s http://localhost/machine-config \
  -X PUT \
  -H "Content-Type: application/json" \
  -d "{
    \"vcpu_count\": 2,
    \"mem_size_mib\": 512
  }"

# Add network interface
curl --unix-socket "${API_SOCKET}" -s http://localhost/network-interfaces/eth0 \
  -X PUT \
  -H "Content-Type: application/json" \
  -d "{
    \"iface_id\": \"eth0\",
    \"host_dev_name\": \"${TAP_NAME}\"
  }"

# Start the VM
curl --unix-socket "${API_SOCKET}" -s http://localhost/actions \
  -X PUT \
  -H "Content-Type: application/json" \
  -d "{\"action_type\": \"InstanceStart\"}"

echo "Agent ${AGENT_NAME} started (PID: ${FC_PID})"
echo "  API Socket: ${API_SOCKET}"
echo "  Log: ${LOG_FILE}"
echo "  IP: ${VM_IP}"

# Save VM info
mkdir -p /tmp/fc-vms
cat > "/tmp/fc-vms/${AGENT_NAME}.json" << EOF
{
  "name": "${AGENT_NAME}",
  "pid": ${FC_PID},
  "ip": "${VM_IP}",
  "api_socket": "${API_SOCKET}",
  "log": "${LOG_FILE}",
  "started_at": "$(date -Iseconds)"
}
EOF

echo "VM info saved to /tmp/fc-vms/${AGENT_NAME}.json"
