#!/bin/bash
# Build rootfs image with opencode installed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOTFS_DIR="${SCRIPT_DIR}/../rootfs"
AGENT_NAME="${1:-coder}"
AGENT_CONFIG="${SCRIPT_DIR}/../../agents/${AGENT_NAME}/AGENT.md"
SIZE_MB="${2:-512}"

mkdir -p "$ROOTFS_DIR"

ROOTFS_FILE="${ROOTFS_DIR}/${AGENT_NAME}.ext4"
echo "Building rootfs for agent: ${AGENT_NAME} (${SIZE_MB}MB)"

# Create empty ext4 image
dd if=/dev/zero of="${ROOTFS_FILE}" bs=1M count=${SIZE_MB} status=progress
mkfs.ext4 -F "${ROOTFS_FILE}"

# Mount and populate
MOUNT_DIR="/tmp/rootfs-${AGENT_NAME}"
mkdir -p "${MOUNT_DIR}"

sudo mount "${ROOTFS_FILE}" "${MOUNT_DIR}"

# Use Alpine Docker to populate the rootfs
sudo docker run --rm \
  -v "${MOUNT_DIR}:/my-rootfs" \
  -v "${AGENT_CONFIG}:/agent-config/AGENT.md:ro" \
  alpine:latest bash -c '
    # Install base system
    apk add --no-cache \
      openrc util-linux curl git bash \
      nodejs npm jq iproute2 iptables \
      ca-certificates
    
    # Set up init system
    ln -s agetty /etc/init.d/agetty.ttyS0
    echo ttyS0 > /etc/securetty
    rc-update add agetty.ttyS0 default
    rc-update add devfs boot
    rc-update add procfs boot
    rc-update add sysfs boot
    rc-update add networking boot
    
    # Create opencode user
    adduser -D -s /bin/bash opencode
    
    # Install opencode
    su - opencode -c "
      mkdir -p ~/.opencode/bin
      curl -fsSL https://opencode.ai/install | bash
    "
    
    # Copy base system to rootfs
    for d in bin etc lib root sbin usr home; do
      tar c "/$d" 2>/dev/null | tar x -C /my-rootfs
    done
    
    for dir in dev proc run sys var tmp; do
      mkdir -p /my-rootfs/${dir}
    done
    
    # Copy agent config
    mkdir -p /my-rootfs/home/opencode/.config/opencode/agents
    cp /agent-config/AGENT.md /my-rootfs/home/opencode/.config/opencode/agents/
    
    # Create startup script
    cat > /my-rootfs/start-agent.sh << "STARTUP"
#!/bin/bash
cd /home/opencode
export PATH="/home/opencode/.opencode/bin:${PATH}"
exec opencode serve --hostname 0.0.0.0 --port 4096
STARTUP
    chmod +x /my-rootfs/start-agent.sh
    
    echo "Rootfs populated successfully"
  '

sudo umount "${MOUNT_DIR}"
rmdir "${MOUNT_DIR}"

echo "Rootfs ready: ${ROOTFS_FILE}"
ls -lh "${ROOTFS_FILE}"
