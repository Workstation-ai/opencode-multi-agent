#!/bin/bash
# Build Firecracker-compatible kernel using Docker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="${SCRIPT_DIR}/../kernels"
mkdir -p "$KERNEL_DIR"

echo "Building Firecracker kernel (this takes a while)..."

# Use Docker to build the kernel without polluting the host
docker run --rm \
  -v "${KERNEL_DIR}:/output" \
  ubuntu:22.04 bash -c '
    apt-get update && apt-get install -y \
      build-essential libncurses-dev flex bison libssl-dev \
      libelf-dev arptables dwarves cpio kmod bc git curl ca-certificates
  
    cd /tmp
    git clone --depth 1 --branch v5.10 https://github.com/torvalds/linux.git
    cd linux
    
    # Use defconfig as base
    make defconfig
    
    # Enable required options for Firecracker
    scripts/config --enable CONFIG_SERIAL_8250
    scripts/config --enable CONFIG_SERIAL_8250_CONSOLE
    scripts/config --enable CONFIG_EXT4_FS
    scripts/config --enable CONFIG_NET
    scripts/config --enable CONFIG_INET
    scripts/config --enable CONFIG_DEVTMPFS
    scripts/config --enable CONFIG_DEVTMPFS_MOUNT
    
    make olddefconfig
    
    # Build kernel
    make -j$(nproc) vmlinux 2>&1 | tail -5
    
    # Copy to output
    cp vmlinux /output/vmlinux
    echo "Kernel built successfully: /output/vmlinux"
  '

echo "Kernel ready: ${KERNEL_DIR}/vmlinux"
ls -lh "${KERNEL_DIR}/vmlinux"
